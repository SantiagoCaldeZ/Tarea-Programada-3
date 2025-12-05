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
        -- 0) Solo ejecutar en FIN DE MES
        ----------------------------------------------------------------------
        IF @inFechaCorte <> EOMONTH(@inFechaCorte)
        BEGIN
            RETURN;
        END;

        DECLARE @PrimerDiaMes DATE = DATEFROMPARTS(YEAR(@inFechaCorte), MONTH(@inFechaCorte), 1);

        ----------------------------------------------------------------------
        -- 1) Propiedades con algún CC activo Y que no hayan sido facturadas este mes
        ----------------------------------------------------------------------
        DECLARE @Propiedades TABLE
        (
              idPropiedad INT PRIMARY KEY,
              numeroFinca NVARCHAR(64),
              metrosCuadrados INT,
              valorFiscal INT
        );

        INSERT INTO @Propiedades (idPropiedad, numeroFinca, metrosCuadrados, valorFiscal)
        SELECT DISTINCT
              p.id,
              p.numeroFinca,
              p.metrosCuadrados,
              p.valorFiscal
        FROM dbo.Propiedad p
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = p.id AND cp.fechaFin IS NULL
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.Factura f
            WHERE f.idPropiedad = p.id
              AND f.fecha >= @PrimerDiaMes
              AND f.fecha <= @inFechaCorte
        );

        IF NOT EXISTS (SELECT 1 FROM @Propiedades)
            RETURN;


        ----------------------------------------------------------------------
        -- 2) Crear FACTURAS
        ----------------------------------------------------------------------
        DECLARE @Facturas TABLE
        (
              idFactura INT,
              idPropiedad INT,
              numeroFinca NVARCHAR(64)
        );

        INSERT INTO dbo.Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
        SELECT
              p.idPropiedad,
              @inFechaCorte,
              DATEADD(DAY, 5, @inFechaCorte),
              0, 0, 1
        FROM @Propiedades p;

        INSERT INTO @Facturas (idFactura, idPropiedad, numeroFinca)
        SELECT
              f.id,
              f.idPropiedad,
              p.numeroFinca
        FROM dbo.Factura f
        JOIN @Propiedades p ON p.idPropiedad = f.idPropiedad
        WHERE f.fecha = @inFechaCorte;

        ----------------------------------------------------------------------
        -- 3) Obtener tarifas desde CC + Tarifa
        ----------------------------------------------------------------------
        ;WITH CCTarifas AS
        (
            SELECT
                  cc.id AS idCC,
                  cc.nombre AS nombreCC,
                  cc.periodoMonto AS periodoMonto,
                  cc.tipoMontoCC AS tipoMonto,
                  t.monto AS montoTarifa
            FROM dbo.CC cc
            LEFT JOIN dbo.Tarifa t ON t.id = cc.idTarifa
        ),

        ----------------------------------------------------------------------
        -- 4) Lecturas de agua (actual y anterior)
        ----------------------------------------------------------------------
        LecturaActual AS
        (
            SELECT
                  p.idPropiedad,
                  MAX(m.fecha) AS fechaActual
            FROM @Propiedades p
            LEFT JOIN dbo.MovMedidor m
                ON m.idPropiedad = p.idPropiedad
                AND m.fecha >= @PrimerDiaMes
                AND m.fecha <= @inFechaCorte
            GROUP BY p.idPropiedad
        ),
        ValorActual AS
        (
            SELECT
                  la.idPropiedad,
                  m.valor AS lecturaActual
            FROM LecturaActual la
            LEFT JOIN dbo.MovMedidor m
                ON m.idPropiedad = la.idPropiedad
                AND m.fecha = la.fechaActual
        ),
        ValorAnterior AS
        (
            SELECT
                  p.idPropiedad,
                  ISNULL(
                      (
                          SELECT TOP 1 m2.valor
                          FROM dbo.MovMedidor m2
                          WHERE m2.idPropiedad = p.idPropiedad
                            AND m2.fecha < @PrimerDiaMes
                          ORDER BY m2.fecha DESC
                      ), 0
                  ) AS lecturaAnterior
            FROM @Propiedades p
        ),

        ----------------------------------------------------------------------
        -- 5) Unir todo lo necesario para facturar AGUA
        ----------------------------------------------------------------------
        Consumo AS
        (
            SELECT
                  f.idFactura,
                  f.idPropiedad,
                  a.lecturaActual,
                  b.lecturaAnterior
            FROM @Facturas f
            LEFT JOIN ValorActual a ON a.idPropiedad = f.idPropiedad
            LEFT JOIN ValorAnterior b ON b.idPropiedad = f.idPropiedad
        )

        ----------------------------------------------------------------------
        -- 6) Facturar CONSUMO DE AGUA
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
        (
              idFactura,
              idCC,
              descripcion,
              monto
        )
        SELECT
              c.idFactura,
              cc.idCC,
              cc.nombreCC,
              CASE 
                  WHEN c.lecturaActual IS NULL THEN ct.montoTarifa
                  ELSE 
                  (
                      -- cálculo correcto según XML
                      CASE 
                          WHEN (c.lecturaActual - c.lecturaAnterior) <= 30
                               THEN 500
                          ELSE 500 + ((c.lecturaActual - c.lecturaAnterior) - 30) * 100
                      END
                  )
              END
        FROM Consumo c
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = c.idPropiedad AND cp.fechaFin IS NULL
        JOIN CCTarifas cc ON cc.idCC = cp.idCC AND cc.nombreCC = N'ConsumoAgua'
        JOIN CCTarifas ct ON ct.idCC = cc.idCC;


        ----------------------------------------------------------------------
        -- 7) Recolección de Basura
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura (idFactura, idCC, descripcion, monto)
        SELECT
              f.idFactura,
              cc.idCC,
              cc.nombreCC,
              CASE 
                  WHEN p.metrosCuadrados <= 400 THEN 150
                  ELSE 150 + CEILING( (p.metrosCuadrados - 400) / 75.0 ) * 300
              END
        FROM @Facturas f
        JOIN @Propiedades p ON p.idPropiedad = f.idPropiedad
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
        JOIN CCTarifas cc ON cc.idCC = cp.idCC AND cc.nombreCC = N'RecoleccionBasura';


        ----------------------------------------------------------------------
        -- 8) Mantenimiento Parques
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura (idFactura, idCC, descripcion, monto)
        SELECT
              f.idFactura,
              cc.idCC,
              cc.nombreCC,
              cc.montoTarifa
        FROM @Facturas f
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
        JOIN CCTarifas cc ON cc.idCC = cp.idCC AND cc.nombreCC = N'MantenimientoParques';


        ----------------------------------------------------------------------
        -- 9) Patente Comercial (trimestral → prorrateo mensual)
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura (idFactura, idCC, descripcion, monto)
        SELECT
              f.idFactura,
              cc.idCC,
              cc.nombreCC,
              (cc.montoTarifa / 3)
        FROM @Facturas f
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
        JOIN CCTarifas cc ON cc.idCC = cp.idCC AND cc.nombreCC = N'PatenteComercial';


        ----------------------------------------------------------------------
        -- 10) Impuesto Propiedad (anual → prorrateo mensual)
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura (idFactura, idCC, descripcion, monto)
        SELECT
              f.idFactura,
              cc.idCC,
              cc.nombreCC,
              (p.valorFiscal * 0.01) / 12
        FROM @Facturas f
        JOIN @Propiedades p ON p.idPropiedad = f.idPropiedad
        JOIN dbo.CCPropiedad cp ON cp.PropiedadId = f.idPropiedad AND cp.fechaFin IS NULL
        JOIN CCTarifas cc ON cc.idCC = cp.idCC AND cc.nombreCC = N'ImpuestoPropiedad';


        ----------------------------------------------------------------------
        -- 11) Actualizar totales
        ----------------------------------------------------------------------
        UPDATE f
        SET 
            f.totalOriginal = x.total,
            f.totalFinal = x.total
        FROM dbo.Factura f
        JOIN
        (
            SELECT idFactura, SUM(monto) AS total
            FROM dbo.DetalleFactura
            GROUP BY idFactura
        ) x ON x.idFactura = f.id;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 54000;

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

    END CATCH
END;
GO

EXEC dbo.usp_FacturacionMensualMasiva
    @inFechaCorte = '2024-01-31',
    @outResultCode = NULL;
