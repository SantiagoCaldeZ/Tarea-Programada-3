CREATE OR ALTER PROCEDURE dbo.usp_AplicacionPagosMasiva
(
      @inFechaCorte   DATE,
      @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1) Pagos del día que no han sido aplicados
        ----------------------------------------------------------------------
        DECLARE @Pagos TABLE
        (
              idPago           INT PRIMARY KEY,
              numeroFinca      NVARCHAR(64),
              montoPago        MONEY,
              numeroReferencia NVARCHAR(64)
        );

        INSERT INTO @Pagos (idPago, numeroFinca, montoPago, numeroReferencia)
        SELECT 
              p.id,
              p.numeroFinca,
              ISNULL(p.monto, 0.0),
              p.numeroReferencia
        FROM dbo.Pago AS p
        WHERE p.fecha = @inFechaCorte
          AND p.idFactura IS NULL;


        ----------------------------------------------------------------------
        -- 2) Facturas pendientes (solo columnas necesarias)
        ----------------------------------------------------------------------
        ;WITH FacturasPendientes AS
        (
            SELECT 
                  f.id            AS idFactura,
                  f.totalFinal    AS saldoFactura,
                  f.idPropiedad   AS idPropiedad,
                  f.fecha         AS fechaFactura,
                  f.fechaVenc     AS fechaVencimiento,
                  pr.numeroFinca  AS numeroFinca
            FROM dbo.Factura AS f
            INNER JOIN dbo.Propiedad AS pr
                ON pr.id = f.idPropiedad
            WHERE f.totalFinal > 0
        ),

        ----------------------------------------------------------------------
        -- 3) Expandir pagos → facturas (sin SELECT * y sin ORDER BY prohibido)
        ----------------------------------------------------------------------
        Expansiones AS
        (
            SELECT
                  p.idPago,
                  p.montoPago,
                  fp.idFactura,
                  fp.saldoFactura,
                  fp.fechaFactura,
                  fp.fechaVencimiento,
                  p.numeroReferencia
            FROM @Pagos AS p
            CROSS APPLY
            (
                SELECT 
                      fp.idFactura,
                      fp.saldoFactura,
                      fp.fechaFactura,
                      fp.fechaVencimiento
                FROM FacturasPendientes AS fp
                WHERE fp.numeroFinca = p.numeroFinca
            ) AS fp
        ),

        ----------------------------------------------------------------------
        -- 4) Running sum ordenado correctamente en la ventana (permitido)
        ----------------------------------------------------------------------
        Calculos AS
        (
            SELECT
                  e.idPago,
                  e.montoPago,
                  e.idFactura,
                  e.saldoFactura,
                  e.fechaFactura,
                  e.fechaVencimiento,
                  e.numeroReferencia,
                  SUM(e.saldoFactura) OVER
                  (
                      PARTITION BY e.idPago
                      ORDER BY e.fechaFactura, e.fechaVencimiento
                      ROWS UNBOUNDED PRECEDING
                  ) AS saldoAcumulado
            FROM Expansiones AS e
        ),

        ----------------------------------------------------------------------
        -- 5) Monto aplicado a cada factura (sin SELECT *)
        ----------------------------------------------------------------------
        Aplicaciones AS
        (
            SELECT
                  c.idPago,
                  c.idFactura,
                  c.montoPago,
                  c.saldoFactura,
                  c.saldoAcumulado,
                  c.numeroReferencia,
                  CASE
                      WHEN c.saldoAcumulado - c.saldoFactura >= c.montoPago THEN 0
                      WHEN c.saldoAcumulado <= c.montoPago THEN c.saldoFactura
                      ELSE c.montoPago - (c.saldoAcumulado - c.saldoFactura)
                  END AS montoAplicado
            FROM Calculos AS c
        )

        ----------------------------------------------------------------------
        -- 6) Actualización set-based de facturas
        ----------------------------------------------------------------------
        UPDATE f
        SET 
            f.totalFinal = f.totalFinal - a.montoAplicado,
            f.estado = CASE 
                           WHEN f.totalFinal - a.montoAplicado = 0 THEN 4 
                           ELSE f.estado 
                       END
        FROM dbo.Factura AS f
        INNER JOIN Aplicaciones AS a 
            ON a.idFactura = f.id
        WHERE a.montoAplicado > 0;


        ----------------------------------------------------------------------
        -- 7) Insertar un comprobante por cada pago (no por factura)
        ----------------------------------------------------------------------
        INSERT INTO dbo.ComprobantePago
        (
              idPago,
              monto,
              numeroReferencia
        )
        SELECT
              p.idPago,
              p.montoPago,
              p.numeroReferencia
        FROM @Pagos AS p;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 50030;

        INSERT INTO dbo.DBErrors
        (
              UserName, Number, State, Severity, [Line],
              [Procedure], Message, DateTime
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

    END CATCH
END;
GO