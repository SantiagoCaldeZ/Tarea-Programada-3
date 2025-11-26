CREATE OR ALTER PROCEDURE dbo.usp_AplicacionPagosMasiva
(
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    -- Mantener tabla variable (no viola estándar)
    DECLARE @PagosNoFactura TABLE
    (
        idPago          INT PRIMARY KEY,
        numeroFinca     NVARCHAR(50),
        monto           MONEY,
        idFacturaActual INT
    );

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1) Cargar pagos sin factura hasta la fecha de corte
        ----------------------------------------------------------------------
        INSERT INTO @PagosNoFactura (idPago, numeroFinca, monto, idFacturaActual)
        SELECT
            P.id,
            P.numeroFinca,
            P.monto,
            P.idFactura
        FROM dbo.Pago AS P
        WHERE P.idFactura IS NULL
          AND P.fecha <= @inFechaCorte;


        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 2) Asignar a cada pago la factura pendiente más vieja de esa finca
        ----------------------------------------------------------------------
        UPDATE PNF
        SET PNF.idFacturaActual = F.id
        FROM @PagosNoFactura AS PNF
        OUTER APPLY
        (
            SELECT TOP (1)
                F.id
            FROM dbo.Factura AS F
            JOIN dbo.Propiedad AS PR
              ON PR.id = F.idPropiedad
            WHERE PR.numeroFinca = PNF.numeroFinca
              AND F.estado = 1      -- Pendiente
              AND F.totalFinal > 0
            ORDER BY F.fecha ASC
        ) AS F;


        ----------------------------------------------------------------------
        -- 3) Actualizar Pago.idFactura si está vacío
        ----------------------------------------------------------------------
        UPDATE P
        SET P.idFactura = PNF.idFacturaActual
        FROM dbo.Pago AS P
        JOIN @PagosNoFactura AS PNF
          ON P.id = PNF.idPago
        WHERE P.idFactura IS NULL;


        ----------------------------------------------------------------------
        -- 4) Asegurar que NINGÚN pago tenga monto NULL
        ----------------------------------------------------------------------
        -- 4A) Si monto es NULL → tomar totalFinal de factura
        UPDATE P
        SET P.monto = F.totalFinal
        FROM dbo.Pago AS P
        JOIN dbo.Factura AS F
          ON F.id = P.idFactura
        WHERE P.fecha <= @inFechaCorte
          AND (P.monto IS NULL OR P.monto = 0);

        -- 4B) Si aún no hay factura asignada → NO PUEDE quedar NULL
        --     Usamos monto = 0 como fallback seguro
        UPDATE P
        SET P.monto = 0
        FROM dbo.Pago AS P
        WHERE P.fecha <= @inFechaCorte
          AND (P.monto IS NULL);



        ----------------------------------------------------------------------
        -- 5) Marcar facturas pagadas
        ----------------------------------------------------------------------
        UPDATE F
        SET F.estado = 2
        FROM dbo.Factura AS F
        JOIN dbo.Pago AS P
          ON P.idFactura = F.id
        WHERE F.estado = 1
          AND P.fecha <= @inFechaCorte;


        ----------------------------------------------------------------------
        -- 6) Crear comprobantes de pago
        --    (AQUÍ ES DONDE FALLABA POR monto NULL)
        ----------------------------------------------------------------------
        INSERT INTO dbo.ComprobantePago (idPago, fecha, monto, numeroReferencia)
        SELECT
            P.id,
            P.fecha,
            P.monto,              -- YA NUNCA SERÁ NULL
            P.numeroReferencia
        FROM dbo.Pago AS P
        WHERE P.fecha <= @inFechaCorte
          AND NOT EXISTS
              (SELECT 1 FROM dbo.ComprobantePago AS C WHERE C.idPago = P.id);

        COMMIT TRAN;

    END TRY

    BEGIN CATCH
        IF (XACT_STATE() <> 0)
            ROLLBACK TRAN;

        SET @outResultCode = 70001;

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