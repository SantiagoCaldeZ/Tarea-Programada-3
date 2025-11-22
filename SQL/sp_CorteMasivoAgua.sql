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
    -- 1) Propiedades con 2+ facturas vencidas y pendientes
    ----------------------------------------------------------------------
    ;WITH FacturasVencidas AS
    (
        SELECT 
            f.idPropiedad,
            COUNT(*) AS CantVencidas
        FROM dbo.Factura f
        WHERE f.estado = 'Pendiente'
          AND f.fechaVenc < @inFechaCorte
        GROUP BY f.idPropiedad
        HAVING COUNT(*) >= 2
    )
    SELECT fv.idPropiedad
    INTO #PropsCorte
    FROM FacturasVencidas fv;

    ----------------------------------------------------------------------
    -- 2) Insertar ORDEN DE CORTE (solo si NO existe una orden activa)
    ----------------------------------------------------------------------
    INSERT INTO dbo.OrdenCorta
    (
        idPropiedad,
        idFacturaCausa,
        fechaGeneracion,
        estadoCorta  -- 1 = Activa, 2 = Cerrada
    )
    SELECT 
        pc.idPropiedad,
        fMin.id AS idFacturaCausa,
        @inFechaCorte AS fechaGeneracion,
        1 AS estadoCorta
    FROM #PropsCorte pc
    CROSS APPLY
    (
        SELECT TOP (1) id
        FROM dbo.Factura
        WHERE idPropiedad = pc.idPropiedad
          AND estado = 'Pendiente'
          AND fechaVenc < @inFechaCorte
        ORDER BY fechaVenc
    ) fMin
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.OrdenCorta oc
        WHERE oc.idPropiedad = pc.idPropiedad
          AND oc.estadoCorta = 1  -- activa
    );

    ----------------------------------------------------------------------
    -- 3) Marcar Propiedad como CORTADA
    ----------------------------------------------------------------------
    UPDATE p
    SET p.aguaCortada = 1
    FROM dbo.Propiedad p
    JOIN #PropsCorte pc
         ON pc.idPropiedad = p.id;

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