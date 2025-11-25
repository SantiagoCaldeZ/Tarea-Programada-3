CREATE OR ALTER   PROCEDURE [dbo].[usp_CalculoInteresesMasivo]
    (
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    -- 0) Validaciones simples

    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 61001;
        -- fecha de corte inválida
        RETURN;
    END;

    DECLARE @idCC        INT;
    DECLARE @tasaMensual DECIMAL(6,5);
    DECLARE @tasaDiaria  DECIMAL(18,10);

    DECLARE @FacturasMora TABLE
    (
        idFactura INT PRIMARY KEY
        ,
        idPropiedad INT
        ,
        totalOriginal MONEY
        ,
        diasMora INT
        ,
        interesTeorico MONEY
    );

    BEGIN TRY
    -- 1 Obtener parámetros para cálculo (CC y Tasa)

    SELECT @idCC = c.id
    FROM dbo.CC AS c
    WHERE (c.nombre = N'InteresesMoratorios');

    IF (@idCC IS NULL)
    BEGIN
        SET @outResultCode = 61002;
        -- CC de intereses no configurado
        RETURN;
    END;

    -- Obtener tasa y convertir a diaria
    SELECT @tasaMensual = TRY_CONVERT(DECIMAL(6,5), p.valor)
    FROM dbo.ParametroSistema AS p
    WHERE (p.clave = N'TasaInteresMoratorio');

    -- Se asume un mes de 30 días para el cálculo de la tasa diaria
    SET @tasaDiaria = @tasaMensual / 30.0; 

    -- 2 Identificar y calcular intereses de facturas en mora 
    INSERT INTO @FacturasMora
        (
        idFactura
        ,idPropiedad
        ,totalOriginal
        ,diasMora
        ,interesTeorico
        )
    SELECT
        f.id,
        f.idPropiedad,
        f.totalOriginal,
        DATEDIFF(DAY, f.fechaVenc, @inFechaCorte),
        -- Cálculo: monto_base * tasa_diaria * días_mora
        (f.totalOriginal * @tasaDiaria * DATEDIFF(DAY, f.fechaVenc, @inFechaCorte))
    FROM dbo.Factura AS f
    WHERE 
        (f.estado = 3) -- Solo facturas Vencidas (Mora)
        AND (f.fechaVenc < @inFechaCorte) -- Que la fecha de vencimiento haya pasado
        AND (f.totalOriginal > 0);                  -- Solo facturas con saldo base

    BEGIN TRAN;

    -- Subconsulta para Intereses Acumulados (si ya se había aplicado el CC)
    ;WITH
        InteresAcumulado
        AS
        (
            SELECT
                df.idFactura
            , SUM(df.monto) AS interesAcumulado
            FROM dbo.DetalleFactura AS df
            WHERE (df.idCC = @idCC)
            GROUP BY df.idFactura
        )
    -- Insertar los nuevos intereses
    INSERT INTO dbo.DetalleFactura
        (
        idFactura
        , idCC
        , monto
        )
    SELECT
        fm.idFactura
        , @idCC
        , (fm.interesTeorico - ISNULL(ia.interesAcumulado, 0.0))
    -- Solo la diferencia
    FROM @FacturasMora AS fm
        LEFT JOIN InteresAcumulado AS ia --en este caso el left join hace que las facturas nuevas en mora sean incluidas pero su interes acumulado sera nulo
        ON ia.idFactura = fm.idFactura
    -- Solo insertar si el nuevo interés calculado supera el acumulado (o si no existe)
    WHERE (fm.interesTeorico > ISNULL(ia.interesAcumulado, 0.0));

    --Recalcular totalFinal de facturas afectadas 
    ;WITH
        Totales
        AS
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
        JOIN @FacturasMora AS fm
        ON fm.idFactura = f.id
        LEFT JOIN Totales AS t
        ON t.idFactura = f.id;

    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    -- Inserción de error según estándar
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
    THROW;
END CATCH
END;
GO