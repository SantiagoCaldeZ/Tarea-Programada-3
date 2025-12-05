CREATE OR ALTER PROCEDURE dbo.usp_Xml_CargarSimulacion
(
      @inIdXml        INT
    , @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @xml         XML;
    DECLARE @fechaActual DATE;

    -- Tabla variable de fechas de operación
    DECLARE @Fechas TABLE
    (
          idFecha INT IDENTITY(1,1) PRIMARY KEY
        , fecha   DATE NOT NULL
    );

    -- DESACTIVAR TRIGGER (para evitar errores dentro de la transacción masiva XML)
    DISABLE TRIGGER TR_Propiedad_AI_AsociaCCDefault ON dbo.Propiedad;

    SET @outResultCode = 0;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 0) Cargar XML desde XmlFuente y preprocesar fechas (fuera de la TX)
        ----------------------------------------------------------------------
        SELECT
            @xml = xf.XmlContenido
        FROM dbo.XmlFuente AS xf
        WHERE xf.IdXml = @inIdXml;

        IF (@xml IS NULL)
        BEGIN
            SET @outResultCode = 50001;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- Insertar fechas únicas sin ORDER BY (evita error con DISTINCT)
        ----------------------------------------------------------------------
        INSERT INTO @Fechas (fecha)
        SELECT DISTINCT
            F.N.value('@fecha','date')
        FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N);

        DECLARE @idFecha    INT;
        DECLARE @maxIdFecha INT;

        SELECT @maxIdFecha = MAX(idFecha) FROM @Fechas;
        SET @idFecha = 1;

        ----------------------------------------------------------------------
        -- 1) Transacción: simulación completa día por día
        ----------------------------------------------------------------------
        BEGIN TRAN;

        WHILE (@idFecha <= @maxIdFecha)
        BEGIN
            SELECT @fechaActual = fecha
            FROM @Fechas
            WHERE idFecha = @idFecha;

            ------------------------------------------------------------------
            -- 1. PERSONAS de la fecha actual
            ------------------------------------------------------------------
            ;WITH FechaActual AS
            (
                SELECT F.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.Persona
            (
                  valorDocumento
                , nombre
                , email
                , telefono
            )
            SELECT
                  T.N.value('@valorDocumento','nvarchar(64)')
                , T.N.value('@nombre','nvarchar(64)')
                , T.N.value('@email','nvarchar(64)')
                , T.N.value('@telefono','nvarchar(64)')
            FROM FechaActual AS FA
            CROSS APPLY FA.FechaNode.nodes('Personas/Persona') AS T(N)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Persona AS p
                WHERE p.valorDocumento = T.N.value('@valorDocumento','nvarchar(64)')
            );

            ------------------------------------------------------------------
            -- 2. PROPIEDADES de la fecha actual
            ------------------------------------------------------------------
            ;WITH FechaActual AS
            (
                SELECT F.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.Propiedad
            (
                  numeroFinca
                , metrosCuadrados
                , idTipoUsoPropiedad
                , idTipoZonaPropiedad
                , valorFiscal
                , fechaRegistro
                , numeroMedidor
            )
            SELECT
                  T.N.value('@numeroFinca','nvarchar(64)')
                , T.N.value('@metrosCuadrados','int')
                , T.N.value('@tipoUsoId','int')
                , T.N.value('@tipoZonaId','int')
                , T.N.value('@valorFiscal','int')
                , T.N.value('@fechaRegistro','date')
                , T.N.value('@numeroMedidor','nvarchar(64)')
            FROM FechaActual AS FA
            CROSS APPLY FA.FechaNode.nodes('Propiedades/Propiedad') AS T(N)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Propiedad AS pr
                WHERE pr.numeroFinca = T.N.value('@numeroFinca','nvarchar(64)')
            );

            ------------------------------------------------------------------
            -- 3. MOVIMIENTOS PropiedadPersona del día
            ------------------------------------------------------------------

            ------------------------------------------------------------------
            -- 3A. ASOCIAR
            ------------------------------------------------------------------
            ;WITH MovPP AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@valorDocumento','nvarchar(64)') AS valorDocumento
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@tipoAsociacionId','int') AS tipoAsociacionId
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('PropiedadPersona/Movimiento') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            ),
            MovPP_Asociar AS
            (
                SELECT * FROM MovPP WHERE tipoAsociacionId = 1
            ),
            BaseIdPP AS
            (
                SELECT ISNULL(MAX(pp.id),0) AS baseId
                FROM dbo.PropiedadPersona AS pp
            )
            INSERT INTO dbo.PropiedadPersona
            (
                  id
                , fechaInicio
                , fechaFin
                , idPersona
                , idPropiedad
            )
            SELECT
                  B.baseId + ROW_NUMBER() OVER (ORDER BY M.fechaOperacion, M.numeroFinca, M.valorDocumento)
                , M.fechaOperacion
                , NULL
                , per.id
                , pr.id
            FROM MovPP_Asociar AS M
            JOIN dbo.Persona AS per
                ON per.valorDocumento = M.valorDocumento
            JOIN dbo.Propiedad AS pr
                ON pr.numeroFinca = M.numeroFinca
            CROSS JOIN BaseIdPP AS B
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.PropiedadPersona AS pp
                WHERE pp.idPersona = per.id
                  AND pp.idPropiedad = pr.id
                  AND pp.fechaFin IS NULL
            );

            ------------------------------------------------------------------
            -- 3B. DESASOCIAR
            ------------------------------------------------------------------
            ;WITH MovPP AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@valorDocumento','nvarchar(64)') AS valorDocumento
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@tipoAsociacionId','int') AS tipoAsociacionId
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('PropiedadPersona/Movimiento') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            UPDATE pp
            SET pp.fechaFin = M.fechaOperacion
            FROM MovPP AS M
            JOIN dbo.Persona AS per
                ON per.valorDocumento = M.valorDocumento
            JOIN dbo.Propiedad AS pr
                ON pr.numeroFinca = M.numeroFinca
            JOIN dbo.PropiedadPersona AS pp
                ON pp.idPersona = per.id
               AND pp.idPropiedad = pr.id
            WHERE M.tipoAsociacionId = 2
              AND pp.fechaFin IS NULL;

            ------------------------------------------------------------------
            -- 4. MOVIMIENTOS CCPropiedad del día
            ------------------------------------------------------------------

            ------------------------------------------------------------------
            -- 4A. ASOCIAR CC
            ------------------------------------------------------------------
            ;WITH MovCC AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@idCC','int') AS idCC
                    , T.N.value('@tipoAsociacionId','int') AS tipoAsociacionId
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.CCPropiedad
            (
                  numeroFinca
                , idCC
                , PropiedadId
                , fechaInicio
                , fechaFin
            )
            SELECT
                  pr.numeroFinca
                , M.idCC
                , pr.id
                , M.fechaOperacion
                , NULL
            FROM MovCC AS M
            JOIN dbo.Propiedad AS pr
                ON pr.numeroFinca = M.numeroFinca
            WHERE M.tipoAsociacionId = 1
              AND NOT EXISTS
              (
                SELECT 1
                FROM dbo.CCPropiedad AS cp
                WHERE cp.PropiedadId = pr.id
                  AND cp.idCC = M.idCC
                  AND cp.fechaFin IS NULL
              );

            ------------------------------------------------------------------
            -- 4B. DESASOCIAR CC
            ------------------------------------------------------------------
            ;WITH MovCC AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@idCC','int') AS idCC
                    , T.N.value('@tipoAsociacionId','int') AS tipoAsociacionId
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            UPDATE cp
            SET cp.fechaFin = M.fechaOperacion
            FROM MovCC AS M
            JOIN dbo.Propiedad AS pr
                ON pr.numeroFinca = M.numeroFinca
            JOIN dbo.CCPropiedad AS cp
                ON cp.PropiedadId = pr.id
               AND cp.idCC = M.idCC
            WHERE M.tipoAsociacionId = 2
              AND cp.fechaFin IS NULL;

            ------------------------------------------------------------------
            -- 4C. CCPropiedadEvento
            ------------------------------------------------------------------
            ;WITH MovCC AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@idCC','int') AS idCC
                    , T.N.value('@tipoAsociacionId','int') AS tipoAsociacionId
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.CCPropiedadEvento
            (
                  idPropiedad
                , idCC
                , idTipoAsociacion
                , fecha
            )
            SELECT
                  pr.id
                , M.idCC
                , M.tipoAsociacionId
                , M.fechaOperacion
            FROM MovCC AS M
            JOIN dbo.Propiedad AS pr
                ON pr.numeroFinca = M.numeroFinca;

            ------------------------------------------------------------------
            -- 5. LECTURAS MEDIDOR
            ------------------------------------------------------------------
            ;WITH MovLect AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@numeroMedidor','nvarchar(64)') AS numeroMedidor
                    , T.N.value('@tipoMovimientoId','int') AS idTipoMovimiento
                    , T.N.value('@valor','money') AS valor
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('LecturasMedidor/Lectura') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            ),
            BaseIdMov AS
            (
                SELECT ISNULL(MAX(m.id),0) AS baseId
                FROM dbo.MovMedidor AS m
            )
            INSERT INTO dbo.MovMedidor
            (
                  id
                , numeroMedidor
                , idTipoMovimientoLecturaMedidor
                , valor
                , idPropiedad
                , fecha
                , saldoResultante
            )
            SELECT
                  B.baseId + ROW_NUMBER() OVER (ORDER BY M.fechaOperacion, M.numeroMedidor)
                , M.numeroMedidor
                , M.idTipoMovimiento
                , M.valor
                , pr.id
                , M.fechaOperacion
                , NULL
            FROM MovLect AS M
            LEFT JOIN dbo.Propiedad AS pr
                ON pr.numeroMedidor = M.numeroMedidor
            CROSS JOIN BaseIdMov AS B;

            ------------------------------------------------------------------
            -- 6. PAGOS
            ------------------------------------------------------------------
            ;WITH MovPago AS
            (
                SELECT
                      F.N.value('@fecha','date') AS fechaOperacion
                    , T.N.value('@numeroFinca','nvarchar(64)') AS numeroFinca
                    , T.N.value('@tipoMedioPagoId','int') AS tipoMedioPagoId
                    , T.N.value('@numeroReferencia','nvarchar(64)') AS numeroReferencia
                FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
                CROSS APPLY F.N.nodes('Pagos/Pago') AS T(N)
                WHERE F.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.Pago
            (
                  numeroFinca
                , idTipoMedioPago
                , numeroReferencia
                , idFactura
                , fecha
                , monto
            )
            SELECT
                  M.numeroFinca
                , M.tipoMedioPagoId
                , M.numeroReferencia
                , NULL
                , M.fechaOperacion
                , NULL
            FROM MovPago AS M
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Pago AS p
                WHERE p.numeroReferencia = M.numeroReferencia
            );

            ------------------------------------------------------------------
            -- 7. PROCESOS MASIVOS (NO XML)
            ------------------------------------------------------------------
            EXEC dbo.usp_CalculoInteresesMasivo
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            EXEC dbo.usp_AplicacionPagosMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            EXEC dbo.usp_FacturacionMensualMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            EXEC dbo.usp_CorteMasivoAgua
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            EXEC dbo.usp_ReconexionMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            IF (@fechaActual = EOMONTH(@fechaActual))
            BEGIN
                EXEC dbo.usp_CerrarMesMasivo
                    @inFechaCorte  = @fechaActual,
                    @outResultCode = @outResultCode OUTPUT;
            END;

            ------------------------------------------------------------------
            -- Avanzar hacia la siguiente fecha
            ------------------------------------------------------------------
            SET @idFecha = @idFecha + 1;
        END;

        COMMIT TRAN;

        ENABLE TRIGGER TR_Propiedad_AI_AsociaCCDefault ON dbo.Propiedad;

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

        SET @outResultCode = 50002;
    END CATCH;
END;
GO

-- EJECUCIÓN DEL SP
DECLARE @rc INT;

EXEC dbo.usp_Xml_CargarSimulacion
    @inIdXml       = 2,
    @outResultCode = @rc OUTPUT;

SELECT @rc AS ResultCode;