CREATE OR ALTER PROCEDURE dbo.usp_Xml_CargarSimulacion
(
    @inIdXml        INT,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @xml XML;

    SET @outResultCode = 0;

    BEGIN TRY
        SELECT
            @xml = xf.XmlContenido
        FROM dbo.XmlFuente AS xf
        WHERE xf.IdXml = @inIdXml;

        IF (@xml IS NULL)
        BEGIN
            SET @outResultCode = 50001; -- Id nulo / mal entregado
            RETURN;
        END;

        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 1) Personas
        ----------------------------------------------------------------------
        INSERT INTO dbo.Persona
        (
            valorDocumento,
            nombre,
            email,
            telefono
        )
        SELECT
            T.N.value('@valorDocumento', N'nvarchar(64)') AS valorDocumento,
            T.N.value('@nombre',        N'nvarchar(64)') AS nombre,
            T.N.value('@email',         N'nvarchar(64)') AS email,
            T.N.value('@telefono',      N'nvarchar(64)') AS telefono
        FROM @xml.nodes('/Operaciones/FechaOperacion/Personas/Persona') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.Persona AS p
            WHERE p.valorDocumento = T.N.value('@valorDocumento', N'nvarchar(64)')
        );

        ----------------------------------------------------------------------
        -- 2) Propiedades
        ----------------------------------------------------------------------
        INSERT INTO dbo.Propiedad
        (
            numeroFinca,
            metrosCuadrados,
            idTipoUsoPropiedad,
            idTipoZonaPropiedad,
            valorFiscal,
            fechaRegistro,
            numeroMedidor
        )
        SELECT
            T.N.value('@numeroFinca',      N'nvarchar(64)') AS numeroFinca,
            T.N.value('@metrosCuadrados',  N'int')          AS metrosCuadrados,
            T.N.value('@tipoUsoId',        N'int')          AS idTipoUsoPropiedad,
            T.N.value('@tipoZonaId',       N'int')          AS idTipoZonaPropiedad,
            T.N.value('@valorFiscal',      N'int')          AS valorFiscal,
            T.N.value('@fechaRegistro',    N'date')         AS fechaRegistro,
            T.N.value('@numeroMedidor',    N'nvarchar(64)') AS numeroMedidor
        FROM @xml.nodes('/Operaciones/FechaOperacion/Propiedades/Propiedad') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.Propiedad AS pr
            WHERE pr.numeroFinca = T.N.value('@numeroFinca', N'nvarchar(64)')
        );

        ----------------------------------------------------------------------
        -- 3) Movimientos de PropiedadPersona (asociar / desasociar)
        ----------------------------------------------------------------------

        -- A) Asociaciones (tipoAsociacionId = 1)
        ;WITH MovPP AS
        (
            SELECT
                F.N.value('@fecha',         N'date')         AS fechaOperacion,
                T.N.value('@valorDocumento',N'nvarchar(64)') AS valorDocumento,
                T.N.value('@numeroFinca',   N'nvarchar(64)') AS numeroFinca,
                T.N.value('@tipoAsociacionId', N'int')       AS tipoAsociacionId
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('PropiedadPersona/Movimiento') AS T(N)
        ),
        MovPP_Asociar AS
        (
            SELECT
                fechaOperacion,
                valorDocumento,
                numeroFinca,
                tipoAsociacionId
            FROM MovPP
            WHERE (tipoAsociacionId = 1)
        ),
        BaseIdPP AS
        (
            SELECT ISNULL(MAX(id),0) AS baseId
            FROM dbo.PropiedadPersona
        )
        INSERT INTO dbo.PropiedadPersona
        (
            id,
            fechaInicio,
            fechaFin,
            idPersona,
            idPropiedad
        )
        SELECT
            B.baseId
            + ROW_NUMBER() OVER (ORDER BY M.fechaOperacion, M.numeroFinca, M.valorDocumento),
            M.fechaOperacion,
            NULL,
            per.id,
            pr.id
        FROM MovPP_Asociar AS M
        JOIN dbo.Persona   AS per ON per.valorDocumento = M.valorDocumento
        JOIN dbo.Propiedad AS pr  ON pr.numeroFinca     = M.numeroFinca
        CROSS JOIN BaseIdPP AS B
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.PropiedadPersona AS pp
            WHERE pp.idPersona   = per.id
              AND pp.idPropiedad = pr.id
              AND pp.fechaFin IS NULL
        );

        -- B) Desasociaciones (tipoAsociacionId = 2)
        ;WITH MovPP AS
        (
            SELECT
                F.N.value('@fecha',         N'date')         AS fechaOperacion,
                T.N.value('@valorDocumento',N'nvarchar(64)') AS valorDocumento,
                T.N.value('@numeroFinca',   N'nvarchar(64)') AS numeroFinca,
                T.N.value('@tipoAsociacionId', N'int')       AS tipoAsociacionId
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('PropiedadPersona/Movimiento') AS T(N)
        )
        UPDATE pp
        SET pp.fechaFin = M.fechaOperacion
        FROM MovPP AS M
        JOIN dbo.Persona   AS per ON per.valorDocumento = M.valorDocumento
        JOIN dbo.Propiedad AS pr  ON pr.numeroFinca     = M.numeroFinca
        JOIN dbo.PropiedadPersona AS pp
               ON pp.idPersona = per.id
              AND pp.idPropiedad = pr.id
        WHERE M.tipoAsociacionId = 2
          AND pp.fechaFin IS NULL;

        ----------------------------------------------------------------------
        -- 4) Movimientos de CCPropiedad + bitácora CCPropiedadEvento
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- A) ASOCIAR CC (tipoAsociacionId = 1)
        ----------------------------------------------------------------------
        ;WITH MovCC AS
        (
            SELECT
                F.N.value('@fecha',      N'date')         AS fechaOperacion,
                T.N.value('@numeroFinca',N'nvarchar(64)') AS numeroFinca,
                T.N.value('@idCC',       N'int')          AS idCC,
                T.N.value('@tipoAsociacionId', N'int')    AS tipoAsociacionId
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
        )
        INSERT INTO dbo.CCPropiedad
        (
            NumeroFinca,
            idCC,
            PropiedadId,
            fechaInicio,
            fechaFin
        )
        SELECT
            pr.numeroFinca,
            M.idCC,
            pr.id,
            M.fechaOperacion,
            NULL
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

        ----------------------------------------------------------------------
        -- B) DESASOCIAR CC (tipoAsociacionId = 2)
        ----------------------------------------------------------------------
        ;WITH MovCC AS
        (
            SELECT
                F.N.value('@fecha',      N'date')         AS fechaOperacion,
                T.N.value('@numeroFinca',N'nvarchar(64)') AS numeroFinca,
                T.N.value('@idCC',       N'int')          AS idCC,
                T.N.value('@tipoAsociacionId', N'int')    AS tipoAsociacionId
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
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

        ----------------------------------------------------------------------
        -- C) BITÁCORA CCPropiedadEvento (siempre)
        ----------------------------------------------------------------------
        ;WITH MovCC AS
        (
            SELECT
                F.N.value('@fecha',      N'date')         AS fechaOperacion,
                T.N.value('@numeroFinca',N'nvarchar(64)') AS numeroFinca,
                T.N.value('@idCC',       N'int')          AS idCC,
                T.N.value('@tipoAsociacionId', N'int')    AS tipoAsociacionId
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('CCPropiedad/Movimiento') AS T(N)
        )
        INSERT INTO dbo.CCPropiedadEvento
        (
            idPropiedad,
            idCC,
            idTipoAsociacion,
            fecha
        )
        SELECT
            pr.id,
            M.idCC,
            M.tipoAsociacionId,
            M.fechaOperacion
        FROM MovCC AS M
        JOIN dbo.Propiedad AS pr
            ON pr.numeroFinca = M.numeroFinca;


        ----------------------------------------------------------------------
        -- 5) Lecturas y ajustes de medidor -> MovMedidor
        ----------------------------------------------------------------------
        ;WITH MovLect AS
        (
            SELECT
                F.N.value('@fecha',       N'date')         AS fechaOperacion,
                T.N.value('@numeroMedidor',N'nvarchar(64)') AS numeroMedidor,
                T.N.value('@tipoMovimientoId', N'int')      AS idTipoMovimiento,
                T.N.value('@valor',       N'money')         AS valor
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('LecturasMedidor/Lectura') AS T(N)
        )
        , BaseIdMov AS
        (
            SELECT
                ISNULL(MAX(m.id), 0) AS baseId
            FROM dbo.MovMedidor AS m
        )
        INSERT INTO dbo.MovMedidor
        (
            id,
            numeroMedidor,
            idTipoMovimientoLecturaMedidor,
            valor,
            idPropiedad,
            fecha,
            saldoResultante
        )
        SELECT
            B.baseId
            + ROW_NUMBER() OVER (ORDER BY M.fechaOperacion, M.numeroMedidor) AS id,
            M.numeroMedidor,
            M.idTipoMovimiento,
            M.valor,
            pr.id        AS idPropiedad,
            M.fechaOperacion,
            NULL         AS saldoResultante
        FROM MovLect AS M
        LEFT JOIN dbo.Propiedad AS pr
            ON pr.numeroMedidor = M.numeroMedidor
        CROSS JOIN BaseIdMov AS B;

        ----------------------------------------------------------------------
        -- 6) Pagos
        ----------------------------------------------------------------------
        ;WITH MovPago AS
        (
            SELECT
                F.N.value('@fecha',      N'date')         AS fechaOperacion,
                T.N.value('@numeroFinca',N'nvarchar(64)') AS numeroFinca,
                T.N.value('@tipoMedioPagoId', N'int')     AS tipoMedioPagoId,
                T.N.value('@numeroReferencia',N'nvarchar(64)') AS numeroReferencia
            FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N)
            CROSS APPLY F.N.nodes('Pagos/Pago') AS T(N)
        )
        INSERT INTO dbo.Pago
        (
            numeroFinca,
            idTipoMedioPago,
            numeroReferencia,
            idFactura,
            fecha,
            monto
        )
        SELECT
            M.numeroFinca,
            M.tipoMedioPagoId,
            M.numeroReferencia,
            NULL,              -- idFactura se llenará en otros SPs
            M.fechaOperacion,
            NULL               -- monto calculado luego
        FROM MovPago AS M
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.Pago AS p
            WHERE p.numeroReferencia = M.numeroReferencia
        );

        ----------------------------------------------------------------------
        -- 7) PROCESOS MASIVOS (Ejecutados al final del procesamiento del XML)
        ----------------------------------------------------------------------
        DECLARE @fechaCorte DATE;

        SELECT
            @fechaCorte = MAX(F.N.value('@fecha', 'date'))
        FROM @xml.nodes('/Operaciones/FechaOperacion') AS F(N);

        -- 7) PROCESOS MASIVOS (Ejecutados al final del procesamiento del XML)

        EXEC dbo.usp_CalculoInteresesMasivo
            @inFechaCorte   = @fechaCorte,
            @outResultCode  = @outResultCode OUTPUT;

        EXEC dbo.usp_FacturacionMensualMasiva
            @inFechaCorte   = @fechaCorte,
            @outResultCode  = @outResultCode OUTPUT;

        EXEC dbo.usp_CorteMasivoAgua
            @inFechaCorte   = @fechaCorte,
            @outResultCode  = @outResultCode OUTPUT;

        EXEC dbo.usp_AplicacionPagosMasiva
            @inFechaCorte   = @fechaCorte,
            @outResultCode  = @outResultCode OUTPUT;

        EXEC dbo.usp_ReconexionMasiva
            @inFechaCorte   = @fechaCorte,
            @outResultCode  = @outResultCode OUTPUT;

        IF (@fechaCorte = EOMONTH(@fechaCorte))
        BEGIN
            EXEC dbo.usp_CerrarMesMasivo
                @inFechaCorte   = @fechaCorte,
                @outResultCode  = @outResultCode OUTPUT;
        END;

        ----------------------------------------------------------------------
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRAN;
        END;

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

