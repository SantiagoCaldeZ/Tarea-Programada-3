CREATE OR ALTER PROCEDURE dbo.usp_CerrarMesMasivo
(
    @inFechaCorte     DATE,   -- Último día del mes que termina
    @outResultCode    INT OUTPUT
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
        SET @outResultCode = 66001;
        ROLLBACK TRAN;
        RETURN;
    END;

    ----------------------------------------------------------------------
    -- 1) Cerrar facturas pagadas del mes
    ----------------------------------------------------------------------
    UPDATE f
    SET f.estado = 'Cerrada'
    FROM dbo.Factura f
    WHERE f.estado = 'Pagada'
      AND f.fecha <= @inFechaCorte;

    ----------------------------------------------------------------------
    -- 2) Obtener lecturas más recientes del mes
    ----------------------------------------------------------------------
    ;WITH UltLect AS
    (
        SELECT
            m.numeroMedidor,
            m.valor,
            m.fecha,
            ROW_NUMBER() OVER (PARTITION BY m.numeroMedidor ORDER BY m.fecha DESC) AS rn
        FROM dbo.MovMedidor m
        WHERE m.fecha <= @inFechaCorte
          AND m.idTipoMovimientoLecturaMedidor = 1   -- solo lecturas
    )
    SELECT numeroMedidor, valor
    INTO #LecturasBase
    FROM UltLect
    WHERE rn = 1;

    ----------------------------------------------------------------------
    -- 3) Insertar lecturas base del próximo mes (día 1)
    ----------------------------------------------------------------------
    DECLARE @fechaInicioMes DATE = DATEADD(DAY, 1, @inFechaCorte);

    INSERT INTO dbo.MovMedidor
    (
        id,
        numeroMedidor,
        idTipoMovimientoLecturaMedidor,
        valor,
        idPropiedad,
        fecha,
        saldoResultante
    )
    SELECT
        (SELECT ISNULL(MAX(id),0) FROM dbo.MovMedidor) 
           + ROW_NUMBER() OVER (ORDER BY lb.numeroMedidor),
        lb.numeroMedidor,
        1,                   -- lectura base (lectura)
        lb.valor,
        p.id,
        @fechaInicioMes,
        NULL
    FROM #LecturasBase lb
    JOIN dbo.Propiedad p
        ON p.numeroMedidor = lb.numeroMedidor;

    ----------------------------------------------------------------------
    COMMIT TRAN;

END TRY
BEGIN CATCH

    IF (XACT_STATE() <> 0)
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

    SET @outResultCode = 66002;

END CATCH;

END;
GO