CREATE OR ALTER PROCEDURE dbo.usp_ReconexionMasiva
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
        -- 1) Órdenes de corte pendientes (estadoCorta = 1)
        ----------------------------------------------------------------------
        ;WITH OrdenesPendientes AS
        (
            SELECT 
                  oc.id             AS idOrdenCorta,
                  oc.idPropiedad    AS idPropiedad,
                  oc.idFacturaCausa AS idFacturaCausa
            FROM dbo.OrdenCorta oc
            WHERE oc.estadoCorta = 1
        ),

        ----------------------------------------------------------------------
        -- 2) Propiedades al día (NO tienen facturas pendientes)
        ----------------------------------------------------------------------
        PropiedadesAlDia AS
        (
            SELECT 
                  op.idOrdenCorta,
                  op.idPropiedad,
                  op.idFacturaCausa
            FROM OrdenesPendientes op
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM dbo.Factura f
                WHERE f.idPropiedad = op.idPropiedad
                  AND f.totalFinal > 0
            )
        ),

        ----------------------------------------------------------------------
        -- 3) Pagos del día → Relación REAL es por numeroFinca
        ----------------------------------------------------------------------
        PagoDia AS
        (
            SELECT
                  pr.id           AS idPropiedad,
                  p.idFactura     AS idFacturaPago
            FROM dbo.Pago p
            JOIN dbo.Propiedad pr
              ON pr.numeroFinca = p.numeroFinca   -- RELACIÓN REAL
            WHERE p.fecha = @inFechaCorte
        )

        ----------------------------------------------------------------------
        -- 4) Insertar órdenes de reconexión
        ----------------------------------------------------------------------
        INSERT INTO dbo.OrdenReconexion
        (
              idPropiedad,
              idOrdenCorta,
              idFacturaPago,
              fechaGeneracion,
              estadoReconexion,
              fechaEjecucion
        )
        SELECT
              pa.idPropiedad,
              pa.idOrdenCorta,
              pd.idFacturaPago,
              @inFechaCorte,
              1,
              NULL
        FROM PropiedadesAlDia pa
        LEFT JOIN PagoDia pd
               ON pd.idPropiedad = pa.idPropiedad;

        ----------------------------------------------------------------------
        -- 5) Marcar orden de corte como cerrada
        ----------------------------------------------------------------------
        UPDATE oc
        SET oc.estadoCorta   = 2,
            oc.fechaCierre   = @inFechaCorte
        FROM dbo.OrdenCorta oc
        JOIN PropiedadesAlDia pa
             ON pa.idOrdenCorta = oc.id;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 55000;

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