ALTER   PROCEDURE [dbo].[usp_CorteMasivoAgua]
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

        DECLARE @diasGraciaCorte INT;

        SELECT
            @diasGraciaCorte = CONVERT(INT, ps.valor)
      FROM dbo.ParametroSistema ps
      WHERE ps.clave = N'DiasGraciaCorta';


        ----------------------------------------------------------------------
        -- Tabla variable para almacenar propiedades a cortar
        ----------------------------------------------------------------------
        DECLARE @ACortar TABLE
        (
            idPropiedad INT
            ,
            idFactura INT
        );

        ----------------------------------------------------------------------
        -- Poblar tabla variable con las propiedades que requieren corte
        ----------------------------------------------------------------------
        ;WITH
            FacturasVencidas
            AS
            (
                  SELECT
                        f.id              AS idFactura,
                        f.idPropiedad     AS idPropiedad,
                        f.fechaVenc       AS fechaVenc,
                        f.totalFinal      AS saldoPendiente
                  FROM dbo.Factura f
                  WHERE (f.estado = 1)
                        AND (f.totalFinal > 0)
                        AND (f.fechaVenc < @inFechaCorte)
                        AND (@inFechaCorte > DATEADD(DAY, @diasGraciaCorte, f.fechaVenc))
            ),
            FacturasAgua
            AS
            (
                  SELECT DISTINCT
                        fv.idFactura,
                        fv.idPropiedad,
                        fv.fechaVenc,
                        fv.saldoPendiente
                  FROM FacturasVencidas fv
                        INNER JOIN dbo.DetalleFactura df
                        ON df.idFactura = fv.idFactura
                        INNER JOIN dbo.CC cc
                        ON cc.id = df.idCC
                  WHERE cc.nombre = N'ConsumoAgua'
            ),
            FacturaCausa
            AS
            (
                  SELECT
                        fa.idPropiedad,
                        fa.idFactura,
                        ROW_NUMBER() OVER ( --el objetivo es encontrar la factura mas antigua 
                        PARTITION BY fa.idPropiedad --se divide por propiedad y la numeracion de cada prop comienza en 1
                        ORDER BY fa.fechaVenc ASC --se ordena ascendente para obtener la mas antigua
                  ) AS rn
                  FROM FacturasAgua fa
            )
      INSERT INTO @ACortar
            (
            idPropiedad
            , idFactura
            )
      SELECT
            fc.idPropiedad
            , fc.idFactura
      FROM FacturaCausa fc
      WHERE fc.rn = 1;


        ----------------------------------------------------------------------
        -- 1) Insertar orden de corta
        ----------------------------------------------------------------------
        INSERT INTO dbo.OrdenCorta
            (
            idPropiedad
            , idFacturaCausa
            , fechaGeneracion
            , estadoCorta
            )
      SELECT
            ac.idPropiedad
            , ac.idFactura
            , @inFechaCorte
            , 1
      FROM @ACortar AS ac
      WHERE NOT EXISTS
        (
            SELECT 1
      FROM dbo.OrdenCorta oc
      WHERE (oc.idPropiedad = ac.idPropiedad)
            AND (oc.estadoCorta = 1)
        );


        ----------------------------------------------------------------------
        -- 2) Marcar propiedad como agua cortada
        ----------------------------------------------------------------------
        UPDATE p
        SET p.aguaCortada = 1
        FROM dbo.Propiedad p
            INNER JOIN @ACortar ac
            ON ac.idPropiedad = p.id;


        COMMIT TRAN;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 50040;

        INSERT INTO dbo.DBErrors
            (
            UserName
            , Number
            , State
            , Severity
            , [Line]
            , [Procedure]
            , Message
            , DateTime
            )
      VALUES
            (
                  SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

    END CATCH;

END;