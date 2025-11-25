CREATE OR ALTER   PROCEDURE [dbo].[usp_FacturacionMensualMasiva]
    (
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 60001;
        RETURN;
    END;

    DECLARE @diasVenc       INT;
    DECLARE @fechaEmision   DATE = @inFechaCorte;
    DECLARE @fechaVenc      DATE;

    -- Almacena el Consumo calculado por propiedad
    DECLARE @Consumos TABLE
    (
        idPropiedad INT PRIMARY KEY
        ,
        consumoM3 DECIMAL(10, 2)
        ,
        lecturaAnt DECIMAL(10, 2)
        ,
        lecturaAct DECIMAL(10, 2)
    );

    -- Almacena las propiedades a facturar y el ID generado
    DECLARE @FacturasBase TABLE
    (
        idPropiedad INT PRIMARY KEY
        ,
        fechaEmision DATE
        ,
        fechaVenc DATE
        ,
        idFactura INT      -- Se actualizará con el ID generado
    );

    -- Tabla de ayuda para el OUTPUT de IDs
    DECLARE @FacturasNewIDs TABLE
    (
        idFactura INT
        ,
        idPropiedad INT
    );

    -- Obtener días de vencimiento
    SELECT @diasVenc = TRY_CONVERT(INT, valor)
    FROM dbo.ParametroSistema
    WHERE clave = N'DiasVencimientoFactura';

    IF @diasVenc IS NULL
    BEGIN
        SET @outResultCode = 60002;
        RETURN;
    END;

    SET @fechaVenc = DATEADD(DAY, @diasVenc, @fechaEmision);

    BEGIN TRY

    -- 1)Calcular consumos del mes segun MovMedidor

    ;WITH
        Lecturas
        AS
        (
            -- Se obtiene la última lectura y la penúltima para calcular la diferencia
            SELECT
                m.idPropiedad,
                m.numeroMedidor,
                m.valor,
                m.fecha,
                LAG(m.valor, 1, 0) OVER ( --este lag se utiliza para calcular el consumo de agua al restar la lectura actual de la lectura inmediatamente anterior
                PARTITION BY m.numeroMedidor
                ORDER BY m.fecha ASC, m.id ASC
            ) AS lecturaAnterior,
                ROW_NUMBER() OVER (
                PARTITION BY m.numeroMedidor
                ORDER BY m.fecha DESC, m.id DESC
            ) AS rn
            FROM dbo.MovMedidor AS m
            WHERE (m.fecha <= @inFechaCorte)
                AND (m.idTipoMovimientoLecturaMedidor = 1)
            -- Solo lecturas
        )
    INSERT INTO @Consumos
        (
        idPropiedad
        ,consumoM3
        ,lecturaAnt
        ,lecturaAct
        )
    SELECT
        l.idPropiedad,
        (l.valor - l.lecturaAnterior) AS consumo,
        l.lecturaAnterior,
        l.valor
    FROM Lecturas AS l
    WHERE (l.rn = 1)
        AND (l.valor > l.lecturaAnterior); -- Consumo positivo

    -- 2 identificar propiedades a facturar

    INSERT INTO @FacturasBase
        (
        idPropiedad
        ,fechaEmision
        ,fechaVenc
        )
    SELECT
        pr.id
        , @fechaEmision
        , @fechaVenc
    FROM dbo.Propiedad AS pr
    -- Solo propiedades que tienen ConsumoAgua activo O algún otro CC mensual
    WHERE EXISTS
    (
        SELECT 1
    FROM dbo.CCPropiedad AS ccp
        JOIN dbo.CC AS cc ON cc.id = ccp.idCC
    WHERE (ccp.PropiedadId = pr.id)
        AND (ccp.fechaFin IS NULL)
        AND (cc.PeriodoMontoCC = 1 OR cc.nombre = N'ConsumoAgua') -- PeriodoMontoCC=1 es Mensual
    );

    BEGIN TRAN;

    INSERT INTO dbo.Factura
        (
        idPropiedad
        ,fecha
        ,fechaVenc
        ,totalOriginal -- Se actualizará más adelante
        ,totalFinal -- Se actualizará más adelante
        ,estado -- 1 = Pendiente
        )
    OUTPUT 
         inserted.id 
        ,inserted.idPropiedad
    INTO @FacturasNewIDs (idFactura, idPropiedad)
    -- Capturar IDs generados
    SELECT
        fb.idPropiedad
        , fb.fechaEmision
        , fb.fechaVenc
        , 0.0 -- Inicial
        , 0.0 -- Inicial
        , 1
    -- Pendiente
    FROM @FacturasBase AS fb;

    -- Actualizar @FacturasBase con los IDs generados
    UPDATE fb
    SET fb.idFactura = nid.idFactura
    FROM @FacturasBase AS fb
        JOIN @FacturasNewIDs AS nid
        ON nid.idPropiedad = fb.idPropiedad;

    -- 4 INSERCIÓN DE DETALLES DE FACTURA   
    -- 4.1 CONSUMO DE AGUA 
    INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto, m3Facturados )
    SELECT
        fb.idFactura, cc.id, cc.nombre,
        CASE
            WHEN c.consumoM3 <= cc_agua.ValorMinimoM3 THEN cc_agua.ValorMinimo
            ELSE cc_agua.ValorMinimo + ((c.consumoM3 - cc_agua.ValorMinimoM3) * cc_agua.ValorFijoM3Adicional)
        END AS monto,
        c.consumoM3
    FROM @FacturasBase AS fb
        JOIN @Consumos AS c ON c.idPropiedad = fb.idPropiedad
        JOIN dbo.CCPropiedad AS cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc ON cc.id = cp.idCC AND cc.nombre = N'ConsumoAgua'
        JOIN dbo.CC_ConsumoAgua AS cc_agua ON cc_agua.id = cc.id;

    -- 4.2 IMPUESTO DE PROPIEDAD (CC ID 3 - Trimestral / Porcentual)
    INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto )
    SELECT
        fb.idFactura, cc.id, cc.nombre,
        (pr.valorFiscal * cc_imp.ValorPorcentual) / 3.0
    -- Cargo Mensual (1/3 de trimestre)
    FROM @FacturasBase AS fb
        JOIN dbo.Propiedad AS pr ON pr.id = fb.idPropiedad
        JOIN dbo.CCPropiedad AS cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc ON cc.id = cp.idCC AND cc.nombre = N'ImpuestoPropiedad'
        JOIN dbo.CC_ImpuestoPropiedad AS cc_imp ON cc_imp.id = cc.id;

    -- 4.3 PATENTE COMERCIAL (CC ID 2 - Trimestral / Valor Fijo)
    INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto )
    SELECT
        fb.idFactura, cc.id, cc.nombre,
        pc.ValorFijo / 3.0
    -- Trimestral (PeriodoMontoCC=3) facturado mensual
    FROM @FacturasBase AS fb
        JOIN dbo.CCPropiedad AS cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc ON cc.id = cp.idCC AND cc.nombre = N'PatenteComercial'
        JOIN dbo.CC_PatenteComercial AS pc ON pc.id = cc.id; 

    -- 4.4 RECOLECCIÓN BASURA (CC ID 4 - Mensual / Valor Fijo + Tramos M2)
    INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto )
    SELECT
        fb.idFactura, cc.id, cc.nombre,
        CASE
            WHEN pr.metrosCuadrados <= rb.ValorM2Minimo 
            THEN rb.ValorMinimo
            ELSE rb.ValorMinimo +
                ((pr.metrosCuadrados - rb.ValorM2Minimo)* rb.ValorTramosM2)
        END
    FROM @FacturasBase AS fb
        JOIN dbo.Propiedad AS pr ON pr.id = fb.idPropiedad
        JOIN dbo.CCPropiedad AS cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc ON cc.id = cp.idCC AND cc.nombre = N'RecoleccionBasura'
        JOIN dbo.CC_RecoleccionBasura AS rb ON rb.id = cc.id; 

    -- 4.5 MANTENIMIENTO PARQUES (CC ID 5 - Mensual / Valor Fijo)
    INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto )
    SELECT
        fb.idFactura, cc.id, cc.nombre,
        mp.ValorFijo
    FROM @FacturasBase AS fb
        JOIN dbo.CCPropiedad AS cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc ON cc.id = cp.idCC AND cc.nombre = N'MantenimientoParques'
        JOIN dbo.CC_MantenimientoParques mp ON mp.id = cc.id

    --4.6 reconexion (si aplica)
     INSERT INTO dbo.DetalleFactura
        ( idFactura, idCC, descripcion, monto )
    SELECT
        fb.idFactura, cc.id, cc.nombre, r.ValorFijo
    FROM @FacturasBase AS fb
        JOIN CCPropiedad cp ON cp.PropiedadId = fb.idPropiedad AND cp.fechaFin IS NULL
        JOIN CC cc ON cc.id = cp.idCC AND cc.nombre = 'ReconexionAgua'
        Join CC_ReconexionAgua r ON r.id = cc.id;
    
    -- 5 ACTUALIZAR TOTALES
    -- 5.1 Recalcular el total por factura desde el DetalleFactura
    ;WITH
        Totales
        AS
        (
            SELECT idFactura, SUM(monto) AS total
            FROM dbo.DetalleFactura
            WHERE idFactura IN (SELECT idFactura
            FROM @FacturasBase)
            -- Solo las que acabamos de crear
            GROUP BY idFactura
        )
    -- 5.2 Actualizar las facturas recién creadas
    UPDATE f
    SET f.totalOriginal = t.total,
        f.totalFinal = t.total      -- Inicialmente, final es igual al original
    FROM dbo.Factura AS f
        JOIN Totales AS t
        ON t.idFactura = f.id;

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
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(),
            ERROR_PROCEDURE(), ERROR_MESSAGE(), SYSDATETIME()
    );

    SET @outResultCode = 60003;
    THROW;
END CATCH
END;
GO