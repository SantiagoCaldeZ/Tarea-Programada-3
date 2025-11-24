CREATE OR ALTER PROCEDURE dbo.usp_PropiedadesPorPersona
(
      @inValorDocumento    NVARCHAR(64)
    , @outResultCode       INT            OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        BEGIN TRAN;

        SELECT DISTINCT
              p.id              AS idPropiedad
            , p.numeroFinca     AS numeroFinca
        FROM dbo.Persona AS per
        INNER JOIN dbo.PropiedadPersona AS pp
            ON per.id = pp.idPersona
        INNER JOIN dbo.Propiedad AS p
            ON p.id = pp.idPropiedad
        WHERE (per.valorDocumento = @inValorDocumento)
          AND (pp.fechaFin        IS NULL);

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

        SET @outResultCode = 50003;
    END CATCH;
END;
GO