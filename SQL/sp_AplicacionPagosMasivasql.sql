CREATE OR ALTER PROCEDURE dbo.usp_AplicacionPagosMasiva
(
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
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
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 65001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Seleccionar pagos sin factura asignada O con factura pendiente
    ----------------------------------------------------------------------
    SELECT 
        p.id              AS idPago,
        p.numeroFinca,
        p.monto,
        p.idFactura,
        pr.id             AS idPropiedad
    INTO #PagosPendientes
    FROM dbo.Pago p
    JOIN dbo.Propiedad pr ON pr.numeroFinca = p.numeroFinca
    WHERE p.fecha <= @inFechaCorte;

    ----------------------------------------------------------------------
    -- 2) Asignar factura más vieja si idFactura = NULL
    ----------------------------------------------------------------------
    UPDATE pp
    SET idFactura =
    (
        SELECT TOP 1 f.id
        FROM dbo.Factura f
        WHERE f.idPropiedad = pp.idPropiedad
          AND f.estado = 'Pendiente'
        ORDER BY f.fechaVenc
    )
    FROM #PagosPendientes pp
    WHERE pp.idFactura IS NULL;

    ----------------------------------------------------------------------
    -- 3) Aplicar pago a la factura correspondiente
    ----------------------------------------------------------------------
    UPDATE f
    SET f.totalFinal = f.totalFinal - pp.monto
    FROM dbo.Factura f
    JOIN #PagosPendientes pp ON pp.idFactura = f.id;

    ----------------------------------------------------------------------
    -- 4) Marcar facturas pagadas si totalFinal <= 0
    ----------------------------------------------------------------------
    UPDATE f
    SET f.estado = 'Pagada',
        f.totalFinal = 0
    FROM dbo.Factura f
    WHERE f.totalFinal <= 0;

    ----------------------------------------------------------------------
    -- 5) Generar Comprobante de Pago
    ----------------------------------------------------------------------
    INSERT INTO dbo.ComprobantePago
    (
        idPago,
        numeroFinca,
        fecha,
        monto
    )
    SELECT 
        pp.idPago,
        pp.numeroFinca,
        @inFechaCorte,
        pp.monto
    FROM #PagosPendientes pp;

    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH

    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    INSERT INTO dbo.DBErrors
    (
        UserName, Number, State, Severity, [Line],
        [Procedure], Message, DateTime
    )
    VALUES
    (
        SUSER_SNAME(),
        ERROR_NUMBER(),
        ERROR_STATE(),
        ERROR_SEVERITY(),
        ERROR_LINE(),
        ERROR_PROCEDURE(),
        ERROR_MESSAGE(),
        SYSDATETIME()
    );

    SET @outResultCode = 65002;

END CATCH;

END;
GO