CREATE OR ALTER PROCEDURE dbo.usp_CerrarMesMasivo
(
    @inFechaCorte   DATE,       -- Último día del mes que termina
    @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @fechaInicioMes DATE;

    DECLARE @LecturasBase TABLE
    (
        numeroMedidor NVARCHAR(50) PRIMARY KEY,
        valor         DECIMAL(10, 2)
    );

    DECLARE @baseIdMov INT;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1) Validación
        ----------------------------------------------------------------------
        IF (@inFechaCorte IS NULL)
        BEGIN
            SET @outResultCode = 66001;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- 2) Calcular fecha de la lectura base (primer día del mes siguiente)
        ----------------------------------------------------------------------
        SET @fechaInicioMes = DATEADD(DAY, 1, @inFechaCorte);

        ----------------------------------------------------------------------
        -- 3) Obtener lecturas más recientes a la fecha de corte
        ----------------------------------------------------------------------
        ;WITH UltLect AS
        (
            SELECT
                m.numeroMedidor,
                m.valor,
                m.fecha,
                ROW_NUMBER() OVER
                (
                    PARTITION BY m.numeroMedidor
                    ORDER BY m.fecha DESC, m.id DESC
                ) AS rn
            FROM dbo.MovMedidor AS m
            WHERE m.fecha <= @inFechaCorte
              AND m.idTipoMovimientoLecturaMedidor = 1  -- solo lecturas
        )
        INSERT INTO @LecturasBase (numeroMedidor, valor)
        SELECT
            numeroMedidor,
            valor
        FROM UltLect
        WHERE rn = 1;

        BEGIN TRAN;

        ----------------------------------------------------------------------
        -- 4) Calcular base de IDs para MovMedidor
        ----------------------------------------------------------------------
        SELECT @baseIdMov = ISNULL(MAX(m.id), 0)
        FROM dbo.MovMedidor AS m;

        ----------------------------------------------------------------------
        -- 5) Insertar lecturas base para el mes entrante
        ----------------------------------------------------------------------
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
            @baseIdMov + ROW_NUMBER() OVER (ORDER BY lb.numeroMedidor, p.id) AS id,
            lb.numeroMedidor,
            1,                -- Lectura
            lb.valor,
            p.id,
            @fechaInicioMes,
            NULL
        FROM @LecturasBase AS lb
        JOIN dbo.Propiedad AS p
            ON p.numeroMedidor = lb.numeroMedidor
        WHERE NOT EXISTS
        (
            -- Evitar duplicados si ya existe una lectura para ese medidor en esa fecha
            SELECT 1
            FROM dbo.MovMedidor AS m2
            WHERE m2.numeroMedidor = lb.numeroMedidor
              AND m2.fecha = @fechaInicioMes
              AND m2.idTipoMovimientoLecturaMedidor = 1
        );

        ----------------------------------------------------------------------
        -- 6) Actualizar saldos en la tabla Propiedad
        ----------------------------------------------------------------------
        UPDATE p
        SET p.saldoM3UltimaFactura = lb.valor
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
            UserName,
            Number,
            State,
            Severity,
            [Line],
            [Procedure],
            Message,
            DateTime
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
        THROW;
    END CATCH;
END;
GO