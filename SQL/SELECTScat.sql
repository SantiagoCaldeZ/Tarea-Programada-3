/*  Parametros del sistema  */
SELECT
    ps.clave
  , ps.valor
FROM dbo.ParametroSistema AS ps
ORDER BY
    ps.clave;


/*  TipoMovimientoLecturaMedidor  */
SELECT
    tmlm.id
  , tmlm.nombre
FROM dbo.TipoMovimientoLecturaMedidor AS tmlm
ORDER BY
    tmlm.id;


/*  TipoUsoPropiedad  */
SELECT
    tup.id
  , tup.nombre
FROM dbo.TipoUsoPropiedad AS tup
ORDER BY
    tup.id;


/*  TipoZonaPropiedad  */
SELECT
    tzp.id
  , tzp.nombre
FROM dbo.TipoZonaPropiedad AS tzp
ORDER BY
    tzp.id;


/*  TipoUsuario  */
SELECT
    tu.id
  , tu.nombre
FROM dbo.TipoUsuario AS tu
ORDER BY
    tu.id;


/*  TipoAsociacion  */
SELECT
    ta.id
  , ta.nombre
FROM dbo.TipoAsociacion AS ta
ORDER BY
    ta.id;


/*  TipoMedioPago  */
SELECT
    tmp.id
  , tmp.nombre
FROM dbo.TipoMedioPago AS tmp
ORDER BY
    tmp.id;


/*  PeriodoMontoCC  */
SELECT
    pm.id
  , pm.nombre
  , pm.qMeses
  , pm.dias
FROM dbo.PeriodoMontoCC AS pm
ORDER BY
    pm.id;


/*  TipoMontoCC  */
SELECT
    tm.id
  , tm.nombre
FROM dbo.TipoMontoCC AS tm
ORDER BY
    tm.id;


/*  CC (catálogo general de cobros)  */
SELECT
    c.id
  , c.nombre
  , c.TipoMontoCC
  , c.PeriodoMontoCC
FROM dbo.CC AS c
ORDER BY
    c.id;


/*  CC_ConsumoAgua  */
SELECT
    ca.id
  , ca.ValorMinimo
  , ca.ValorMinimoM3
  , ca.ValorFijoM3Adicional
FROM dbo.CC_ConsumoAgua AS ca
ORDER BY
    ca.id;


/*  CC_PatenteComercial  */
SELECT
    pc.id
  , pc.ValorFijo
FROM dbo.CC_PatenteComercial AS pc
ORDER BY
    pc.id;


/*  CC_ImpuestoPropiedad  */
SELECT
    ip.id
  , ip.ValorPorcentual
FROM dbo.CC_ImpuestoPropiedad AS ip
ORDER BY
    ip.id;


/*  CC_RecoleccionBasura  */
SELECT
    rb.id
  , rb.ValorMinimo
  , rb.ValorFijo
  , rb.ValorM2Minimo
  , rb.ValorTramosM2
FROM dbo.CC_RecoleccionBasura AS rb
ORDER BY
    rb.id;


/*  CC_MantenimientoParques  */
SELECT
    mp.id
  , mp.ValorFijo
FROM dbo.CC_MantenimientoParques AS mp
ORDER BY
    mp.id;


/*  CC_ReconexionAgua  */
SELECT
    ra.id
  , ra.ValorFijo
FROM dbo.CC_ReconexionAgua AS ra
ORDER BY
    ra.id;
