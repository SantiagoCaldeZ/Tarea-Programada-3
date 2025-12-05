CREATE OR ALTER TRIGGER TR_Propiedad_AI_AsociaCCDefault
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        ----------------------------------------------------------------------
        -- 1. Cargar IDs de CC según catálogo real (por nombre exacto)
        ----------------------------------------------------------------------
        DECLARE
              @idCCImpuesto           INT = (SELECT id FROM dbo.CC WHERE nombre = N'ImpuestoPropiedad')
            , @idCCConsumoAgua        INT = (SELECT id FROM dbo.CC WHERE nombre = N'ConsumoAgua')
            , @idCCRecoleccionBasura  INT = (SELECT id FROM dbo.CC WHERE nombre = N'RecoleccionBasura')
            , @idCCMantenimientoParq  INT = (SELECT id FROM dbo.CC WHERE nombre = N'MantenimientoParques');

        ----------------------------------------------------------------------
        -- 2. Asociar IMPUESTO a TODAS las propiedades insertadas
        ----------------------------------------------------------------------
        INSERT INTO dbo.CCPropiedad (NumeroFinca, idCC, PropiedadId, fechaInicio, fechaFin)
        SELECT  i.numeroFinca,
                @idCCImpuesto,
                i.id,
                i.fechaRegistro,       -- fecha de inscripción
                NULL
        FROM inserted AS i
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.CCPropiedad AS cp
            WHERE cp.PropiedadId = i.id
              AND cp.idCC = @idCCImpuesto
              AND cp.fechaFin IS NULL
        );

        -- Evento: asociación
        INSERT INTO dbo.CCPropiedadEvento (idPropiedad, idCC, idTipoAsociacion, fecha)
        SELECT  i.id,
                @idCCImpuesto,
                1,                     -- asociar
                i.fechaRegistro
        FROM inserted AS i;

        ----------------------------------------------------------------------
        -- 3. Asociar CONSUMO AGUA solo si aplica (Residencial, Industrial, Comercial)
        ----------------------------------------------------------------------
        INSERT INTO dbo.CCPropiedad (NumeroFinca, idCC, PropiedadId, fechaInicio, fechaFin)
        SELECT  i.numeroFinca,
                @idCCConsumoAgua,
                i.id,
                i.fechaRegistro,
                NULL
        FROM inserted AS i
        WHERE i.idTipoUsoPropiedad IN (1,2,3)
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.CCPropiedad AS cp
                WHERE cp.PropiedadId = i.id
                  AND cp.idCC = @idCCConsumoAgua
                  AND cp.fechaFin IS NULL
          );

        INSERT INTO dbo.CCPropiedadEvento (idPropiedad, idCC, idTipoAsociacion, fecha)
        SELECT  i.id,
                @idCCConsumoAgua,
                1,
                i.fechaRegistro
        FROM inserted AS i
        WHERE i.idTipoUsoPropiedad IN (1,2,3);

        ----------------------------------------------------------------------
        -- 4. Asociar RECOLECCIÓN BASURA a toda zona que no sea Agrícola (idZona != 3)
        ----------------------------------------------------------------------
        INSERT INTO dbo.CCPropiedad (NumeroFinca, idCC, PropiedadId, fechaInicio, fechaFin)
        SELECT  i.numeroFinca,
                @idCCRecoleccionBasura,
                i.id,
                i.fechaRegistro,
                NULL
        FROM inserted AS i
        WHERE i.idTipoZonaPropiedad <> 3
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.CCPropiedad AS cp
                WHERE cp.PropiedadId = i.id
                  AND cp.idCC = @idCCRecoleccionBasura
                  AND cp.fechaFin IS NULL
          );

        INSERT INTO dbo.CCPropiedadEvento (idPropiedad, idCC, idTipoAsociacion, fecha)
        SELECT  i.id,
                @idCCRecoleccionBasura,
                1,
                i.fechaRegistro
        FROM inserted AS i
        WHERE i.idTipoZonaPropiedad <> 3;

        ----------------------------------------------------------------------
        -- 5. Asociar MANTENIMIENTO PARQUES solo si zona RESIDENCIAL o COMERCIAL (idZona = 1 o 2)
        ----------------------------------------------------------------------
        INSERT INTO dbo.CCPropiedad (NumeroFinca, idCC, PropiedadId, fechaInicio, fechaFin)
        SELECT  i.numeroFinca,
                @idCCMantenimientoParq,
                i.id,
                i.fechaRegistro,
                NULL
        FROM inserted AS i
        WHERE i.idTipoZonaPropiedad IN (1,2)
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.CCPropiedad AS cp
                WHERE cp.PropiedadId = i.id
                  AND cp.idCC = @idCCMantenimientoParq
                  AND cp.fechaFin IS NULL
          );

        INSERT INTO dbo.CCPropiedadEvento (idPropiedad, idCC, idTipoAsociacion, fecha)
        SELECT  i.id,
                @idCCMantenimientoParq,
                1,
                i.fechaRegistro
        FROM inserted AS i
        WHERE i.idTipoZonaPropiedad IN (1,2);

    END TRY
    BEGIN CATCH

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

    END CATCH;
END;
GO