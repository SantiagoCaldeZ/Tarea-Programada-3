ALTER   PROCEDURE [dbo].[usp_CerrarMesMasivo]
      (
      @inFechaCorte   DATE,
      @outResultCode  INT OUTPUT
)
AS
BEGIN
      SET NOCOUNT ON;
      SET @outResultCode = 0;

      BEGIN TRY

        -- 0 Ejecutar unicamente en fin de mes 
        IF @inFechaCorte <> EOMONTH(@inFechaCorte)
        BEGIN
            RETURN;
      END;


        -- 1 Marcar ordenes de corte pendientes como vencidas
        --
        --OrdenCorta:
        --estadoCorta: 1 = pendiente, 2 = ejecutada
        --no existe estado 3  se marca como "cerrada" con fechaCierre.

        UPDATE oc
        SET 
              oc.estadoCorta = 2,         -- 2 = ejecutada/cerrada
              oc.fechaCierre = @inFechaCorte
        FROM dbo.OrdenCorta oc
        WHERE oc.estadoCorta = 1 -- pendiente
            AND oc.fechaGeneracion < @inFechaCorte;

        -- 2 Marcar ordenes de reconexion pendientes como vencidad
        --OrdenReconexion:
        --estadoReconexion: 1 = pendiente, 2 = ejecutada

        UPDATE orc
        SET 
              orc.estadoReconexion = 2,   -- ejecutada/cerrada
              orc.fechaEjecucion   = @inFechaCorte
        FROM dbo.OrdenReconexion orc
        WHERE orc.estadoReconexion = 1 -- pendiente
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
