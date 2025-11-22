CREATE OR ALTER PROCEDURE dbo.usp_FacturacionMensualMasiva
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
    -- 0) VALIDACIÓN
    ----------------------------------------------------------------------
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 60001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) OBTENER CONSUMOS DEL MES (solo ConsumoAgua)
    ----------------------------------------------------------------------
    ;WITH Lect AS
    (
        SELECT 
            m.idPropiedad,
            m.numeroMedidor,
            m.valor,
            ROW_NUMBER() OVER (PARTITION BY m.numeroMedidor ORDER BY m.fecha DESC) AS rnDesc
        FROM dbo.MovMedidor m
        WHERE m.idTipoMovimientoLecturaMedidor = 1
          AND MONTH(m.fecha) = MONTH(@inFechaCorte)
          AND YEAR(m.fecha)  = YEAR(@inFechaCorte)
    )
    SELECT 
        idPropiedad,
        valor AS consumoMes
    INTO #Consumos
    FROM Lect
    WHERE rnDesc = 1;

    ----------------------------------------------------------------------
    -- 2) CREAR FACTURAS (una por propiedad)
    ----------------------------------------------------------------------
    INSERT INTO dbo.Factura
    (
        idPropiedad,
        fecha,
        fechaVencimiento,
        estado,
        montoTotal
    )
    SELECT 
        p.id,
        @inFechaCorte,
        DATEADD(DAY, ps.DiasVencimientoFactura, @inFechaCorte),
        'Pendiente',
        0
    FROM dbo.Propiedad p
    CROSS JOIN dbo.ParametrosSistema ps;

    ----------------------------------------------------------------------
    -- 3) OBTENER FACTURAS CREADAS
    ----------------------------------------------------------------------
    SELECT id AS idFactura, idPropiedad
    INTO #Facturas
    FROM dbo.Factura
    WHERE fecha = @inFechaCorte;

    ----------------------------------------------------------------------
    -- 4) AGREGAR DETALLES SEGÚN CC ASOCIADA
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- 4.1 ConsumoAgua
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT 
        f.idFactura,
        cc.id,
        cc.nombre,
        CASE 
            WHEN c.consumoMes < agua.ValorMinimoM3
                THEN agua.ValorMinimo
            ELSE 
                agua.ValorMinimo 
                + ((c.consumoMes - agua.ValorMinimoM3) * agua.ValorFijoM3Adicional)
        END AS monto
    FROM #Facturas f
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'ConsumoAgua'
    JOIN dbo.CC_ConsumoAgua agua ON agua.id = cc.id
    LEFT JOIN #Consumos c ON c.idPropiedad = f.idPropiedad;

    ----------------------------------------------------------------------
    -- 4.2 RecoleccionBasura
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT 
        f.idFactura,
        cc.id,
        cc.nombre,
        CASE 
            WHEN p.metrosCuadrados < bas.ValorM2Minimo 
                THEN bas.ValorMinimo
            ELSE 
                bas.ValorMinimo + ((p.metrosCuadrados - bas.ValorM2Minimo) * bas.ValorTramosM2)
        END
    FROM #Facturas f
    JOIN dbo.Propiedad p ON p.id = f.idPropiedad
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'RecoleccionBasura'
    JOIN dbo.CC_RecoleccionBasura bas ON bas.id = cc.id;

    ----------------------------------------------------------------------
    -- 4.3 PatenteComercial
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT
        f.idFactura,
        cc.id,
        cc.nombre,
        pat.ValorFijo
    FROM #Facturas f
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'PatenteComercial'
    JOIN dbo.CC_PatenteComercial pat ON pat.id = cc.id;

    ----------------------------------------------------------------------
    -- 4.4 ImpuestoPropiedad
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT 
        f.idFactura,
        cc.id,
        cc.nombre,
        p.valorFiscal * imp.ValorPorcentual
    FROM #Facturas f
    JOIN dbo.Propiedad p ON p.id = f.idPropiedad
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'ImpuestoPropiedad'
    JOIN dbo.CC_ImpuestoPropiedad imp ON imp.id = cc.id;

    ----------------------------------------------------------------------
    -- 4.5 MantenimientoParques
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT 
        f.idFactura,
        cc.id,
        cc.nombre,
        mp.ValorFijo
    FROM #Facturas f
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'MantenimientoParques'
    JOIN dbo.CC_MantenimientoParques mp ON mp.id = cc.id;

    ----------------------------------------------------------------------
    -- 4.6 ReconexionAgua
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT
        f.idFactura,
        cc.id,
        cc.nombre,
        rec.ValorFijo
    FROM #Facturas f
    JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN dbo.CC cc ON cc.id = cp.idCC AND cc.nombre = 'ReconexionAgua'
    JOIN dbo.CC_ReconexionAgua rec ON rec.id = cc.id;

    ----------------------------------------------------------------------
    -- 5) ACTUALIZAR MONTO TOTAL DE CADA FACTURA
    ----------------------------------------------------------------------
    UPDATE F
    SET montoTotal = X.total
    FROM dbo.Factura F
    JOIN (
        SELECT idFactura, SUM(monto) AS total
        FROM dbo.FacturaDetalle
        GROUP BY idFactura
    ) X ON X.idFactura = F.id;

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

    SET @outResultCode = 60002;
END CATCH;

END;
GO