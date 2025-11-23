CREATE OR ALTER PROCEDURE dbo.usp_AplicacionPagosMasiva
(
    @inFechaCorte DATE,
    @outResultCode INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

BEGIN TRY
    BEGIN TRAN;

    ----------------------------------------------------------------------
    -- 1) PAGOS SIN FACTURA ASOCIADA → asignar factura pendiente más vieja
    ----------------------------------------------------------------------
    SELECT 
        p.id          AS idPago,
        p.numeroFinca,
        p.monto,
        p.idFactura   AS idFacturaActual
    INTO #PagosNoFactura
    FROM dbo.Pago p
    WHERE p.idFactura IS NULL
      AND p.fecha <= @inFechaCorte;

    -- Asignar factura pendiente más vieja
    UPDATE pnf
    SET pnf.idFacturaActual = f.id
    FROM #PagosNoFactura pnf
    CROSS APPLY (
        SELECT TOP 1 f.id
        FROM dbo.Factura f
        JOIN dbo.Propiedad pr ON pr.id = f.idPropiedad
        WHERE pr.numeroFinca = pnf.numeroFinca
          AND f.estado = 1            -- Pendiente
          AND f.totalFinal > 0
        ORDER BY f.fecha ASC
    ) f;

    -- Reflejar asignación en tabla Pago
    UPDATE p
    SET p.idFactura = pnf.idFacturaActual
    FROM dbo.Pago p
    JOIN #PagosNoFactura pnf ON pnf.idPago = p.id;


    ----------------------------------------------------------------------
    -- 2) PAGOS APLICABLES → descontar del totalFinal
    ----------------------------------------------------------------------
    UPDATE f
    SET f.totalFinal = f.totalFinal - p.monto
    FROM dbo.Factura f
    JOIN dbo.Pago p ON p.idFactura = f.id
    WHERE p.fecha <= @inFechaCorte;


    ----------------------------------------------------------------------
    -- 3) FACTURAS EN CERO O NEGATIVO → marcar pagadas
    ----------------------------------------------------------------------
    UPDATE dbo.Factura
    SET estado = 2      -- Pagado normal
    WHERE totalFinal <= 0
      AND estado = 1;


    ----------------------------------------------------------------------
    -- 4) CREAR COMPROBANTE DE PAGO
    ----------------------------------------------------------------------
    INSERT INTO dbo.ComprobantePago (idPago, fecha, monto, numeroReferencia)
    SELECT p.id, p.fecha, p.monto, p.numeroReferencia
    FROM dbo.Pago p
    WHERE p.fecha <= @inFechaCorte;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    SET @outResultCode = 70001;
END CATCH
END;
GO