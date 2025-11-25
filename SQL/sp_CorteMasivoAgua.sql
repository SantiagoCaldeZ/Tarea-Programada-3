CREATE OR ALTER   PROCEDURE [dbo].[usp_CorteMasivoAgua]
    (
    @inFechaCorte   DATE,
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 62001;
        RETURN;
    END;

    DECLARE @PropsCorte TABLE
    (
        idPropiedad INT PRIMARY KEY
        ,
        numeroFinca NVARCHAR(50)
    );

    DECLARE @DiasGraciaCorta INT;

    BEGIN TRY

    -- 1 Obtener parámetro del sistema: días de gracia para corta
    SELECT @DiasGraciaCorta = CONVERT(INT, ps.valor)
    FROM dbo.ParametroSistema AS ps
    WHERE (ps.clave = N'DiasGraciaCorta');

    IF (@DiasGraciaCorta IS NULL OR @DiasGraciaCorta <= 0)
    BEGIN
        -- Parámetro de sistema faltante o inválido
        SET @outResultCode = 62003;
        RETURN;
    END;

    -- 2) Identificar propiedades candidatas a corte 
    INSERT INTO @PropsCorte
        (
        idPropiedad
        ,numeroFinca
        )
    SELECT
        pr.id,
        pr.numeroFinca
    FROM dbo.Propiedad AS pr
        JOIN dbo.CCPropiedad AS ccp
        ON ccp.PropiedadId = pr.id
        JOIN dbo.CC AS cc
        ON cc.id = ccp.idCC
    WHERE 
        (cc.nombre = N'ConsumoAgua') -- Propiedades con servicio de agua
        AND (ccp.fechaFin IS NULL) -- CC activo
        -- Subconsulta para verificar si existe al menos una factura vencida con gracia expirada
        AND EXISTS
        (
            SELECT 1
        FROM dbo.Factura AS f
        WHERE 
                (f.idPropiedad = pr.id)
            AND (f.estado = 1) -- Pendiente
            AND (f.fechaVenc < @inFechaCorte) -- Ya vencida
            -- Que la fecha de corte sea posterior a la fecha de gracia
            AND (@inFechaCorte > DATEADD(DAY, @DiasGraciaCorta, f.fechaVenc))
        )
        -- Que la propiedad NO tenga una orden de corte ACTIVA
        AND NOT EXISTS
        (
            SELECT 1
        FROM dbo.OrdenCorta AS oc
        WHERE 
                (oc.idPropiedad = pr.id)
            AND (oc.estadoCorta = 1)   -- estadoCorta = 1: Orden pendiente / activa
        );

    BEGIN TRAN;
    -- 3 Insertar órdenes de corte
    INSERT INTO dbo.OrdenCorta
        (
        idPropiedad
        ,idFacturaCausa -- Factura más vieja que causa el corte
        ,fechaGeneracion
        ,estadoCorta
        )
    SELECT
        pc.idPropiedad
        , fMin.idFacturaCausa
        , @inFechaCorte AS fechaGeneracion
        , 1 AS estadoCorta-- estadoCorta = 1: Pendiente de Ejecución (activa)
    -- Obtener la factura más vieja que cumple la condición de mora
    FROM @PropsCorte AS pc
    CROSS APPLY 
    (
        -- Se usa CROSS APPLY para obtener la primera factura vencida para cada propiedad
        SELECT TOP 1
            f.id AS idFacturaCausa
        FROM dbo.Factura AS f
        WHERE 
            (f.idPropiedad = pc.idPropiedad)
            AND (f.estado = 1)
            AND (f.fechaVenc < @inFechaCorte)
            AND (@inFechaCorte > DATEADD(DAY, @DiasGraciaCorta, f.fechaVenc))
        ORDER BY f.fechaVenc ASC, f.id ASC -- La más vieja
    ) AS fMin;

    -- 4) Marcar Propiedad como CORTADA
    UPDATE p
    SET p.aguaCortada = 1 -- 1 = Cortada
    FROM dbo.Propiedad AS p
        JOIN @PropsCorte   AS pc
        ON pc.idPropiedad = p.id;

    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF (XACT_STATE() <> 0)
        ROLLBACK TRAN;

    INSERT INTO dbo.DBErrors
        (
        UserName, Number, State, Severity, [Line], [Procedure], Message, DateTime
        )
    VALUES
        (
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(),
            ERROR_PROCEDURE(), ERROR_MESSAGE(), SYSDATETIME()
    );

    SET @outResultCode = 62002;
    THROW;
END CATCH
END;
GO