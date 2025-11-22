CREATE OR ALTER PROCEDURE dbo.usp_ReconexionMasiva
(
      @inFechaCorte   DATE
    , @outResultCode  INT OUTPUT
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
    IF (@inFechaCorte IS NULL)
    BEGIN
        SET @outResultCode = 63001;   -- Fecha inválida
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Obtener idCC de ReconexionAgua
    ----------------------------------------------------------------------
    DECLARE @idCC_Reconexion INT;

    SELECT
        @idCC_Reconexion = cc.id
    FROM dbo.CC AS cc
    WHERE (cc.nombre = N'ReconexionAgua');

    IF (@idCC_Reconexion IS NULL)
    BEGIN
        SET @outResultCode = 63002;   -- Falta CC de reconexión
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 2) Propiedades con corte activo cuya factura causa YA está pagada
    --    (estado = 2 = Pagado normal)
    ----------------------------------------------------------------------
    ;WITH CortesPendientes AS
    (
        SELECT
              oc.id            AS idOrdenCorta
            , oc.idPropiedad
            , oc.idFacturaCausa
        FROM dbo.OrdenCorta AS oc
        WHERE (oc.estadoCorta = 1)     -- orden de corte activa
    ),
    FacturasPagadas AS
    (
        SELECT
              f.id            AS idFactura
            , f.idPropiedad
        FROM dbo.Factura AS f
        WHERE     (f.estado = 2)       -- 2 = Pagado normal
              AND (f.fecha <= @inFechaCorte)
    )
    SELECT
          cp.idOrdenCorta
        , cp.idPropiedad
        , fp.idFactura
    INTO #ReconexionPend
    FROM CortesPendientes AS cp
    JOIN FacturasPagadas AS fp
        ON fp.idFactura = cp.idFacturaCausa;

    ----------------------------------------------------------------------
    -- Si no hay nada que reconectar, salir
    ----------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM #ReconexionPend)
    BEGIN
        SET @outResultCode = 63003;   -- No había propiedades para reconectar
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 3) Insertar orden de reconexión
    ----------------------------------------------------------------------
    INSERT INTO dbo.OrdenReconexion
    (
          idPropiedad
        , idOrdenCorta
        , idFacturaPago
        , estadoReconexion
    )
    SELECT
          r.idPropiedad
        , r.idOrdenCorta
        , r.idFactura       -- factura que quedó pagada y dispara la reconexión
        , 1                 -- 1 = ejecutado / generado
    FROM #ReconexionPend AS r;

    ----------------------------------------------------------------------
    -- 4) Marcar OrdenCorta como atendida y levantar el corte en Propiedad
    ----------------------------------------------------------------------
    UPDATE oc
    SET oc.estadoCorta = 2
    FROM dbo.OrdenCorta AS oc
    JOIN #ReconexionPend AS r
        ON r.idOrdenCorta = oc.id;

    UPDATE p
    SET p.aguaCortada = 0
    FROM dbo.Propiedad AS p
    JOIN #ReconexionPend AS r
        ON r.idPropiedad = p.id;

    ----------------------------------------------------------------------
    -- 5) Insertar detalle de reconexión en DetalleFactura
    ----------------------------------------------------------------------
    DECLARE @montoFijo MONEY;

    SELECT
        @montoFijo = ra.ValorFijo
    FROM dbo.CC_ReconexionAgua AS ra
    WHERE (ra.id = @idCC_Reconexion);

    IF (@montoFijo IS NULL)
    BEGIN
        SET @outResultCode = 63002;   -- Configuración incompleta del CC
        ROLLBACK TRAN;
        RETURN;
    END;

    -- Insertar un renglón de reconexión por cada factura causa
    INSERT INTO dbo.DetalleFactura
    (
          idFactura
        , idCC
        , descripcion
        , monto
    )
    SELECT
          r.idFactura
        , @idCC_Reconexion
        , N'Reconexión del servicio de agua'
        , @montoFijo
    FROM #ReconexionPend AS r;

    ----------------------------------------------------------------------
    -- 6) Actualizar totalFinal de las facturas afectadas
    --    (sumamos SOLO el monto de reconexión recién agregado)
    ----------------------------------------------------------------------
    ;WITH MontosReconexion AS
    (
        SELECT
              df.idFactura
            , SUM(df.monto) AS montoReconex
        FROM dbo.DetalleFactura AS df
        JOIN #ReconexionPend   AS r
            ON r.idFactura = df.idFactura
        WHERE (df.idCC = @idCC_Reconexion)
        GROUP BY df.idFactura
    )
    UPDATE f
    SET f.totalFinal = f.totalFinal + mr.montoReconex
    FROM dbo.Factura          AS f
    JOIN MontosReconexion     AS mr
        ON mr.idFactura = f.id;

    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH

    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

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

    SET @outResultCode = 63004;
END CATCH;

END;
GO