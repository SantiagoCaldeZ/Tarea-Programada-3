/*  Persona  */
SELECT
    p.id
  , p.valorDocumento
  , p.nombre
  , p.email
  , p.telefono
FROM dbo.Persona AS p
ORDER BY
    p.id;


/*  Propiedad  */
SELECT
    pr.id
  , pr.numeroFinca
  , pr.metrosCuadrados
  , pr.idTipoUsoPropiedad
  , pr.idTipoZonaPropiedad
  , pr.valorFiscal
  , pr.fechaRegistro
  , pr.numeroMedidor
  , pr.saldoM3
  , pr.saldoM3UltimaFactura
FROM dbo.Propiedad AS pr
ORDER BY
    pr.id;


/*  PropiedadPersona (todas las asociaciones)  */
SELECT
    pp.id
  , pr.numeroFinca
  , per.valorDocumento
  , per.nombre       AS nombrePersona
  , pp.fechaInicio
  , pp.fechaFin
FROM dbo.PropiedadPersona AS pp
JOIN dbo.Propiedad       AS pr  ON pr.id  = pp.idPropiedad
JOIN dbo.Persona         AS per ON per.id = pp.idPersona
ORDER BY
    pr.numeroFinca
  , per.valorDocumento
  , pp.fechaInicio;


/*  Propietarios vigentes (usa la vista)  */
SELECT
    v.id
  , v.idPropiedad
  , v.numeroFinca
  , v.idPersona
  , v.valorDocumento
  , v.nombrePersona
  , v.fechaInicio
FROM dbo.vw_Propietarios_Vigentes AS v
ORDER BY
    v.numeroFinca
  , v.valorDocumento;


/*  CCPropiedad (histórico completo)  */
SELECT
    cp.id
  , pr.numeroFinca
  , cp.idCC
  , c.nombre       AS CCNombre
  , cp.fechaInicio
  , cp.fechaFin
FROM dbo.CCPropiedad AS cp
JOIN dbo.Propiedad   AS pr ON pr.id = cp.PropiedadId
JOIN dbo.CC          AS c  ON c.id  = cp.idCC
ORDER BY
    pr.numeroFinca
  , cp.idCC
  , cp.fechaInicio;


/*  CCPropiedad vigente (usa la vista ya creada)  */
SELECT
    v.id
  , v.idPropiedad
  , v.numeroFinca
  , v.idCC
  , v.CCNombre
  , v.fechaInicio
FROM dbo.vw_CCPropiedad_Vigente AS v
ORDER BY
    v.numeroFinca
  , v.idCC;


/*  CCPropiedadEvento (bitácora de asociación / desasociación)  */
SELECT
    cpe.id
  , pr.numeroFinca
  , cpe.idCC
  , c.nombre            AS CCNombre
  , cpe.idTipoAsociacion
  , ta.nombre           AS TipoAsociacionNombre
  , cpe.fecha
FROM dbo.CCPropiedadEvento AS cpe
JOIN dbo.Propiedad        AS pr ON pr.id = cpe.idPropiedad
JOIN dbo.CC               AS c  ON c.id  = cpe.idCC
JOIN dbo.TipoAsociacion   AS ta ON ta.id = cpe.idTipoAsociacion
ORDER BY
    cpe.fecha
  , pr.numeroFinca
  , cpe.idCC;


/*  MovMedidor  */
SELECT
    mm.id
  , mm.numeroMedidor
  , mm.idTipoMovimientoLecturaMedidor
  , tmlm.nombre          AS TipoMovimientoNombre
  , mm.valor
  , mm.idPropiedad
  , pr.numeroFinca
  , mm.fecha
  , mm.saldoResultante
FROM dbo.MovMedidor                 AS mm
LEFT JOIN dbo.Propiedad             AS pr   ON pr.id  = mm.idPropiedad
JOIN dbo.TipoMovimientoLecturaMedidor AS tmlm
       ON tmlm.id = mm.idTipoMovimientoLecturaMedidor
ORDER BY
    mm.numeroMedidor
  , mm.fecha
  , mm.id;


/*  Pago  */
SELECT
    p.id
  , p.numeroFinca
  , p.idTipoMedioPago
  , tmp.nombre         AS MedioPagoNombre
  , p.numeroReferencia
  , p.idFactura
  , p.fecha
  , p.monto
FROM dbo.Pago        AS p
JOIN dbo.TipoMedioPago AS tmp ON tmp.id = p.idTipoMedioPago
ORDER BY
    p.fecha
  , p.numeroFinca
  , p.id;
