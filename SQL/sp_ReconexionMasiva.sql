CREATE OR ALTER PROCEDURE dbo.usp_ReconexionMasiva
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
        SET @outResultCode = 63001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Obtener idCC de ReconexionAgua
    ----------------------------------------------------------------------
    DECLARE @idCC_Reconexion INT;

    SELECT @idCC_Reconexion = cc.id
    FROM dbo.CC cc
    WHERE cc.nombre = 'ReconexionAgua';

    IF @idCC_Reconexion IS NULL
    BEGIN
        SET @outResultCode = 63002; -- Falta CC de reconexión
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 2) Propiedades con corte y facturas pagadas
    ----------------------------------------------------------------------
    ;WITH CortesPendientes AS
    (
        SELECT 
            oc.id              AS idOrdenCorta,
            oc.idPropiedad,
            oc.idFacturaCausa,
            oc.estadoCorta
        FROM dbo.OrdenCorta oc
        WHERE oc.estadoCorta = 1   -- 1 = cortado
    ),
    PagosValidos AS
    (
        SELECT 
            p.idFactura,
            p.numeroFinca,
            p.id AS idPago
        FROM dbo.Pago p
        WHERE p.fecha <= @inFechaCorte
          AND p.idFactura IS NOT NULL
    ),
    FacturasCanceladas AS
    (
        SELECT 
            f.id AS idFactura,
            f.idPropiedad
        FROM dbo.Factura f
        WHERE f.estado = 3   -- 3 = pagada
    )
    SELECT 
        cp.idOrdenCorta,
        cp.idPropiedad,
        fv.idFactura,
        pv.idPago
    INTO #ReconexionPend
    FROM CortesPendientes cp
    JOIN FacturasCanceladas fv ON fv.idFactura = cp.idFacturaCausa
    JOIN PagosValidos pv      ON pv.idFactura  = fv.idFactura;

    ----------------------------------------------------------------------
    -- Si no hay nada que reconectar, salir
    ----------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM #ReconexionPend)
    BEGIN
        SET @outResultCode = 63003; -- No había propiedades para reconectar
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 3) Insertar orden de reconexión
    ----------------------------------------------------------------------
    INSERT INTO dbo.OrdenReconexion
    (
        idPropiedad,
        idOrdenCorta,
        idFacturaPago,
        estadoReconexion
    )
    SELECT
        r.idPropiedad,
        r.idOrdenCorta,
        r.idFactura,
        1  -- 1 = ejecutado
    FROM #ReconexionPend r;

    ----------------------------------------------------------------------
    -- 4) Actualizar propiedad → aguaCortada = 0
    ----------------------------------------------------------------------
    UPDATE p
    SET p.aguaCortada = 0
    FROM dbo.Propiedad p
    JOIN #ReconexionPend r ON r.idPropiedad = p.id;

    ----------------------------------------------------------------------
    -- 5) Insertar detalle de reconexión en FacturaDetalle
    ----------------------------------------------------------------------
    DECLARE @montoFijo INT;

    SELECT @montoFijo = ra.ValorFijo
    FROM dbo.CC_ReconexionAgua ra
    WHERE ra.id = @idCC_Reconexion;

    INSERT INTO dbo.DetalleFactura
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT 
        r.idFactura,
        @idCC_Reconexion,
        'Reconexión del servicio de agua',
        @montoFijo
    FROM #ReconexionPend r;

    ----------------------------------------------------------------------
    -- 6) Actualizar totalFinal de las facturas
    ----------------------------------------------------------------------
    UPDATE f
    SET f.totalFinal = df.total
    FROM dbo.Factura f
    JOIN (
        SELECT idFactura, SUM(monto) AS total
        FROM dbo.DetalleFactura
        GROUP BY idFactura
    ) df ON df.idFactura = f.id;

    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    INSERT INTO dbo.DBErrors
    (
        UserName, Number, State, Severity, [Line], [Procedure], Message, DateTime
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

    SET @outResultCode = 63004;
END CATCH;

END;
GO