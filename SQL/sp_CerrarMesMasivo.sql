SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[usp_CerrarMesMasivo]
    (
    @inFechaCorte   DATE,
    -- Último día del mes que termina
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @fechaInicioMes DATE;

    DECLARE @LecturasBase TABLE
    (
        numeroMedidor NVARCHAR(50) PRIMARY KEY
        ,
        valor DECIMAL(10, 2)
    );

    BEGIN TRY
    
    -- 1 Validación 
    IF @inFechaCorte IS NULL
    BEGIN
        SET @outResultCode = 66001;
        RETURN;
    END;

    -- Calcular la fecha de la lectura base (primer día del mes siguiente o mes actual según lógica)
    SET @fechaInicioMes = DATEADD(DAY, 1, @inFechaCorte);

    -- 2 Obtener lecturas más recientes a la fecha de corte 
    ;WITH
        UltLect
        AS
        --se usa un CTE
        (
            SELECT
                m.numeroMedidor,
                m.valor,
                m.fecha,
                ROW_NUMBER() OVER (
                PARTITION BY m.numeroMedidor --agrupa las filas por num de medidor
                ORDER BY m.fecha DESC --ordena las filas dentro del grupo de las mas nueva o la mas vieja
            ) AS rn
            FROM dbo.MovMedidor AS m
            WHERE 
            (m.fecha <= @inFechaCorte)
                AND (m.idTipoMovimientoLecturaMedidor = 1)
            -- solo lecturas
        )
    INSERT INTO @LecturasBase
        (
        numeroMedidor
        ,valor
        )
    SELECT
        numeroMedidor,
        valor
    FROM UltLect
    WHERE (rn = 1);

    BEGIN TRAN;

    -- 3 Insertar lecturas base para el mes entrante 
    INSERT INTO dbo.MovMedidor
        (
        numeroMedidor
        ,idTipoMovimientoLecturaMedidor
        ,valor
        ,idPropiedad
        ,fecha
        ,saldoResultante -- Valor por defecto
        )
    SELECT
        lb.numeroMedidor
        , 1                    -- idTipoMovimientoLecturaMedidor = 1 (Lectura)
        , lb.valor
        , p.id
        , @fechaInicioMes
        , NULL
    -- O el valor DEFAULT que tenga la columna
    FROM @LecturasBase AS lb
        JOIN dbo.Propiedad AS p
        ON p.numeroMedidor = lb.numeroMedidor
    WHERE NOT EXISTS
    (
        -- Evitar duplicados si ya existe una lectura para ese medidor en esa fecha
        SELECT 1
    FROM dbo.MovMedidor AS m2
    WHERE 
            (m2.numeroMedidor = lb.numeroMedidor)
        AND (m2.fecha = @fechaInicioMes)
        AND (m2.idTipoMovimientoLecturaMedidor = 1)
    );

    -- 4 Actualizar saldos en la tabla Propiedad
    UPDATE p
    SET p.saldoM3UltimaFactura = lb.valor -- Se asume que este es el campo de control
    FROM dbo.Propiedad AS p
        JOIN @LecturasBase AS lb
        ON p.numeroMedidor = lb.numeroMedidor;


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

    SET @outResultCode = 66002;
    THROW;
END CATCH
END;
GO
