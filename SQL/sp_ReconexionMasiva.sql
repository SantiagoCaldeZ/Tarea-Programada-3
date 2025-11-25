CREATE OR ALTER   PROCEDURE [dbo].[usp_ReconexionMasiva]
    (
    @inFechaCorte   DATE
    ,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @idCC_Reconexion INT;
    DECLARE @montoFijo MONEY;

    -- Tabla Variable (Reemplaza a la tabla temporal #ReconexionPend)
    DECLARE @ReconexionPend TABLE
    (
        idOrdenCorta INT PRIMARY KEY
        ,
        idPropiedad INT
        ,
        idFacturaCausa INT
    );

    BEGIN TRY
    IF (@inFechaCorte IS NULL)
    BEGIN
        SET @outResultCode = 63001;
        -- Fecha inválida
        RETURN;
    END;

    -- 1 Obtener idCC y Monto de ReconexionAgua 
    SELECT @idCC_Reconexion = cc.id
    FROM dbo.CC AS cc
    WHERE (cc.nombre = N'ReconexionAgua');

    IF (@idCC_Reconexion IS NULL)
    BEGIN
        SET @outResultCode = 63002;
        -- Falta CC de reconexión
        RETURN;
    END;
    
    SELECT @montoFijo = ra.ValorFijo
    FROM dbo.CC_ReconexionAgua AS ra
    WHERE (ra.id = @idCC_Reconexion);

    IF (@montoFijo IS NULL)
    BEGIN
        SET @outResultCode = 63002;
        -- Configuración incompleta del CC
        RETURN;
    END;

    -- 2 Identificar Propiedades a reconectar
    ;WITH
        CortesPendientes
        AS
        (
            SELECT
                oc.id            AS idOrdenCorta
            , oc.idPropiedad
            , oc.idFacturaCausa
            FROM dbo.OrdenCorta AS oc
            WHERE (oc.estadoCorta = 1)
            -- orden de corte activa
        ),
        FacturasPagadas
        AS
        (
            SELECT
                f.id            AS idFactura
            , f.idPropiedad
            FROM dbo.Factura AS f
            WHERE     (f.estado = 2) -- 2 = Pagado normal (totalFinal <= 0)
                AND (f.fecha <= @inFechaCorte)
        )
    -- Llenado de la Tabla Variable 
    INSERT INTO @ReconexionPend
        (
        idOrdenCorta
        , idPropiedad
        , idFacturaCausa
        )
    SELECT
        cp.idOrdenCorta
        , cp.idPropiedad
        , fp.idFactura
    FROM CortesPendientes AS cp
        JOIN FacturasPagadas AS fp
        ON fp.idFactura = cp.idFacturaCausa;

    -- Si no hay nada que reconectar, salir 
    IF NOT EXISTS (SELECT 1
    FROM @ReconexionPend)
    BEGIN
        SET @outResultCode = 63003;
        -- No había propiedades para reconectar
        RETURN;
    END;

    BEGIN TRAN;

    -- 3 Insertar orden de reconexión 
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
        , r.idFacturaCausa
        , 1
    -- 1 = Generado / Pendiente de ejecución física
    FROM @ReconexionPend AS r;

    -- 4 Marcar OrdenCorta como atendida y levantar el corte en Propiedad 
    -- 4.1 Marcar OrdenCorta como Atendida 
    UPDATE oc
    SET oc.estadoCorta = 2
    FROM dbo.OrdenCorta AS oc
        JOIN @ReconexionPend AS r
        ON r.idOrdenCorta = oc.id;

    -- 4.2 Levantar el corte en la propiedad
    UPDATE p
    SET p.aguaCortada = 0
    FROM dbo.Propiedad AS p
        JOIN @ReconexionPend AS r
        ON r.idPropiedad = p.id;

    -- 5 Insertar detalle de reconexión en DetalleFactura 
    -- El cargo de reconexión se agrega a la factura que fue pagada (la que disparó el proceso)
    INSERT INTO dbo.DetalleFactura
        (
        idFactura
        , idCC
        , descripcion
        , monto
        )
    SELECT
        r.idFacturaCausa
        , @idCC_Reconexion
        , N'Reconexión del servicio de agua'
        , @montoFijo
    FROM @ReconexionPend AS r;

    -- 6 Actualizar totalFinal de las facturas afectadas
    --    (Recalculando el totalFinal con el cargo de reconexión)
    ;WITH
        NuevoTotalFactura
        AS
        (
            SELECT
                df.idFactura
            , SUM(df.monto) AS totalActual
            FROM dbo.DetalleFactura AS df
                JOIN @ReconexionPend AS r
                ON r.idFacturaCausa = df.idFactura
            GROUP BY df.idFactura
        )
    UPDATE f
    SET f.totalFinal = nt.totalActual
    FROM dbo.Factura          AS f
        JOIN NuevoTotalFactura    AS nt
        ON nt.idFactura = f.id;

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
    THROW;
END CATCH;
END;
GO