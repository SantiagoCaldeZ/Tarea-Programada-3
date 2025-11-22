CREATE OR ALTER PROCEDURE dbo.usp_AplicacionPagosMasiva
(
      @inFechaCorte   DATE
    , @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    BEGIN TRY
        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 0) Validación
        ----------------------------------------------------------------------
        IF (@inFechaCorte IS NULL)
        BEGIN
            SET @outResultCode = 65001;
            ROLLBACK TRAN;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 1) Seleccionar pagos HASTA la fecha que aún NO tengan comprobante
        ----------------------------------------------------------------------
        SELECT 
              p.id              AS idPago
            , p.numeroFinca
            , p.monto
            , p.idFactura
            , pr.id            AS idPropiedad
        INTO #PagosPendientes
        FROM dbo.Pago          AS p
        JOIN dbo.Propiedad     AS pr  ON pr.numeroFinca = p.numeroFinca
        WHERE   (p.fecha <= @inFechaCorte)
            AND NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.ComprobantePago AS cp
                    WHERE cp.idPago = p.id
                );

        ----------------------------------------------------------------------
        -- 2) Asignar factura más vieja PENDIENTE si idFactura = NULL
        --    Estados de Factura:
        --    1 = Pendiente, 2 = Pagado normal, 3 = Arreglo, 4 = Anulado
        ----------------------------------------------------------------------
        UPDATE pp
        SET idFactura =
        (
            SELECT TOP (1) f.id
            FROM dbo.Factura AS f
            WHERE     f.idPropiedad = pp.idPropiedad
                  AND f.estado      = 1      -- Pendiente
            ORDER BY f.fechaVenc
        )
        FROM #PagosPendientes AS pp
        WHERE pp.idFactura IS NULL;

        ----------------------------------------------------------------------
        -- 3) Calcular el MONTO del pago = totalFinal de la factura
        --    (solo facturas pendientes y con idFactura asignada)
        ----------------------------------------------------------------------
        UPDATE p
        SET p.monto = f.totalFinal
        FROM dbo.Pago          AS p
        JOIN #PagosPendientes  AS pp ON pp.idPago    = p.id
        JOIN dbo.Factura       AS f  ON f.id        = pp.idFactura
        WHERE f.estado = 1;    -- Pendiente

        ----------------------------------------------------------------------
        -- 4) Marcar facturas como pagadas (estado = 2) y totalFinal = 0
        ----------------------------------------------------------------------
        UPDATE f
        SET     f.estado     = 2        -- Pagado normal
              , f.totalFinal = 0
        FROM dbo.Factura       AS f
        JOIN #PagosPendientes  AS pp ON pp.idFactura = f.id
        WHERE f.estado = 1;            -- Solo las que estaban pendientes

        ----------------------------------------------------------------------
        -- 5) Generar Comprobante de Pago
        --    fecha = fecha del pago (o @inFechaCorte),
        --    monto = Pago.monto (ya calculado),
        --    numeroReferencia = Pago.numeroReferencia
        ----------------------------------------------------------------------
        INSERT INTO dbo.ComprobantePago
        (
              idPago
            , fecha
            , monto
            , numeroReferencia
        )
        SELECT
              p.id
            , p.fecha              -- o @inFechaCorte, según prefieras
            , p.monto
            , p.numeroReferencia
        FROM dbo.Pago          AS p
        JOIN #PagosPendientes  AS pp ON pp.idPago    = p.id
        JOIN dbo.Factura       AS f  ON f.id        = pp.idFactura
        WHERE f.estado = 2;          -- ya marcadas como pagadas

        COMMIT TRAN;
    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
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

        SET @outResultCode = 65002;
    END CATCH;
END;
GO