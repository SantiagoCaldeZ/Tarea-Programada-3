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

    SET @outResultCode = 0;

    ------------------------------------------------------------
    -- 1) Cargar XML
    ------------------------------------------------------------
    SELECT @xml = xf.XmlContenido
    FROM dbo.XmlFuente xf
    WHERE xf.IdXml = @inIdXml;

    IF (@xml IS NULL)
    BEGIN
        SET @outResultCode = 50001;
        RETURN;
    END;

    ------------------------------------------------------------
    -- 2) Fechas únicas de simulación
    ------------------------------------------------------------
    DECLARE @Fechas TABLE
    (
          idFecha INT IDENTITY(1,1) PRIMARY KEY,
          fecha   DATE NOT NULL
    );

    INSERT INTO @Fechas (fecha)
    SELECT DISTINCT F.N.value('@fecha','date')
    FROM @xml.nodes('/Operaciones/FechaOperacion') F(N);

    DECLARE @maxIdFecha INT = (SELECT MAX(idFecha) FROM @Fechas);
    DECLARE @idFecha    INT = 1;

    ------------------------------------------------------------
    -- 3) Desactivar trigger para evitar auto-asignación CC default
    ------------------------------------------------------------
    DISABLE TRIGGER TR_Propiedad_AI_AsociaCCDefault ON dbo.Propiedad;

    ------------------------------------------------------------
    -- 4) Simulación completa en transacción
    ------------------------------------------------------------
    BEGIN TRY
        BEGIN TRAN;

        WHILE (@idFecha <= @maxIdFecha)
        BEGIN
            SELECT @fechaActual = fecha
            FROM @Fechas
            WHERE idFecha = @idFecha;

            --------------------------------------------------------
            -- A) PERSONAS
            --------------------------------------------------------
            ;WITH FA AS
            (
                SELECT FN.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.Persona (valorDocumento, nombre, email, telefono)
            SELECT
                  P.N.value('@valorDocumento','nvarchar(32)')
                , P.N.value('@nombre','nvarchar(64)')
                , P.N.value('@email','nvarchar(64)')
                , P.N.value('@telefono','nvarchar(32)')
            FROM FA
            CROSS APPLY FA.FechaNode.nodes('Personas/Persona') P(N)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Persona x
                WHERE x.valorDocumento = P.N.value('@valorDocumento','nvarchar(32)')
            );

            --------------------------------------------------------
            -- B) PROPIEDADES
            --------------------------------------------------------
            ;WITH FA AS
            (
                SELECT FN.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
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
                  P.N.value('@numeroFinca','nvarchar(64)')
                , P.N.value('@metrosCuadrados','int')
                , P.N.value('@tipoUsoId','int')
                , P.N.value('@tipoZonaId','int')
                , P.N.value('@valorFiscal','money')
                , P.N.value('@fechaRegistro','date')
                , P.N.value('@numeroMedidor','nvarchar(64)')
            FROM FA
            CROSS APPLY FA.FechaNode.nodes('Propiedades/Propiedad') P(N)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Propiedad x
                WHERE x.numeroFinca = P.N.value('@numeroFinca','nvarchar(64)')
            );

            --------------------------------------------------------
            -- C) USUARIOS (un solo registro por persona)
            --------------------------------------------------------
            ;WITH FA AS
            (
                SELECT FN.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            -- insertar si no existe
            INSERT INTO dbo.Usuario (ValorDocumento, idTipoUsuario)
            SELECT
                  U.N.value('@ValorDocumentoIdentidad','nvarchar(32)')
                , U.N.value('@TipoUsuario','int')
            FROM FA
            CROSS APPLY FA.FechaNode.nodes('Usuarios/Usuario') U(N)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Usuario X
                WHERE X.ValorDocumento = U.N.value('@ValorDocumentoIdentidad','nvarchar(32)')
            );

            -- actualizar tipoUsuario si ya existía
            ;WITH FA AS
            (
                SELECT FN.N.query('.') AS FechaNode
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            ),
            MovU AS
            (
                SELECT
                      U.N.value('@ValorDocumentoIdentidad','nvarchar(32)') AS valorDoc
                    , U.N.value('@TipoUsuario','int')                       AS tipoUsuario
                FROM FA
                CROSS APPLY FA.FechaNode.nodes('Usuarios/Usuario') U(N)
            )
            UPDATE dbo.Usuario
            SET idTipoUsuario = M.tipoUsuario
            FROM MovU M
            WHERE Usuario.ValorDocumento = M.valorDoc
              AND Usuario.idTipoUsuario <> M.tipoUsuario;

            --------------------------------------------------------
            -- D) USUARIO–PROPIEDAD
            --------------------------------------------------------
            ;WITH MovUP AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@ValorDocumentoIdentidad','nvarchar(32)') AS valorDocumento
                    , T.N.value('@numeroFinca','nvarchar(64)')             AS finca
                    , T.N.value('@TipoAsociacion','int')                   AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('UsuarioPropiedad/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            -- asociar
            INSERT INTO dbo.UsuarioPropiedad (idUsuario, idPropiedad, fechaInicio, fechaFin)
            SELECT
                  U.id
                , P.id
                , @fechaActual
                , NULL
            FROM MovUP M
            JOIN dbo.Usuario   U ON U.ValorDocumento = M.valorDocumento
            JOIN dbo.Propiedad P ON P.numeroFinca    = M.finca
            WHERE M.tipoAsoc = 1
              AND NOT EXISTS
              (
                SELECT 1
                FROM dbo.UsuarioPropiedad X
                WHERE X.idUsuario  = U.id
                  AND X.idPropiedad = P.id
                  AND X.fechaFin IS NULL
              );

            -- desasociar
            ;WITH MovUP AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@ValorDocumentoIdentidad','nvarchar(32)') AS valorDocumento
                    , T.N.value('@numeroFinca','nvarchar(64)')             AS finca
                    , T.N.value('@TipoAsociacion','int')                   AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('UsuarioPropiedad/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            UPDATE UP
            SET UP.fechaFin = @fechaActual
            FROM MovUP M
            JOIN dbo.Usuario U     ON U.ValorDocumento = M.valorDocumento
            JOIN dbo.Propiedad P   ON P.numeroFinca    = M.finca
            JOIN dbo.UsuarioPropiedad UP
                 ON UP.idUsuario   = U.id
                AND UP.idPropiedad = P.id
            WHERE M.tipoAsoc = 2
              AND UP.fechaFin IS NULL;

            --------------------------------------------------------
            -- E) PROPIEDAD–PERSONA
            --------------------------------------------------------
            ;WITH MovPP AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@valorDocumento','nvarchar(32)') AS valorDoc
                    , T.N.value('@numeroFinca','nvarchar(64)')     AS finca
                    , T.N.value('@tipoAsociacionId','int')        AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('PropiedadPersona/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            -- asociar
            INSERT INTO dbo.PropiedadPersona
            (
                  id
                , fechaInicio
                , fechaFin
                , idPersona
                , idPropiedad
            )
            SELECT
                  (SELECT ISNULL(MAX(id),0) FROM dbo.PropiedadPersona)
                  + ROW_NUMBER() OVER (ORDER BY M.fechaOp, M.finca, M.valorDoc)
                , @fechaActual
                , NULL
                , PER.id
                , PR.id
            FROM MovPP M
            JOIN dbo.Persona   PER ON PER.valorDocumento = M.valorDoc
            JOIN dbo.Propiedad PR  ON PR.numeroFinca     = M.finca
            WHERE M.tipoAsoc = 1
              AND NOT EXISTS
              (
                SELECT 1
                FROM dbo.PropiedadPersona X
                WHERE X.idPersona   = PER.id
                  AND X.idPropiedad = PR.id
                  AND X.fechaFin IS NULL
              );

            -- desasociar
            ;WITH MovPP AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@valorDocumento','nvarchar(32)') AS valorDoc
                    , T.N.value('@numeroFinca','nvarchar(64)')     AS finca
                    , T.N.value('@tipoAsociacionId','int')        AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('PropiedadPersona/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            UPDATE PP
            SET PP.fechaFin = @fechaActual
            FROM MovPP M
            JOIN dbo.Persona   PER ON PER.valorDocumento = M.valorDoc
            JOIN dbo.Propiedad PR  ON PR.numeroFinca     = M.finca
            JOIN dbo.PropiedadPersona PP
                 ON PP.idPersona   = PER.id
                AND PP.idPropiedad = PR.id
            WHERE M.tipoAsoc = 2
              AND PP.fechaFin IS NULL;

            --------------------------------------------------------
            -- F) CC–PROPIEDAD + EVENTO
            --------------------------------------------------------
            ;WITH MovCC AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroFinca','nvarchar(64)') AS finca
                    , T.N.value('@idCC','int')                 AS idCC
                    , T.N.value('@tipoAsociacionId','int')     AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('CCPropiedad/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            -- asociar
            INSERT INTO dbo.CCPropiedad
            (
                  numeroFinca
                , idCC
                , PropiedadId
                , fechaInicio
                , fechaFin
            )
            SELECT
                  PR.numeroFinca
                , M.idCC
                , PR.id
                , @fechaActual
                , NULL
            FROM MovCC M
            JOIN dbo.Propiedad PR ON PR.numeroFinca = M.finca
            WHERE M.tipoAsoc = 1
              AND NOT EXISTS
              (
                SELECT 1
                FROM dbo.CCPropiedad X
                WHERE X.PropiedadId = PR.id
                  AND X.idCC        = M.idCC
                  AND X.fechaFin IS NULL
              );

            -- desasociar
            ;WITH MovCC AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroFinca','nvarchar(64)') AS finca
                    , T.N.value('@idCC','int')                 AS idCC
                    , T.N.value('@tipoAsociacionId','int')     AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('CCPropiedad/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            UPDATE CP
            SET CP.fechaFin = @fechaActual
            FROM MovCC M
            JOIN dbo.Propiedad PR ON PR.numeroFinca = M.finca
            JOIN dbo.CCPropiedad CP
                 ON CP.PropiedadId = PR.id
                AND CP.idCC        = M.idCC
            WHERE M.tipoAsoc = 2
              AND CP.fechaFin IS NULL;

            -- evento
            ;WITH MovCC AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroFinca','nvarchar(64)') AS finca
                    , T.N.value('@idCC','int')                 AS idCC
                    , T.N.value('@tipoAsociacionId','int')     AS tipoAsoc
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('CCPropiedad/Movimiento') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            INSERT INTO dbo.CCPropiedadEvento (idPropiedad, idCC, idTipoAsociacion, fecha)
            SELECT
                  PR.id
                , M.idCC
                , M.tipoAsoc
                , @fechaActual
            FROM MovCC M
            JOIN dbo.Propiedad PR ON PR.numeroFinca = M.finca;

            --------------------------------------------------------
            -- G) CAMBIO DE VALOR FISCAL
            --------------------------------------------------------
            ;WITH MovCamb AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroFinca','nvarchar(64)') AS finca
                    , T.N.value('@nuevoValor','money')         AS nuevoValor
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('PropiedadCambio/Cambio') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
            )
            UPDATE P
            SET valorFiscal = M.nuevoValor
            FROM MovCamb M
            JOIN dbo.Propiedad P ON P.numeroFinca = M.finca;

            --------------------------------------------------------
            -- H) MOVIMIENTOS DE MEDIDOR
            --------------------------------------------------------
            ;WITH MovLect AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroMedidor','nvarchar(64)') AS medidor
                    , T.N.value('@tipoMovimientoId','int')       AS tipoMov
                    , T.N.value('@valor','money')                AS valor
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('LecturasMedidor/Lectura') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
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
                  (SELECT ISNULL(MAX(id),0) FROM dbo.MovMedidor)
                  + ROW_NUMBER() OVER (ORDER BY M.fechaOp, M.medidor)
                , M.medidor
                , M.tipoMov
                , M.valor
                , P.id
                , @fechaActual
                , NULL
            FROM MovLect M
            LEFT JOIN dbo.Propiedad P ON P.numeroMedidor = M.medidor;

            --------------------------------------------------------
            -- I) PAGOS
            --------------------------------------------------------
            ;WITH MovPago AS
            (
                SELECT
                      FN.N.value('@fecha','date') AS fechaOp
                    , T.N.value('@numeroFinca','nvarchar(64)')     AS finca
                    , T.N.value('@tipoMedioPagoId','int')          AS tipoMedio
                    , T.N.value('@numeroReferencia','nvarchar(64)') AS ref
                    , T.N.value('@monto','money')                   AS monto
                FROM @xml.nodes('/Operaciones/FechaOperacion') FN(N)
                CROSS APPLY FN.N.nodes('Pagos/Pago') T(N)
                WHERE FN.N.value('@fecha','date') = @fechaActual
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
                  M.finca
                , M.tipoMedio
                , M.ref
                , NULL
                , @fechaActual
                , M.monto
            FROM MovPago M
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Pago X
                WHERE X.numeroReferencia = M.ref
            );

            -- 1) CÁLCULO DE INTERESES MORATORIOS
            EXEC dbo.usp_CalculoInteresesMasivo
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 2) APLICACIÓN DE PAGOS
            EXEC dbo.usp_AplicacionPagosMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 3) PROCESAR RECONEXIONES DESPUÉS DE PAGOS (PDF lo indica)
            EXEC dbo.usp_ReconexionMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 4) FACTURACIÓN MENSUAL (solo si aplica por día de corte)
            EXEC dbo.usp_FacturacionMensualMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 5) GENERAR ORDEN DE CORTE DE AGUA
            EXEC dbo.usp_CorteMasivoAgua
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 6) RECONEXIÓN NUEVAMENTE DESPUÉS DE CORTES
            EXEC dbo.usp_ReconexionMasiva
                @inFechaCorte   = @fechaActual,
                @outResultCode  = @outResultCode OUTPUT;

            -- 7) CIERRE DE MES SOLO SI ES FIN DE MES
            IF (@fechaActual = EOMONTH(@fechaActual))
            BEGIN
                EXEC dbo.usp_CerrarMesMasivo
                    @inFechaCorte   = @fechaActual,
                    @outResultCode  = @outResultCode OUTPUT;
            END;

            --------------------------------------------------------
            -- Siguiente fecha
            --------------------------------------------------------
            SET @idFecha += 1;
        END;

        ------------------------------------------------------------
        -- Reactivar trigger
        ------------------------------------------------------------
        ENABLE TRIGGER TR_Propiedad_AI_AsociaCCDefault ON dbo.Propiedad;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        SET @outResultCode = 50002;

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
    END CATCH;
END;
GO

-- EJECUCIÓN DEL SP
DECLARE @rc INT;

EXEC dbo.usp_Xml_CargarSimulacion
    @inIdXml       = 2,
    @outResultCode = @rc OUTPUT;

SELECT @rc AS ResultCode;