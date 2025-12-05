CREATE OR ALTER PROCEDURE dbo.usp_CorteMasivoAgua
(
      @inFechaCorte   DATE,
      @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    BEGIN TRY

    DECLARE @diasGraciaCorte INT;

    SELECT 
        @diasGraciaCorte = CONVERT(INT, ps.valor)
    FROM dbo.ParametroSistema ps
    WHERE ps.clave = N'DiasGraciaCorta';

        ----------------------------------------------------------------------
        -- 1) Identificar facturas vencidas del CC ConsumoAgua
        ----------------------------------------------------------------------
        ;WITH FacturasVencidas AS
        (
            SELECT 
                  f.id              AS idFactura,
                  f.idPropiedad     AS idPropiedad,
                  f.fechaVenc       AS fechaVenc,
                  f.totalFinal      AS saldoPendiente
            FROM dbo.Factura f
            WHERE f.estado = 1  -- pendiente
              AND f.totalFinal > 0
              AND f.fechaVenc < @inFechaCorte
              AND @inFechaCorte > DATEADD(DAY, @diasGraciaCorte, f.fechaVenc)
        ),

        ----------------------------------------------------------------------
        -- 2) Filtrar SOLO facturas con detalle del CC ConsumoAgua
        ----------------------------------------------------------------------
        FacturasAgua AS
        (
            SELECT DISTINCT
                  fv.idFactura,
                  fv.idPropiedad,
                  fv.fechaVenc,
                  fv.saldoPendiente
            FROM FacturasVencidas fv
            JOIN dbo.DetalleFactura df
                  ON df.idFactura = fv.idFactura
            JOIN dbo.CC cc
                  ON cc.id = df.idCC
            WHERE cc.nombre = N'ConsumoAgua'
        ),

        ----------------------------------------------------------------------
        -- 3) Tomar la factura más antigua por propiedad (la causa)
        ----------------------------------------------------------------------
        FacturaCausa AS
        (
            SELECT 
                  fa.idPropiedad,
                  fa.idFactura,
                  fa.fechaVenc,
                  ROW_NUMBER() OVER (PARTITION BY fa.idPropiedad 
                                    ORDER BY fa.fechaVenc ASC) AS rn
            FROM FacturasAgua fa
        ),

        ----------------------------------------------------------------------
        -- 4) Propiedades cuyo servicio debe cortarse
        ----------------------------------------------------------------------
        PropiedadesACortar AS
        (
            SELECT 
                  fc.idPropiedad,
                  fc.idFactura
            FROM FacturaCausa fc
            WHERE fc.rn = 1
        )

        ----------------------------------------------------------------------
        -- 5) Insertar orden de corte y marcar aguaCortada = 1
        ----------------------------------------------------------------------
        INSERT INTO dbo.OrdenCorta
        (
              idPropiedad,
              idFacturaCausa,
              fechaGeneracion,
              estadoCorta
        )
        SELECT
              pc.idPropiedad,
              pc.idFactura,
              @inFechaCorte,
              1
        FROM PropiedadesACortar pc
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.OrdenCorta oc
            WHERE oc.idPropiedad = pc.idPropiedad
              AND oc.estadoCorta = 1 -- ya cortada
        );


        ----------------------------------------------------------------------
        -- 6) Marcar propiedad como agua cortada
        ----------------------------------------------------------------------
        UPDATE p
        SET p.aguaCortada = 1
        FROM dbo.Propiedad p
        JOIN PropiedadesACortar pc
            ON pc.idPropiedad = p.id;


    END TRY
    BEGIN CATCH
        SET @outResultCode = 50040;

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