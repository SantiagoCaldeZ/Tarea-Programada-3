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
        -- 0) VALIDACIÓN BÁSICA + LECTURA DE PARÁMETROS (FUERA DE LA TRANSACCIÓN)
        ----------------------------------------------------------------------
        IF @inFechaCorte IS NULL
        BEGIN
            SET @outResultCode = 60001;  -- fecha nula
            RETURN;
        END;

        DECLARE @diasVencimiento INT;

        SELECT
            @diasVencimiento = TRY_CONVERT(INT, ps.valor)
        FROM dbo.ParametroSistema AS ps
        WHERE ps.clave = N'DiasVencimientoFactura';

        IF @diasVencimiento IS NULL
        BEGIN
            SET @outResultCode = 60003;  -- Falta parámetro DiasVencimientoFactura
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- INICIO TRANSACCIÓN
        ----------------------------------------------------------------------
        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 1) OBTENER CONSUMOS DEL MES (solo ConsumoAgua)
        --    Para cada medidor: última lectura del mes y consumo respecto a la anterior
        ----------------------------------------------------------------------
        ;WITH Lecturas AS
        (
            SELECT 
                m.idPropiedad,
                m.numeroMedidor,
                m.valor,
                m.fecha,
                ROW_NUMBER() OVER
                (
                    PARTITION BY m.numeroMedidor
                    ORDER BY m.fecha DESC, m.id DESC
                ) AS rnDesc
            FROM dbo.MovMedidor AS m
            WHERE m.idTipoMovimientoLecturaMedidor = 1
              AND MONTH(m.fecha) = MONTH(@inFechaCorte)
              AND YEAR(m.fecha)  = YEAR(@inFechaCorte)
        ),
        UltimaLecturaMes AS
        (
            SELECT
                l.idPropiedad,
                l.numeroMedidor,
                l.valor       AS lecturaActual,
                l.fecha       AS fechaLectura
            FROM Lecturas AS l
            WHERE l.rnDesc = 1
        ),
        LecturaAnterior AS
        (
            SELECT
                m.numeroMedidor,
                m.valor AS lecturaAnterior
            FROM dbo.MovMedidor AS m
            JOIN UltimaLecturaMes AS u
                ON u.numeroMedidor = m.numeroMedidor
            WHERE m.fecha < u.fechaLectura
              AND m.idTipoMovimientoLecturaMedidor = 1
              AND m.fecha =
              (
                  SELECT MAX(m2.fecha)
                  FROM dbo.MovMedidor AS m2
                  WHERE m2.numeroMedidor = m.numeroMedidor
                    AND m2.idTipoMovimientoLecturaMedidor = 1
                    AND m2.fecha < u.fechaLectura
              )
        )
        SELECT 
            u.idPropiedad,
            u.numeroMedidor,
            u.lecturaActual,
            ISNULL(a.lecturaAnterior, 0)                    AS lecturaAnterior,
            u.lecturaActual - ISNULL(a.lecturaAnterior, 0)  AS consumoMes
        INTO #Consumos
        FROM UltimaLecturaMes  AS u
        LEFT JOIN LecturaAnterior AS a
            ON a.numeroMedidor = u.numeroMedidor;

        ----------------------------------------------------------------------
        -- 2) CREAR FACTURAS (una por propiedad)
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
            DATEADD(DAY, @diasVencimiento, @inFechaCorte),
            0,      -- totalOriginal (se actualiza luego)
            0,      -- totalFinal (se actualiza luego)
            1       -- 1 = Pendiente de pago
        FROM dbo.Propiedad AS p
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.Factura AS f
            WHERE f.idPropiedad = p.id
              AND f.fecha       = @inFechaCorte
        );

        ----------------------------------------------------------------------
        -- 3) OBTENER FACTURAS CREADAS EN ESTA CORRIDA
        ----------------------------------------------------------------------
        SELECT
            f.id         AS idFactura,
            f.idPropiedad
        INTO #Facturas
        FROM dbo.Factura AS f
        WHERE f.fecha = @inFechaCorte;

        ----------------------------------------------------------------------
        -- 4) AGREGAR DETALLES SEGÚN CC ASOCIADA
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- 4.1 ConsumoAgua
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
        (
            idFactura,
            idCC,
            descripcion,
            monto,
            m3Facturados
        )
        SELECT 
            f.idFactura,
            cc.id,
            cc.nombre,
            CASE 
                WHEN ISNULL(c.consumoMes, 0) <= 0
                    THEN 0
                WHEN ISNULL(c.consumoMes, 0) < agua.ValorMinimoM3
                    THEN agua.ValorMinimo
                ELSE 
                    agua.ValorMinimo 
                    + ((ISNULL(c.consumoMes, 0) - agua.ValorMinimoM3)
                        * agua.ValorFijoM3Adicional)
            END AS monto,
            ISNULL(c.consumoMes, 0) AS m3Facturados
        FROM #Facturas AS f
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'ConsumoAgua'
        JOIN dbo.CC_ConsumoAgua AS agua
            ON agua.id = cc.id
        LEFT JOIN #Consumos AS c
            ON c.idPropiedad = f.idPropiedad;

        ----------------------------------------------------------------------
        -- 4.2 RecoleccionBasura
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
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
                    bas.ValorMinimo
                    + ((p.metrosCuadrados - bas.ValorM2Minimo)
                        * bas.ValorTramosM2)
            END
        FROM #Facturas AS f
        JOIN dbo.Propiedad AS p
            ON p.id = f.idPropiedad
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'RecoleccionBasura'
        JOIN dbo.CC_RecoleccionBasura AS bas
            ON bas.id = cc.id;

        ----------------------------------------------------------------------
        -- 4.3 PatenteComercial
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
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
        FROM #Facturas AS f
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'PatenteComercial'
        JOIN dbo.CC_PatenteComercial AS pat
            ON pat.id = cc.id;

        ----------------------------------------------------------------------
        -- 4.4 ImpuestoPropiedad
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
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
        FROM #Facturas AS f
        JOIN dbo.Propiedad AS p
            ON p.id = f.idPropiedad
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'ImpuestoPropiedad'
        JOIN dbo.CC_ImpuestoPropiedad AS imp
            ON imp.id = cc.id;

        ----------------------------------------------------------------------
        -- 4.5 MantenimientoParques
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
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
        FROM #Facturas AS f
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'MantenimientoParques'
        JOIN dbo.CC_MantenimientoParques AS mp
            ON mp.id = cc.id;

        ----------------------------------------------------------------------
        -- 4.6 ReconexionAgua
        --    (OJO: si al final prefieres que solo se cobre en usp_ReconexionMasiva,
        --          se puede eliminar esta sección para no duplicar cobros)
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
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
        FROM #Facturas AS f
        JOIN dbo.CCPropiedad AS cp
            ON cp.PropiedadId = f.idPropiedad
           AND cp.fechaFin IS NULL
        JOIN dbo.CC AS cc
            ON cc.id = cp.idCC
           AND cc.nombre = N'ReconexionAgua'
        JOIN dbo.CC_ReconexionAgua AS rec
            ON rec.id = cc.id;

        ----------------------------------------------------------------------
        -- 5) ACTUALIZAR TOTALES DE LAS FACTURAS CREADAS EN ESTA CORRIDA
        ----------------------------------------------------------------------
        ;WITH Totales AS
        (
            SELECT 
                d.idFactura,
                SUM(d.monto) AS total
            FROM dbo.DetalleFactura AS d
            JOIN #Facturas AS nf
                ON nf.idFactura = d.idFactura
            GROUP BY d.idFactura
        )
        UPDATE f
        SET 
            f.totalOriginal = t.total,
            f.totalFinal    = t.total    -- al inicio son iguales
        FROM dbo.Factura AS f
        JOIN Totales AS t
            ON t.idFactura = f.id;

        ----------------------------------------------------------------------
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
            ROLLBACK TRAN;

        INSERT INTO dbo.DBErrors
        (
            UserName,
            Number,
            State,
            Severity,
            [Line],
            [Procedure],
            Message,
            DateTime
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