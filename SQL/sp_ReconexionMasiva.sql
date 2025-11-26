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
        RETURN;
    END;

    SELECT @idCC_Reconexion = cc.id
    FROM dbo.CC AS cc
    WHERE (cc.nombre = N'ReconexionAgua');

    IF (@idCC_Reconexion IS NULL)
    BEGIN
        SET @outResultCode = 63002;
        RETURN;
    END;
    
    SELECT @montoFijo = ra.ValorFijo
    FROM dbo.CC_ReconexionAgua AS ra
    WHERE (ra.id = @idCC_Reconexion);

    IF (@montoFijo IS NULL)
    BEGIN
        SET @outResultCode = 63002;
        RETURN;
    END;

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
        ),
        FacturasPagadas
        AS
        (
            SELECT
                f.id            AS idFactura
            , f.idPropiedad
            FROM dbo.Factura AS f
            WHERE     (f.estado = 2)
                AND (f.fecha <= @inFechaCorte)
        )
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

    IF NOT EXISTS (SELECT 1 FROM @ReconexionPend)
    BEGIN
        SET @outResultCode = 63003;
        RETURN;
    END;

    BEGIN TRAN;

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
    FROM @ReconexionPend AS r;

    UPDATE oc
    SET oc.estadoCorta = 2
    FROM dbo.OrdenCorta AS oc
        JOIN @ReconexionPend AS r
        ON r.idOrdenCorta = oc.id;

    UPDATE p
    SET p.aguaCortada = 0
    FROM dbo.Propiedad AS p
        JOIN @ReconexionPend AS r
        ON r.idPropiedad = p.id;

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