CREATE OR ALTER PROCEDURE dbo.usp_CalculoInteresesMasivo
(
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    ----------------------------------------------------------------------
    -- 0) Validaciones simples (fuera de TRY)
    ----------------------------------------------------------------------
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 61001;   -- fecha de corte inválida
        RETURN;
    END;

    DECLARE @idCC        INT;
    DECLARE @tasaMensual DECIMAL(6,5);
    DECLARE @tasaDiaria  DECIMAL(18,10);

    ----------------------------------------------------------------------
    -- 1) CC de InteresesMoratorios
    ----------------------------------------------------------------------
    SELECT @idCC = c.id
    FROM dbo.CC AS c
    WHERE c.nombre = N'InteresesMoratorios';

    IF @idCC IS NULL
    BEGIN
        SET @outResultCode = 61002;   -- CC de intereses no configurado
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 2) Obtener tasa mensual y convertir a diaria
    --    (ejemplo: 0.04 mensual / 30 días) :contentReference[oaicite:2]{index=2}
    ----------------------------------------------------------------------
    SELECT @tasaMensual = cim.ValorPorcentual
    FROM dbo.CC_InteresesMoratorios AS cim
    WHERE cim.id = @idCC;

    IF @tasaMensual IS NULL
    BEGIN
        SET @outResultCode = 61002;
        RETURN;
    END;

    SET @tasaDiaria = @tasaMensual / 30.0;

    ----------------------------------------------------------------------
    -- 3) Cálculo de intereses (con transacción)
    ----------------------------------------------------------------------
    BEGIN TRY
        BEGIN TRAN;

        ------------------------------------------------------------------
        -- 3.1 Facturas pendientes y vencidas a la fecha
        ------------------------------------------------------------------
        ;WITH FacturasConMora AS
        (
            SELECT 
                  f.id            AS idFactura
                , f.idPropiedad
                , f.totalOriginal
                , DATEDIFF(DAY, f.fechaVenc, @inFechaCorte) AS diasMora
            FROM dbo.Factura AS f
            WHERE f.estado    = 1              -- 1 = Pendiente :contentReference[oaicite:3]{index=3}
              AND f.fechaVenc < @inFechaCorte
        )
        SELECT
              idFactura
            , idPropiedad
            , totalOriginal
            , diasMora
        INTO #FacturasMora
        FROM FacturasConMora
        WHERE diasMora > 0;

        ------------------------------------------------------------------
        -- 3.2 Insertar SOLO el interés incremental
        ------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
        (
              idFactura
            , idCC
            , descripcion
            , monto
        )
        SELECT
              fm.idFactura
            , @idCC
            , N'Intereses por mora (' 
                + CAST(fm.diasMora AS NVARCHAR(4)) 
                + N' días)'
            , CAST(
                    theo.interesTeorico 
                  - ISNULL(ia.interesAcumulado, 0.0)
              AS MONEY)
        FROM #FacturasMora AS fm
        CROSS APPLY
        (
            -- Interés TEÓRICO al día @inFechaCorte
            SELECT 
                CAST(
                    fm.totalOriginal * @tasaDiaria * fm.diasMora
                AS MONEY) AS interesTeorico
        ) AS theo
        LEFT JOIN
        (
            -- Interés YA COBRADO para este CC en cada factura
            SELECT
                  df.idFactura
                , SUM(df.monto) AS interesAcumulado
            FROM dbo.DetalleFactura AS df
            WHERE df.idCC = @idCC
            GROUP BY df.idFactura
        ) AS ia
            ON ia.idFactura = fm.idFactura
        WHERE theo.interesTeorico > ISNULL(ia.interesAcumulado, 0.0);

        ------------------------------------------------------------------
        -- 3.3 Recalcular totalFinal SOLO de facturas afectadas
        ------------------------------------------------------------------
        ;WITH Totales AS
        (
            SELECT
                  df.idFactura
                , SUM(df.monto) AS totalDetalle
            FROM dbo.DetalleFactura AS df
            GROUP BY df.idFactura
        )
        UPDATE f
        SET f.totalFinal = f.totalOriginal + ISNULL(t.totalDetalle, 0.0)
        FROM dbo.Factura AS f
        JOIN #FacturasMora AS fm
             ON fm.idFactura = f.id
        LEFT JOIN Totales AS t
             ON t.idFactura = f.id;

        DROP TABLE #FacturasMora;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        INSERT INTO dbo.DBErrors
        (
              UserName
            , Number
            , State
            , Severity
            , [Line]
            , [Procedure]
            , Message
            , DateTime
        )
        VALUES
        (
              SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 61003;
    END CATCH;
END;
GO