CREATE OR ALTER PROCEDURE dbo.usp_AdminLogin
(
      @inValorDocumento     NVARCHAR(32)
    , @outResultCode        INT           OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Pre-proceso
    SET @outResultCode = 0;

    BEGIN TRY

        BEGIN TRAN;

        SELECT
              u.id                AS idUsuario
            , u.idTipoUsuario     AS idTipoUsuario
            , u.valorDocumento    AS valorDocumento
        FROM dbo.Usuario AS u
        WHERE (u.valorDocumento = @inValorDocumento)
          AND (u.idTipoUsuario  = 1);   -- Solo administradores

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
              SUSER_SNAME()                  -- UserName
            , ERROR_NUMBER()                 -- Number
            , ERROR_STATE()                  -- State
            , ERROR_SEVERITY()               -- Severity
            , ERROR_LINE()                   -- Line
            , ERROR_PROCEDURE()              -- Procedure
            , ERROR_MESSAGE()                -- Message
            , SYSDATETIME()                  -- DateTime
        );

        SET @outResultCode = 50001;
    END CATCH;
END;
GO