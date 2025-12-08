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

        ----------------------------------------------------------------------
        -- Tabla para capturar los intereses insertados hoy
        ----------------------------------------------------------------------
        DECLARE @Intereses TABLE
        (
              idFactura INT,
              interesDia MONEY
        );

        ----------------------------------------------------------------------
        -- 1) Facturas en mora con saldo pendiente real
        ----------------------------------------------------------------------
        ;WITH FacturasPendientes AS
        (
            SELECT
                  f.id
                , f.fechaVenc
                , f.totalFinal
                , COALESCE(SUM(p.monto), 0.0) AS pagosAplicados
            FROM dbo.Factura AS f
            LEFT JOIN dbo.Pago AS p
                ON p.idFactura = f.id
            WHERE f.estado = 3
            GROUP BY f.id, f.fechaVenc, f.totalFinal
        ),
        FacturasConSaldo AS
        (
            SELECT
                  fp.id
                , fp.fechaVenc
                , (fp.totalFinal - fp.pagosAplicados) AS saldoPendiente
            FROM FacturasPendientes AS fp
            WHERE (fp.totalFinal - fp.pagosAplicados) > 0
        ),
        CCPrincipal AS
        (
            SELECT
                  fcs.id AS idFactura
                , df0.idCC AS idCC
                , fcs.saldoPendiente
                , fcs.fechaVenc
            FROM FacturasConSaldo AS fcs
            JOIN
            (
                SELECT idFactura, MIN(id) AS idPrimerDetalle
                FROM dbo.DetalleFactura
                GROUP BY idFactura
            ) AS d
                ON d.idFactura = fcs.id
            JOIN dbo.DetalleFactura AS df0
                ON df0.id = d.idPrimerDetalle
        ),
        FacturasCobrablesHoy AS
        (
            SELECT
                  cc.idFactura
                , cc.saldoPendiente
                , cc.fechaVenc
                , dcc.ValorPorcentual AS porcentajeInteres
            FROM CCPrincipal AS cc
            JOIN dbo.CC_InteresesMoratorios AS dcc
                ON dcc.id = cc.idCC
            WHERE @inFechaCorte > cc.fechaVenc
        )

        ----------------------------------------------------------------------
        -- 2) Insertar interés del día
        ----------------------------------------------------------------------
        INSERT INTO dbo.DetalleFactura
        (
              idFactura
            , idCC
            , monto
            , fecha
            , descripcion
        )
        OUTPUT inserted.idFactura, inserted.monto 
        INTO @Intereses(idFactura, interesDia)
        SELECT
              f.idFactura
            , 7     -- CC de InteresesMoratorios
            , (f.saldoPendiente * (f.porcentajeInteres / 100.0))
            , @inFechaCorte
            , CONCAT('Interés moratorio generado el día ', CONVERT(char(10), @inFechaCorte, 120))
        FROM FacturasCobrablesHoy AS f;

        ----------------------------------------------------------------------
        -- 3) Actualizar totalFinal de las facturas
        ----------------------------------------------------------------------
        UPDATE fac
        SET fac.totalFinal = fac.totalFinal + i.interesDia
        FROM dbo.Factura AS fac
        JOIN @Intereses AS i
            ON i.idFactura = fac.id;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 50010;

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

    END CATCH;

END;
GO