CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPagoIndividual
(
      @inIdFactura          INT
    , @inTipoMedioPagoId    INT
    , @inNumeroReferencia   NVARCHAR(100)
    , @outResultCode        INT             OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 0;

    BEGIN TRY

        BEGIN TRAN;

        INSERT INTO dbo.Pago
        (
              idFactura
            , monto
            , idTipoMedioPago
            , numeroReferencia
            , fecha
        )
        VALUES
        (
              @inIdFactura             -- idFactura
            , NULL                    -- monto: la capa lógica NO lo manda; se aplica masivamente
            , @inTipoMedioPagoId      -- idTipoMedioPago
            , @inNumeroReferencia     -- numeroReferencia
            , SYSDATETIME()           -- fecha
        );

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

        SET @outResultCode = 50004;
    END CATCH;
END;
GO