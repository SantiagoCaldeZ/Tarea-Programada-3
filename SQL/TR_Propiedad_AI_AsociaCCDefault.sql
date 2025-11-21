CREATE OR ALTER TRIGGER dbo.TR_Propiedad_AI_AsociaCCDefault
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCCImpuesto          INT;
        DECLARE @idCCConsumoAgua       INT;
        DECLARE @idCCRecoleccionBasura INT;
        DECLARE @idCCMantenimientoParq INT;
        DECLARE @hoy                   DATE;

        SET @hoy = CONVERT(DATE, GETDATE());

        /*  Buscar los ids de los CC que vamos a usar  */
        SELECT
            @idCCImpuesto          = MAX(CASE WHEN c.nombre = N'ImpuestoPropiedad'    THEN c.id END),
            @idCCConsumoAgua       = MAX(CASE WHEN c.nombre = N'ConsumoAgua'          THEN c.id END),
            @idCCRecoleccionBasura = MAX(CASE WHEN c.nombre = N'RecoleccionBasura'   THEN c.id END),
            @idCCMantenimientoParq = MAX(CASE WHEN c.nombre = N'MantenimientoParques' THEN c.id END)
        FROM dbo.CC AS c;

        /* 1) Impuesto sobre propiedad: SIEMPRE  */
        IF (@idCCImpuesto IS NOT NULL)
        BEGIN
            INSERT INTO dbo.CCPropiedad
            (
                NumeroFinca
              , idCC
              , PropiedadId
              , fechaInicio
              , fechaFin
            )
            SELECT
                i.numeroFinca
              , @idCCImpuesto
              , i.id
              , @hoy
              , NULL
            FROM inserted AS i
            WHERE NOT EXISTS
            (
                SELECT
                    1
                FROM dbo.CCPropiedad AS cp
                WHERE cp.PropiedadId = i.id
                  AND cp.idCC        = @idCCImpuesto
                  AND cp.fechaFin IS NULL
            );
        END;

        /* 2) Consumo de agua:
              uso residencial / industrial / comercial
           (Habitación, Industrial, Comercial)
        */
        IF (@idCCConsumoAgua IS NOT NULL)
        BEGIN
            INSERT INTO dbo.CCPropiedad
            (
                NumeroFinca
              , idCC
              , PropiedadId
              , fechaInicio
              , fechaFin
            )
            SELECT
                i.numeroFinca
              , @idCCConsumoAgua
              , i.id
              , @hoy
              , NULL
            FROM inserted             AS i
            JOIN dbo.TipoUsoPropiedad AS tup
                ON tup.id = i.idTipoUsoPropiedad
            WHERE tup.nombre IN (N'Habitación', N'Comercial', N'Industrial')
              AND NOT EXISTS
              (
                  SELECT
                      1
                  FROM dbo.CCPropiedad AS cp
                  WHERE cp.PropiedadId = i.id
                    AND cp.idCC        = @idCCConsumoAgua
                    AND cp.fechaFin IS NULL
              );
        END;

        /* 3) Recolección de basura:
              zona distinta de agrícola
        */
        IF (@idCCRecoleccionBasura IS NOT NULL)
        BEGIN
            INSERT INTO dbo.CCPropiedad
            (
                NumeroFinca
              , idCC
              , PropiedadId
              , fechaInicio
              , fechaFin
            )
            SELECT
                i.numeroFinca
              , @idCCRecoleccionBasura
              , i.id
              , @hoy
              , NULL
            FROM inserted               AS i
            JOIN dbo.TipoZonaPropiedad AS tzp
                ON tzp.id = i.idTipoZonaPropiedad
            WHERE tzp.nombre <> N'Agrícola'
              AND NOT EXISTS
              (
                  SELECT
                      1
                  FROM dbo.CCPropiedad AS cp
                  WHERE cp.PropiedadId = i.id
                    AND cp.idCC        = @idCCRecoleccionBasura
                    AND cp.fechaFin IS NULL
              );
        END;

        /* 4) Mantenimiento de parques:
              zona residencial o comercial
        */
        IF (@idCCMantenimientoParq IS NOT NULL)
        BEGIN
            INSERT INTO dbo.CCPropiedad
            (
                NumeroFinca
              , idCC
              , PropiedadId
              , fechaInicio
              , fechaFin
            )
            SELECT
                i.numeroFinca
              , @idCCMantenimientoParq
              , i.id
              , @hoy
              , NULL
            FROM inserted               AS i
            JOIN dbo.TipoZonaPropiedad AS tzp
                ON tzp.id = i.idTipoZonaPropiedad
            WHERE tzp.nombre IN (N'Residencial', N'Comercial')
              AND NOT EXISTS
              (
                  SELECT
                      1
                  FROM dbo.CCPropiedad AS cp
                  WHERE cp.PropiedadId = i.id
                    AND cp.idCC        = @idCCMantenimientoParq
                    AND cp.fechaFin IS NULL
              );
        END;
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

        THROW;   -- re–lanza el error para que la inserción falle visiblemente
    END CATCH;
END;
GO

INSERT INTO dbo.Propiedad
(
    numeroFinca
  , metrosCuadrados
  , idTipoUsoPropiedad      -- p.ej. 1 = Habitación
  , idTipoZonaPropiedad     -- p.ej. 1 = Residencial
  , valorFiscal
  , fechaRegistro
  , numeroMedidor
  , saldoM3
  , saldoM3UltimaFactura
)
VALUES
(
    N'F-TEST-001'
  , 120
  , 1
  , 1
  , 1000000
  , CONVERT(DATE, GETDATE())
  , N'MED-TEST-001'
  , 0
  , 0
);

SELECT
    cp.id
  , cp.PropiedadId
  , cp.NumeroFinca
  , cp.idCC
  , c.nombre AS CCNombre
  , cp.fechaInicio
  , cp.fechaFin
FROM dbo.CCPropiedad AS cp
JOIN dbo.CC          AS c
    ON c.id = cp.idCC
WHERE cp.NumeroFinca = N'F-TEST-001'
  AND cp.fechaFin IS NULL
ORDER BY
    cp.id;