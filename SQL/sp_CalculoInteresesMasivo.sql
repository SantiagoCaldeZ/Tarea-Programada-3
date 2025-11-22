CREATE OR ALTER PROCEDURE dbo.usp_CalculoInteresesMasivo
(
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

BEGIN TRY
    BEGIN TRAN;

    ----------------------------------------------------------------------
    -- 0) Validación
    ----------------------------------------------------------------------
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 61001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) CC de InteresesMoratorios
    ----------------------------------------------------------------------
    DECLARE @idCC INT;

    SELECT @idCC = cc.id
    FROM dbo.CC cc
    WHERE cc.nombre = 'InteresesMoratorios';

    IF @idCC IS NULL
    BEGIN
        SET @outResultCode = 61002;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 2) Obtener porcentaje de interés
    ----------------------------------------------------------------------
    DECLARE @porcentaje DECIMAL(10,6);

    SELECT @porcentaje = im.valorPorcentual
    FROM dbo.CC_InteresesMoratorios im
    WHERE im.id = @idCC;

    ----------------------------------------------------------------------
    -- 3) Facturas pendientes y vencidas
    ----------------------------------------------------------------------
    ;WITH FactVenc AS
    (
        SELECT 
            f.id            AS idFactura,
            f.idPropiedad,
            f.totalFinal,
            DATEDIFF(DAY, f.fechaVenc, @inFechaCorte) AS diasMora
        FROM dbo.Factura f
        WHERE f.estado = 'Pendiente'
          AND f.fechaVenc < @inFechaCorte
    )
    SELECT *
    INTO #FacturasVencidas
    FROM FactVenc
    WHERE diasMora > 0;

    ----------------------------------------------------------------------
    -- 4) Insertar detalles de intereses moratorios
    ----------------------------------------------------------------------
    INSERT INTO dbo.FacturaDetalle
    (
        idFactura,
        idCC,
        descripcion,
        monto
    )
    SELECT
        fv.idFactura,
        @idCC,
        'Intereses por mora (' + CAST(fv.diasMora AS NVARCHAR(4)) + ' días)',
        fv.totalFinal * @porcentaje * fv.diasMora
    FROM #FacturasVencidas fv;

    ----------------------------------------------------------------------
    -- 5) Actualizar totalFinal de facturas
    ----------------------------------------------------------------------
    UPDATE f
    SET f.totalFinal = f.totalOriginal + d.sumDetalle
    FROM dbo.Factura f
    JOIN (
        SELECT idFactura, SUM(monto) AS sumDetalle
        FROM dbo.FacturaDetalle
        GROUP BY idFactura
    ) d ON d.idFactura = f.id;

    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    INSERT INTO dbo.DBErrors
    (
        UserName, Number, State, Severity, [Line], [Procedure], Message, DateTime
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

    SET @outResultCode = 61003;
END CATCH;

END;
GO