CREATE OR ALTER PROCEDURE dbo.usp_CalcularInteresesFactura
(
    @inIdFactura   INT,
    @outIntereses  MONEY OUTPUT,
    @outTotalPagar MONEY OUTPUT,
    @outResultCode INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @fechaVenc DATE;
    DECLARE @totalOriginal MONEY;
    DECLARE @diasGracia INT;
    DECLARE @tasaMoratoria DECIMAL(10,4);
    DECLARE @diasAtraso INT;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1) Obtener parámetros del sistema
        ----------------------------------------------------------------------
        SELECT 
            @diasGracia = diasGracia,
            @tasaMoratoria = tasaMoratoria
        FROM dbo.ParameterSystem;

        ----------------------------------------------------------------------
        -- 2) Obtener datos de la factura
        ----------------------------------------------------------------------
        SELECT
            @fechaVenc = fechaVenc,          -- CORREGIDO
            @totalOriginal = totalOriginal
        FROM dbo.Factura
        WHERE id = @inIdFactura;

        IF (@fechaVenc IS NULL OR @totalOriginal IS NULL)
        BEGIN
            SET @outResultCode = 71001;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 3) Calcular días de atraso
        ----------------------------------------------------------------------
        SET @diasAtraso = DATEDIFF(DAY, @fechaVenc, CAST(GETDATE() AS DATE));

        IF (@diasAtraso <= @diasGracia)
        BEGIN
            SET @outIntereses = 0;
            SET @outTotalPagar = @totalOriginal;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 4) Calcular intereses
        ----------------------------------------------------------------------
        SET @outIntereses = @diasAtraso * @tasaMoratoria * @totalOriginal;
        SET @outTotalPagar = @totalOriginal + @outIntereses;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 71002;

        INSERT INTO dbo.DBErrors
        (
            UserName, Number, State, Severity, [Line], [Procedure],
            Message, DateTime
        )
        VALUES
        (
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
            ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), SYSDATETIME()
        );
    END CATCH;
END;
GO