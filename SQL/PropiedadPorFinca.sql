CREATE OR ALTER PROCEDURE dbo.usp_PropiedadPorFinca
(
      @inNumeroFinca       NVARCHAR(64)
    , @outResultCode       INT            OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        BEGIN TRAN;

        -- Propiedad
        SELECT
              p.id                        AS idPropiedad
            , p.numeroFinca               AS numeroFinca
            , p.metrosCuadrados           AS metrosCuadrados
            , p.valorFiscal               AS valorFiscal
            , p.fechaRegistro             AS fechaRegistro
            , tu.nombre                   AS tipoUso
            , tz.nombre                   AS tipoZona
        FROM dbo.Propiedad AS p
        INNER JOIN dbo.TipoUsoPropiedad AS tu
            ON tu.id = p.idTipoUsoPropiedad
        INNER JOIN dbo.TipoZonaPropiedad AS tz
            ON tz.id = p.idTipoZonaPropiedad
        WHERE (p.numeroFinca = @inNumeroFinca);

        -- Facturas pendientes
        SELECT
              f.id            AS idFactura
            , f.fecha         AS fecha
            , f.fechaVenc     AS fechaVenc
            , f.totalOriginal AS totalOriginal
            , f.totalFinal    AS totalFinal
            , f.estado        AS estado
        FROM dbo.Factura AS f
        INNER JOIN dbo.Propiedad AS p2
            ON p2.id = f.idPropiedad
        WHERE (p2.numeroFinca = @inNumeroFinca)
          AND (f.estado       = 1)
        ORDER BY
              f.fecha ASC;

        COMMIT TRAN;

    END TRY
    BEGIN CATCH

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