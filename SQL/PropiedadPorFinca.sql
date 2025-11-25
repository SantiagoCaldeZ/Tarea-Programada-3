CREATE OR ALTER PROCEDURE dbo.usp_PropiedadPorFinca
(
      @inNumeroFinca NVARCHAR(64)
    , @outResultCode INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @fechaSimulacion DATE = '2025-11-10';  -- FECHA BASE DEL XML

    BEGIN TRY
        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 1. Datos de la propiedad
        ----------------------------------------------------------------------
        SELECT
              p.id              AS idPropiedad
            , p.numeroFinca     AS numeroFinca
            , p.metrosCuadrados AS metrosCuadrados
            , p.valorFiscal     AS valorFiscal
            , p.fechaRegistro   AS fechaRegistro
            , tu.nombre         AS tipoUso
            , tz.nombre         AS tipoZona
        FROM dbo.Propiedad AS p
        INNER JOIN dbo.TipoUsoPropiedad  AS tu ON tu.id = p.idTipoUsoPropiedad
        INNER JOIN dbo.TipoZonaPropiedad AS tz ON tz.id = p.idTipoZonaPropiedad
        WHERE p.numeroFinca = @inNumeroFinca;

        ----------------------------------------------------------------------
        -- 2. Facturas pendientes con estado calculado
        ----------------------------------------------------------------------
        SELECT
              f.id AS idFactura
            , f.fecha AS fecha
            , f.fechaVenc AS fechaVenc
            , f.totalOriginal
            , f.totalFinal

            -- Total pagado
            , ISNULL((
                SELECT SUM(monto)
                FROM Pago p
                WHERE p.idFactura = f.id
            ), 0) AS totalPagado

            -- Total pendiente
            , f.totalFinal - ISNULL((
                SELECT SUM(monto)
                FROM Pago p
                WHERE p.idFactura = f.id
            ), 0) AS totalPendiente

            -- Estado calculado
            , CASE
                WHEN ISNULL((
                    SELECT SUM(monto)
                    FROM Pago p
                    WHERE p.idFactura = f.id
                ), 0) >= f.totalFinal
                    THEN 'Pagada'

                WHEN f.fechaVenc < @fechaSimulacion
                    THEN 'Vencida'

                ELSE 'Pendiente'
              END AS estadoCalculado

        FROM dbo.Factura f
        INNER JOIN dbo.Propiedad p2 ON p2.id = f.idPropiedad
        WHERE p2.numeroFinca = @inNumeroFinca
        ORDER BY f.fecha ASC;

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        INSERT INTO dbo.DBErrors
        (
            UserName, Number, State, Severity,
            [Line], [Procedure], Message, DateTime
        )
        VALUES
        (
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), SYSDATETIME()
        );

        SET @outResultCode = 50002;
    END CATCH;
END;
GO