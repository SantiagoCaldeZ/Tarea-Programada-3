SELECT
      id
    , valorDocumento
    , nombre
    , email
    , telefono
FROM dbo.Persona
ORDER BY id;

SELECT
      id
    , numeroFinca
    , metrosCuadrados
    , idTipoUsoPropiedad
    , idTipoZonaPropiedad
    , valorFiscal
    , fechaRegistro
    , numeroMedidor
    , saldoM3
    , saldoM3UltimaFactura
    , aguaCortada
FROM dbo.Propiedad
ORDER BY id;

SELECT
      id
    , ValorDocumento
    , idTipoUsuario
FROM dbo.Usuario
ORDER BY id;

SELECT
      id
    , idPersona
    , idPropiedad
    , fechaInicio
    , fechaFin
FROM dbo.PropiedadPersona
ORDER BY id;

SELECT
      id
    , numeroFinca
    , idCC
    , PropiedadId
    , fechaInicio
    , fechaFin
FROM dbo.CCPropiedad
ORDER BY id;

SELECT
      id
    , idPropiedad
    , idCC
    , idTipoAsociacion
    , fecha
FROM dbo.CCPropiedadEvento
ORDER BY id;


SELECT
      id
    , numeroMedidor
    , idTipoMovimientoLecturaMedidor
    , valor
    , idPropiedad
    , fecha
    , saldoResultante
FROM dbo.MovMedidor
ORDER BY id;

SELECT
      id
    , numeroFinca
    , idTipoMedioPago
    , numeroReferencia
    , idFactura
    , fecha
    , monto
FROM dbo.Pago
ORDER BY id;


