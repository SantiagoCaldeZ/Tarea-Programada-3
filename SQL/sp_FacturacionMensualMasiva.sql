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
    ----------------------------------------------------------------------
    -- VALIDACIONES
    ----------------------------------------------------------------------
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 60001;
        RETURN;
    END;

    DECLARE @diasVenc INT;

    SELECT @diasVenc = TRY_CONVERT(INT, valor)
    FROM dbo.ParametroSistema
    WHERE clave = 'DiasVencimientoFactura';

    IF @diasVenc IS NULL
    BEGIN
        SET @outResultCode = 60002;
        RETURN;
    END;

    BEGIN TRAN;

    ----------------------------------------------------------------------
    -- 1) CALCULAR CONSUMOS DEL MES SEGÚN MOVMEDIDOR
    ----------------------------------------------------------------------
    ;WITH Lecturas AS
    (
        SELECT
            m.idPropiedad,
            m.numeroMedidor,
            m.valor,
            m.fecha,
            ROW_NUMBER() OVER (
                PARTITION BY m.numeroMedidor
                ORDER BY m.fecha DESC, m.id DESC
            ) AS rn
        FROM dbo.MovMedidor m
        WHERE m.idTipoMovimientoLecturaMedidor = 1
          AND MONTH(m.fecha) = MONTH(@inFechaCorte)
          AND YEAR(m.fecha)  = YEAR(@inFechaCorte)
    ),
    UltimaLectura AS
    (
        SELECT idPropiedad, numeroMedidor, valor AS valorActual, fecha
        FROM Lecturas WHERE rn = 1
    ),
    LecturaAnterior AS
    (
        SELECT
            u.numeroMedidor,
            ( SELECT TOP 1 m2.valor
              FROM dbo.MovMedidor m2
              WHERE m2.numeroMedidor = u.numeroMedidor
                AND m2.fecha < u.fecha
                AND m2.idTipoMovimientoLecturaMedidor = 1
              ORDER BY m2.fecha DESC, m2.id DESC
            ) AS valorAnterior
        FROM UltimaLectura u
    )
    SELECT
        u.idPropiedad,
        u.numeroMedidor,
        u.valorActual,
        ISNULL(a.valorAnterior, 0) AS valorAnterior,
        u.valorActual - ISNULL(a.valorAnterior, 0) AS consumoMes
    INTO #Consumos
    FROM UltimaLectura u
    LEFT JOIN LecturaAnterior a
           ON a.numeroMedidor = u.numeroMedidor;

    ----------------------------------------------------------------------
    -- 2) CREAR FACTURA POR PROPIEDAD
    ----------------------------------------------------------------------
    INSERT INTO dbo.Factura
    (
        idPropiedad,
        fecha,
        fechaVenc,
        totalOriginal,
        totalFinal,
        estado
    )
    SELECT
        p.id,
        @inFechaCorte,
        DATEADD(DAY, @diasVenc, @inFechaCorte),
        0, 0,
        1   -- Pendiente
    FROM dbo.Propiedad p
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.Factura f
        WHERE f.idPropiedad = p.id
          AND f.fecha = @inFechaCorte
    );

    ----------------------------------------------------------------------
    -- 3) OBTENER LAS FACTURAS CREADAS
    ----------------------------------------------------------------------
    SELECT id AS idFactura, idPropiedad
    INTO #Facturas
    FROM dbo.Factura
    WHERE fecha = @inFechaCorte;

    ----------------------------------------------------------------------
    -- 4) INSERTAR DETALLES POR CADA CC
    ----------------------------------------------------------------------

    ---------------------------
    -- CONSUMO AGUA
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    (
        idFactura, idCC, descripcion, monto, m3Facturados
    )
    SELECT
        f.idFactura,
        cc.id,
        cc.nombre,
        CASE WHEN c.consumoMes < agua.ValorMinimoM3
             THEN agua.ValorMinimo
             ELSE agua.ValorMinimo + 
                 ((c.consumoMes - agua.ValorMinimoM3) * agua.ValorFijoM3Adicional)
        END AS monto,
        c.consumoMes
    FROM #Facturas f
    JOIN CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN CC cc          ON cc.id = cp.idCC AND cc.nombre = 'ConsumoAgua'
    JOIN CC_ConsumoAgua agua ON agua.id = cc.id
    LEFT JOIN #Consumos c ON c.idPropiedad = f.idPropiedad;

    ---------------------------
    -- BASURA
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    (
        idFactura, idCC, descripcion, monto
    )
    SELECT
        f.idFactura, cc.id, cc.nombre,
        CASE WHEN p.metrosCuadrados < bas.ValorM2Minimo
             THEN bas.ValorMinimo
             ELSE bas.ValorMinimo + 
                 ((p.metrosCuadrados - bas.ValorM2Minimo) * bas.ValorTramosM2)
        END
    FROM #Facturas f
    JOIN Propiedad p ON p.id = f.idPropiedad
    JOIN CCPropiedad cp ON cp.PropiedadId = p.id AND cp.fechaFin IS NULL
    JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'RecoleccionBasura'
    JOIN CC_RecoleccionBasura bas ON bas.id = cc.id;

    ---------------------------
    -- PATENTE COMERCIAL
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    ( idFactura, idCC, descripcion, monto )
    SELECT
        f.idFactura, cc.id, cc.nombre, pat.ValorFijo
    FROM #Facturas f
    JOIN CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'PatenteComercial'
    JOIN CC_PatenteComercial pat ON pat.id = cc.id;

    ---------------------------
    -- IMPUESTO PROPIEDAD
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    ( idFactura, idCC, descripcion, monto )
    SELECT
        f.idFactura, cc.id, cc.nombre,
        p.valorFiscal * imp.ValorPorcentual
    FROM #Facturas f
    JOIN Propiedad p ON p.id = f.idPropiedad
    JOIN CCPropiedad cp ON cp.PropiedadId = p.id AND cp.fechaFin IS NULL
    JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'ImpuestoPropiedad'
    JOIN CC_ImpuestoPropiedad imp ON imp.id = cc.id;

    ---------------------------
    -- MANTENIMIENTO PARQUES
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    ( idFactura, idCC, descripcion, monto )
    SELECT
        f.idFactura, cc.id, cc.nombre, mp.ValorFijo
    FROM #Facturas f
    JOIN CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'MantenimientoParques'
    JOIN CC_MantenimientoParques mp ON mp.id = cc.id;

    ---------------------------
    -- RECONEXIÓN (si aplica)
    ---------------------------
    INSERT INTO dbo.DetalleFactura
    ( idFactura, idCC, descripcion, monto )
    SELECT
        f.idFactura, cc.id, cc.nombre, r.ValorFijo
    FROM #Facturas f
    JOIN CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
    JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'ReconexionAgua'
    JOIN CC_ReconexionAgua r ON r.id = cc.id;

    ----------------------------------------------------------------------
    -- 5) ACTUALIZAR TOTALES
    ----------------------------------------------------------------------
    ;WITH Totales AS
    (
        SELECT idFactura, SUM(monto) AS total
        FROM dbo.DetalleFactura
        WHERE idFactura IN (SELECT idFactura FROM #Facturas)
        GROUP BY idFactura
    )
    UPDATE f
    SET f.totalOriginal = t.total,
        f.totalFinal = t.total
    FROM dbo.Factura f
    JOIN Totales t ON t.idFactura = f.id;

    ----------------------------------------------------------------------
    COMMIT TRAN;
END TRY
BEGIN CATCH

    IF (XACT_STATE() <> 0) ROLLBACK TRAN;

    SET @outResultCode = 60005;

END CATCH;
END;
GO