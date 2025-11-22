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
    BEGIN TRAN;

    ----------------------------------------------------------------------
    -- 0) Validación
    ----------------------------------------------------------------------
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 62001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Obtener parámetro del sistema: días de gracia para corta
    --    ParametroSistema(clave, valor)
    ----------------------------------------------------------------------
    DECLARE @DiasGraciaCorta INT;

    SELECT @DiasGraciaCorta = CONVERT(INT, ps.valor)
    FROM dbo.ParametroSistema AS ps
    WHERE ps.clave = N'DiasGraciaCorta';

    IF (@DiasGraciaCorta IS NULL OR @DiasGraciaCorta <= 0)
    BEGIN
        -- Parámetro de sistema faltante o inválido
        SET @outResultCode = 62003;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 2) Propiedades con CC ConsumoAgua y con ≥ 1 factura vencida
    --    y cuya fecha de operación supera la fecha límite de corta
    --
    --  - Deben tener CC de ConsumoAgua asignado (vista vw_CCPropiedad_Vigente)
    --  - Deben tener una o más facturas:
    --        * estado = 1 (Pendiente)
    --        * factura vencida: fechaVenc < @inFechaCorte
    --        * @inFechaCorte > fechaFactura + DiasGraciaCorta (límite para corta)
    ----------------------------------------------------------------------
    ;WITH PropsConAgua AS
    (
        SELECT DISTINCT v.idPropiedad
        FROM dbo.vw_CCPropiedad_Vigente AS v
        WHERE v.CCNombre = N'ConsumoAgua'
    ),
    FacturasElegibles AS
    (
        SELECT
            f.idPropiedad
        FROM dbo.Factura AS f
        JOIN PropsConAgua AS pa
            ON pa.idPropiedad = f.idPropiedad
        WHERE f.estado = 1   -- 1 = Pendiente de pago :contentReference[oaicite:0]{index=0}
          AND f.fechaVenc < @inFechaCorte
          AND @inFechaCorte > DATEADD(DAY, @DiasGraciaCorta, f.fecha) -- superó fecha límite de corta :contentReference[oaicite:1]{index=1}
    ),
    FacturasVencidas AS
    (
        SELECT
            fe.idPropiedad,
            COUNT(*) AS CantVencidas
        FROM FacturasElegibles AS fe
        GROUP BY fe.idPropiedad
        HAVING COUNT(*) >= 1      -- “una o más factura vencida” :contentReference[oaicite:2]{index=2}
    )
    SELECT fv.idPropiedad
    INTO #PropsCorte
    FROM FacturasVencidas AS fv;

    ----------------------------------------------------------------------
    -- 3) Insertar ORDEN DE CORTE (solo si NO existe una orden activa)
    ----------------------------------------------------------------------
    INSERT INTO dbo.OrdenCorta
    (
        idPropiedad,
        idFacturaCausa,
        fechaGeneracion,
        estadoCorta   -- 1 = Pago de reconexión pendiente, 2 = pago de reconexión realizado :contentReference[oaicite:3]{index=3}
    )
    SELECT 
        pc.idPropiedad,
        fMin.idFacturaCausa,
        @inFechaCorte AS fechaGeneracion,
        1 AS estadoCorta
    FROM #PropsCorte AS pc
    CROSS APPLY
    (
        SELECT TOP (1)
            f.id AS idFacturaCausa
        FROM dbo.Factura AS f
        WHERE f.idPropiedad = pc.idPropiedad
          AND f.estado = 1
          AND f.fechaVenc < @inFechaCorte
          AND @inFechaCorte > DATEADD(DAY, @DiasGraciaCorta, f.fecha)
        ORDER BY f.fechaVenc, f.id
    ) AS fMin
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.OrdenCorta AS oc
        WHERE oc.idPropiedad = pc.idPropiedad
          AND oc.estadoCorta = 1   -- orden de corta activa
    );

    ----------------------------------------------------------------------
    -- 4) Marcar Propiedad como CORTADA
    ----------------------------------------------------------------------
    UPDATE p
    SET p.aguaCortada = 1
    FROM dbo.Propiedad AS p
    JOIN #PropsCorte   AS pc
        ON pc.idPropiedad = p.id;

    ----------------------------------------------------------------------
    -- 5) Fin OK
    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRAN;

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

    SET @outResultCode = 62002;
END CATCH;

END;
GO