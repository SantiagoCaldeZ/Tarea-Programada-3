CREATE OR ALTER PROCEDURE dbo.usp_CerrarMesMasivo
(
      @inFechaCorte   DATE,
      @outResultCode  INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 0) Ejecutar únicamente en FIN DE MES
        ----------------------------------------------------------------------
        IF @inFechaCorte <> EOMONTH(@inFechaCorte)
        BEGIN
            RETURN;
        END;


        ----------------------------------------------------------------------
        -- 1) Marcar ORDENES DE CORTE pendientes como VENCIDAS
        --
        --    OrdenCorta:
        --       estadoCorta: 1 = pendiente, 2 = ejecutada
        --       NO existe estado 3 → se marca como "cerrada" con fechaCierre.
        ----------------------------------------------------------------------
        UPDATE oc
        SET 
              oc.estadoCorta = 2,         -- 2 = ejecutada/cerrada
              oc.fechaCierre = @inFechaCorte
        FROM dbo.OrdenCorta oc
        WHERE oc.estadoCorta = 1          -- pendiente
          AND oc.fechaGeneracion < @inFechaCorte;


        ----------------------------------------------------------------------
        -- 2) Marcar ORDENES DE RECONEXIÓN pendientes como VENCIDAS
        --
        --    OrdenReconexion:
        --       estadoReconexion: 1 = pendiente, 2 = ejecutada
        ----------------------------------------------------------------------
        UPDATE orc
        SET 
              orc.estadoReconexion = 2,   -- ejecutada/cerrada
              orc.fechaEjecucion   = @inFechaCorte
        FROM dbo.OrdenReconexion orc
        WHERE orc.estadoReconexion = 1     -- pendiente
          AND orc.fechaGeneracion < @inFechaCorte;


        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH

        SET @outResultCode = 56000;

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
    END CATCH;

END;
GO