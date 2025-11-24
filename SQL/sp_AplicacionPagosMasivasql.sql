SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[usp_AplicacionPagosMasiva]
    (
    @inFechaCorte DATE,
    @outResultCode INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @PagosNoFactura TABLE
    (
        idPago INT PRIMARY KEY
        ,
        numeroFinca NVARCHAR(50)
        ,
        monto MONEY
        ,
        idFacturaActual INT
    );

    BEGIN TRY

    -- asignar factura pendiente más vieja
    INSERT INTO @PagosNoFactura
        (
        idPago
        ,numeroFinca
        ,monto
        ,idFacturaActual
        )
    SELECT
        P.id
        , P.numeroFinca
        , P.monto
        , P.idFactura
    FROM dbo.Pago AS P
    WHERE 
        (P.idFactura IS NULL)
        AND (P.fecha <= @inFechaCorte);

    BEGIN TRAN;

    -- Asignar factura pendiente más vieja 
    UPDATE PNF
    SET PNF.idFacturaActual = F.id
    FROM @PagosNoFactura AS PNF

    CROSS APPLY ( --cross aply se va a utilizar para encontar la factura pendiente mas antigua
        SELECT TOP 1
            F.id
        FROM dbo.Factura AS F
            JOIN dbo.Propiedad AS PR ON PR.id = F.idPropiedad
        WHERE 
            (PR.numeroFinca = PNF.numeroFinca)
            AND (F.estado = 1) -- Pendiente
            AND (F.totalFinal > 0)
        ORDER BY F.fecha ASC
    ) AS F;

    -- Reflejar asignación en tabla Pago 
    UPDATE P
    SET P.idFactura = PNF.idFacturaActual
    FROM dbo.Pago AS P
        JOIN @PagosNoFactura AS PNF ON PNF.idPago = P.id
    WHERE (P.idFactura IS NULL); -- Solo actualizar los que no tenían factura

    -- 2 pagos aplicables descontar del totalFinal 
    UPDATE F
    SET F.totalFinal = F.totalFinal - P.monto
    FROM dbo.Factura AS F
        JOIN dbo.Pago AS P ON P.idFactura = F.id
    WHERE (P.fecha <= @inFechaCorte)
        AND (F.estado = 1); -- Solo descontar de facturas pendientes

    -- 3 facturas en 0 o negativas marcar pagadas 
    UPDATE dbo.Factura
    SET estado = 2      -- Pagado normal
    WHERE (totalFinal <= 0)
        AND (estado = 1);

    -- 4 creacion del comprobante
    INSERT INTO dbo.ComprobantePago
        (
        idPago
        ,fecha
        ,monto
        ,numeroReferencia
        )
    SELECT
        P.id
        , P.fecha
        , P.monto
        , P.numeroReferencia
    FROM dbo.Pago AS P
    WHERE (P.fecha <= @inFechaCorte); -- Se insertan los comprobantes solo una vez

    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    SET @outResultCode = 70001;
    
    THROW;
END CATCH
END;