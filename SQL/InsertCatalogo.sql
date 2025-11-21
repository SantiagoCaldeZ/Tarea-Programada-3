INSERT INTO dbo.XmlFuente
(
    IdXml,
    NombreArchivo,
    XmlContenido
)
VALUES
(
    1,
    N'catalogosV2.xml',
    N'<Catalogos>
<!--   Parámetros para el sistema, como fecha en la que se hacen los cobros   -->
<ParametrosSistema>
<DiasVencimientoFactura>15</DiasVencimientoFactura>
<DiasGraciaCorta>10</DiasGraciaCorta>
</ParametrosSistema>
<TipoMovimientoLecturaMedidor>
<TipoMov id="1" nombre="Lectura"/>
<TipoMov id="2" nombre="Ajuste Crédito"/>
<TipoMov id="3" nombre="Ajuste Débito"/>
</TipoMovimientoLecturaMedidor>
<TipoUsoPropiedad>
<TipoUso id="1" nombre="Habitación"/>
<TipoUso id="2" nombre="Comercial"/>
<TipoUso id="3" nombre="Industrial"/>
<TipoUso id="4" nombre="Lote Baldío"/>
<TipoUso id="5" nombre="Agrícola"/>
</TipoUsoPropiedad>
<TipoZonaPropiedad>
<TipoZona id="1" nombre="Residencial"/>
<TipoZona id="2" nombre="Agrícola"/>
<TipoZona id="3" nombre="Bosque"/>
<TipoZona id="4" nombre="Industrial"/>
<TipoZona id="5" nombre="Comercial"/>
</TipoZonaPropiedad>
<UsuarioAdmin>
<Admin id="1" nombre="Administrador" password="SoyAdmin"/>
</UsuarioAdmin>
<TipoAsociacion>
<TipoAso id="1" nombre="Asociar"/>
<TipoAso id="2" nombre="Desasociar"/>
</TipoAsociacion>
<TipoMedioPago>
<MedioPago id="1" nombre="Efectivo"/>
<MedioPago id="2" nombre="Tarjeta"/>
</TipoMedioPago>
<PeriodoMontoCC>
<PeriodoMonto id="1" nombre="Mensual" qMeses="1"/>
<PeriodoMonto id="2" nombre="Trimestral" qMeses="3"/>
<PeriodoMonto id="3" nombre="Semestral" qMeses="6"/>
<PeriodoMonto id="4" nombre="Anual" qMeses="12"/>
<PeriodoMonto id="5" nombre="Único" qMeses="1"/>
<PeriodoMonto id="6" nombre="Interés Diario" qMeses="1" dias="30"/>
<!--   Consderar año bisiesto en SPs  -->
</PeriodoMontoCC>
<TipoMontoCC>
<TipoMonto id="1" nombre="Monto Fijo"/>
<TipoMonto id="2" nombre="Monto Variable"/>
<TipoMonto id="3" nombre="Porcentaje"/>
</TipoMontoCC>
<CCs>
<CC id="1" nombre="ConsumoAgua" TipoMontoCC="2" PeriodoMontoCC="1" ValorMinimo="500" ValorMinimoM3="30" ValorFijoM3Adicional="100" ValorPorcentual="" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
<CC id="2" nombre="PatenteComercial" TipoMontoCC="1" PeriodoMontoCC="3" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="150000" ValorM2Minimo="" ValorTramosM2=""/>
<CC id="3" nombre="ImpuestoPropiedad" TipoMontoCC="3" PeriodoMontoCC="4" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="0.01" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
<CC id="4" nombre="RecoleccionBasura" TipoMontoCC="1" PeriodoMontoCC="1" ValorMinimo="150" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="300" ValorM2Minimo="400" ValorTramosM2="75"/>
<CC id="5" nombre="MantenimientoParques" TipoMontoCC="1" PeriodoMontoCC="1" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="2000" ValorM2Minimo="" ValorTramosM2=""/>
<CC id="6" nombre="ReconexionAgua" TipoMontoCC="1" PeriodoMontoCC="5" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="30000" ValorM2Minimo="" ValorTramosM2=""/>
<CC id="7" nombre="InteresesMoratorios" TipoMontoCC="3" PeriodoMontoCC="6" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="0.04" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
</CCs>
</Catalogos>'
);

-- EJECUCIÓN DEL SP
DECLARE @rc INT;

EXEC dbo.usp_Xml_CargarCatalogos
    @inIdXml       = 1,  
    @outResultCode = @rc OUTPUT;

SELECT @rc AS ResultCode;