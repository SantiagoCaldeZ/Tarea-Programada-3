CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPagoIndividual
(
    @inIdFactura        INT,
    @inTipoMedioPagoId  INT,
    @inNumeroReferencia NVARCHAR(64),
    @outResultCode      INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @montoFactura MONEY;
    DECLARE @tieneComprobante INT;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1) Validaciones iniciales
        ----------------------------------------------------------------------
        IF (@inIdFactura IS NULL OR @inTipoMedioPagoId IS NULL)
        BEGIN
            SET @outResultCode = 70001;    -- Parámetros inválidos
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 2) Validar que la factura existe y obtener el monto
        ----------------------------------------------------------------------
        SELECT 
            @montoFactura = totalFinal
        FROM dbo.Factura
        WHERE id = @inIdFactura
          AND estado = 1;  -- Pendiente

        IF (@montoFactura IS NULL)
        BEGIN
            SET @outResultCode = 70002;    -- Factura no existe o no está pendiente
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 3) Insertar el pago
        ----------------------------------------------------------------------
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
            p.numeroFinca,
            @inTipoMedioPagoId,
            @inNumeroReferencia,
            @inIdFactura,
            SYSDATETIME(),
            @montoFactura            -- pago completo
        FROM dbo.Propiedad AS p
        JOIN dbo.Factura   AS f 
            ON f.idPropiedad = p.id
        WHERE f.id = @inIdFactura;

        ----------------------------------------------------------------------
        -- 4) Marcar la factura como pagada
        ----------------------------------------------------------------------
        UPDATE dbo.Factura
        SET estado = 2           -- Pagado Normal
        WHERE id = @inIdFactura;

        ----------------------------------------------------------------------
        -- 5) Evitar comprobante duplicado
        ----------------------------------------------------------------------
        SELECT 
            @tieneComprobante = COUNT(1)
        FROM dbo.ComprobantePago
        WHERE idPago = SCOPE_IDENTITY();

        ----------------------------------------------------------------------
        -- 6) Crear comprobante de pago (solo si no existe)
        ----------------------------------------------------------------------
        IF (@tieneComprobante = 0)
        BEGIN
            INSERT INTO dbo.ComprobantePago
            (
                idPago,
                fecha,
                monto,
                numeroReferencia
            )
            SELECT 
                p.id,
                p.fecha,
                p.monto,
                p.numeroReferencia
            FROM dbo.Pago AS p
            WHERE p.id = SCOPE_IDENTITY();
        END;

        ----------------------------------------------------------------------
        SET @outResultCode = 0;   -- Éxito
    END TRY
    BEGIN CATCH

        SET @outResultCode = 70003;

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

        THROW;
    END CATCH;

END;
GO