CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPagoIndividual
(
      @inIdFactura          INT
    , @inTipoMedioPagoId    INT
    , @inNumeroReferencia   NVARCHAR(100)
    , @outResultCode        INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    BEGIN TRY

        BEGIN TRAN;

        DECLARE @numeroFinca NVARCHAR(128);

        SELECT @numeroFinca = p.numeroFinca
        FROM dbo.Factura f
        JOIN dbo.Propiedad p ON p.id = f.idPropiedad
        WHERE f.id = @inIdFactura;

        IF @numeroFinca IS NULL
        BEGIN
            SET @outResultCode = 50005;
            ROLLBACK TRAN;
            RETURN;
        END;

        INSERT INTO dbo.Pago
        (
              numeroFinca
            , idFactura
            , monto
            , idTipoMedioPago
            , numeroReferencia
            , fecha
        )
        VALUES
        (
              @numeroFinca
            , @inIdFactura
            , NULL
            , @inTipoMedioPagoId
            , @inNumeroReferencia
            , SYSDATETIME()
        );

        --------------------------------------------------------
        -- 👉 FALTA ESTO: MARCAR LA FACTURA COMO PAGADA
        --------------------------------------------------------
        UPDATE dbo.Factura
        SET estado = 2       -- pagada
        WHERE id = @inIdFactura;

        COMMIT TRAN;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK TRAN;

        INSERT INTO dbo.DBErrors
        (
            UserName, Number, State, Severity, [Line], [Procedure], Message, DateTime
        )
        VALUES
        (
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), SYSDATETIME()
        );

        SET @outResultCode = 50004;
    END CATCH;
END;
GO

