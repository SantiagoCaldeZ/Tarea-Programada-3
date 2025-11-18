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




INSERT INTO dbo.XmlFuente
(
    IdXml,
    NombreArchivo,
    XmlContenido
)
VALUES
(
    2,
    N'simulacionActu.xml',
    N'<Operaciones>
<!--   Carga de datos base (personas, propiedades, asociaciones y CCPropiedad)   -->
<FechaOperacion fecha="2025-06-01">
<Personas>
<Persona valorDocumento="10000001" nombre="Valeria Solano" email="p01@ejemplo.org" telefono="8001-0001"/>
<Persona valorDocumento="10000002" nombre="José Miguel Rodríguez" email="p02@ejemplo.org" telefono="8002-0002"/>
<Persona valorDocumento="10000003" nombre="Andrea Vargas" email="p03@ejemplo.org" telefono="8003-0003"/>
<Persona valorDocumento="10000004" nombre="Daniel Méndez" email="p04@ejemplo.org" telefono="8004-0004"/>
<Persona valorDocumento="10000005" nombre="María Fernanda Sánchez" email="p05@ejemplo.org" telefono="8005-0005"/>
<Persona valorDocumento="10000006" nombre="Luis Diego Araya" email="p06@ejemplo.org" telefono="8006-0006"/>
<Persona valorDocumento="10000007" nombre="Sofía Morales" email="p07@ejemplo.org" telefono="8007-0007"/>
<Persona valorDocumento="10000008" nombre="Alejandro Navarro" email="p08@ejemplo.org" telefono="8008-0008"/>
<Persona valorDocumento="10000009" nombre="Carolina Pérez" email="p09@ejemplo.org" telefono="8009-0009"/>
<Persona valorDocumento="10000010" nombre="Ricardo Castro" email="p10@ejemplo.org" telefono="8010-0010"/>
<Persona valorDocumento="10000011" nombre="Natalia Salazar" email="p11@ejemplo.org" telefono="8011-0011"/>
<Persona valorDocumento="10000012" nombre="Gabriel Hernández" email="p12@ejemplo.org" telefono="8012-0012"/>
<Persona valorDocumento="10000013" nombre="Paola Rojas" email="p13@ejemplo.org" telefono="8013-0013"/>
<Persona valorDocumento="10000014" nombre="Esteban Calderón" email="p14@ejemplo.org" telefono="8014-0014"/>
<Persona valorDocumento="10000015" nombre="Laura Jiménez" email="p15@ejemplo.org" telefono="8015-0015"/>
<Persona valorDocumento="10000016" nombre="Kevin López" email="p16@ejemplo.org" telefono="8016-0016"/>
<Persona valorDocumento="10000017" nombre="Adriana Cordero" email="p17@ejemplo.org" telefono="8017-0017"/>
<Persona valorDocumento="10000018" nombre="Mauricio Rojas" email="p18@ejemplo.org" telefono="8018-0018"/>
<Persona valorDocumento="10000019" nombre="Daniela Alfaro" email="p19@ejemplo.org" telefono="8019-0019"/>
<Persona valorDocumento="10000020" nombre="Ignacio Chaves" email="p20@ejemplo.org" telefono="8020-0020"/>
<Persona valorDocumento="10000021" nombre="Karina Gutiérrez" email="p21@ejemplo.org" telefono="8021-0021"/>
<Persona valorDocumento="10000022" nombre="Diego Porras" email="p22@ejemplo.org" telefono="8022-0022"/>
<Persona valorDocumento="10000023" nombre="Juliana Villalobos" email="p23@ejemplo.org" telefono="8023-0023"/>
<Persona valorDocumento="10000024" nombre="Marco Antonio Mora" email="p24@ejemplo.org" telefono="8024-0024"/>
<Persona valorDocumento="10000025" nombre="Ximena Sánchez" email="p25@ejemplo.org" telefono="8025-0025"/>
<Persona valorDocumento="10000026" nombre="Cristian Valverde" email="p26@ejemplo.org" telefono="8026-0026"/>
<Persona valorDocumento="10000027" nombre="Rebeca Bonilla" email="p27@ejemplo.org" telefono="8027-0027"/>
<Persona valorDocumento="10000028" nombre="Sebastián Madriz" email="p28@ejemplo.org" telefono="8028-0028"/>
<Persona valorDocumento="10000029" nombre="Pamela Hidalgo" email="p29@ejemplo.org" telefono="8029-0029"/>
<Persona valorDocumento="10000030" nombre="Fabián Arias" email="p30@ejemplo.org" telefono="8030-0030"/>
</Personas>
<Propiedades>
<Propiedad numeroFinca="F-0001" numeroMedidor="M-1001" metrosCuadrados="135" tipoUsoId="1" tipoZonaId="1" valorFiscal="21500000" fechaRegistro="2025-06-02"/>
<Propiedad numeroFinca="F-0002" numeroMedidor="M-1002" metrosCuadrados="150" tipoUsoId="2" tipoZonaId="1" valorFiscal="23000000" fechaRegistro="2025-06-03"/>
<Propiedad numeroFinca="F-0003" numeroMedidor="M-1003" metrosCuadrados="165" tipoUsoId="3" tipoZonaId="4" valorFiscal="24500000" fechaRegistro="2025-06-05"/>
<Propiedad numeroFinca="F-0004" numeroMedidor="M-1004" metrosCuadrados="180" tipoUsoId="1" tipoZonaId="1" valorFiscal="26000000" fechaRegistro="2025-06-07"/>
<Propiedad numeroFinca="F-0005" numeroMedidor="M-1005" metrosCuadrados="195" tipoUsoId="2" tipoZonaId="5" valorFiscal="27500000" fechaRegistro="2025-06-09"/>
<Propiedad numeroFinca="F-0006" numeroMedidor="M-1006" metrosCuadrados="210" tipoUsoId="1" tipoZonaId="1" valorFiscal="29000000" fechaRegistro="2025-06-10"/>
<Propiedad numeroFinca="F-0007" numeroMedidor="M-1007" metrosCuadrados="225" tipoUsoId="2" tipoZonaId="1" valorFiscal="30500000" fechaRegistro="2025-06-12"/>
<Propiedad numeroFinca="F-0008" numeroMedidor="M-1008" metrosCuadrados="240" tipoUsoId="3" tipoZonaId="4" valorFiscal="32000000" fechaRegistro="2025-06-14"/>
<Propiedad numeroFinca="F-0009" numeroMedidor="M-1009" metrosCuadrados="255" tipoUsoId="1" tipoZonaId="1" valorFiscal="33500000" fechaRegistro="2025-06-16"/>
<Propiedad numeroFinca="F-0010" numeroMedidor="M-1010" metrosCuadrados="270" tipoUsoId="4" tipoZonaId="3" valorFiscal="35000000" fechaRegistro="2025-06-18"/>
<Propiedad numeroFinca="F-0011" numeroMedidor="M-1011" metrosCuadrados="285" tipoUsoId="4" tipoZonaId="1" valorFiscal="36500000" fechaRegistro="2025-06-20"/>
<Propiedad numeroFinca="F-0012" numeroMedidor="M-1012" metrosCuadrados="300" tipoUsoId="4" tipoZonaId="5" valorFiscal="38000000" fechaRegistro="2025-06-21"/>
<Propiedad numeroFinca="F-0013" numeroMedidor="M-1013" metrosCuadrados="315" tipoUsoId="2" tipoZonaId="5" valorFiscal="39500000" fechaRegistro="2025-06-23"/>
<Propiedad numeroFinca="F-0014" numeroMedidor="M-1014" metrosCuadrados="330" tipoUsoId="1" tipoZonaId="1" valorFiscal="41000000" fechaRegistro="2025-06-26"/>
<Propiedad numeroFinca="F-0015" numeroMedidor="M-1015" metrosCuadrados="345" tipoUsoId="5" tipoZonaId="2" valorFiscal="42500000" fechaRegistro="2025-06-28"/>
</Propiedades>
<PropiedadPersona>
<Movimiento valorDocumento="10000001" numeroFinca="F-0001" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000002" numeroFinca="F-0001" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000003" numeroFinca="F-0001" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000004" numeroFinca="F-0002" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000005" numeroFinca="F-0003" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000006" numeroFinca="F-0003" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000007" numeroFinca="F-0004" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000008" numeroFinca="F-0004" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000009" numeroFinca="F-0004" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000010" numeroFinca="F-0004" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000011" numeroFinca="F-0005" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000012" numeroFinca="F-0006" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000013" numeroFinca="F-0006" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000014" numeroFinca="F-0007" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000015" numeroFinca="F-0007" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000016" numeroFinca="F-0007" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000017" numeroFinca="F-0008" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000018" numeroFinca="F-0009" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000019" numeroFinca="F-0009" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000020" numeroFinca="F-0010" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000021" numeroFinca="F-0011" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000022" numeroFinca="F-0011" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000023" numeroFinca="F-0011" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000024" numeroFinca="F-0011" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000025" numeroFinca="F-0012" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000026" numeroFinca="F-0013" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000027" numeroFinca="F-0013" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000028" numeroFinca="F-0013" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000029" numeroFinca="F-0014" tipoAsociacionId="1"/>
<Movimiento valorDocumento="10000030" numeroFinca="F-0015" tipoAsociacionId="1"/>
</PropiedadPersona>
<CCPropiedad>
<Movimiento numeroFinca="F-0002" idCC="4" tipoAsociacionId="1"/>
<Movimiento numeroFinca="F-0005" idCC="4" tipoAsociacionId="1"/>
<Movimiento numeroFinca="F-0007" idCC="4" tipoAsociacionId="1"/>
<Movimiento numeroFinca="F-0010" idCC="4" tipoAsociacionId="1"/>
<Movimiento numeroFinca="F-0013" idCC="4" tipoAsociacionId="1"/>
</CCPropiedad>
</FechaOperacion>
<!--   LECTURAS JUNIO (TipoMov=1)   -->
<FechaOperacion fecha="2025-06-02">
<LecturasMedidor>
<Lectura numeroMedidor="M-1001" tipoMovimientoId="1" valor="97.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-03">
<LecturasMedidor>
<Lectura numeroMedidor="M-1002" tipoMovimientoId="1" valor="104.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-05">
<LecturasMedidor>
<Lectura numeroMedidor="M-1003" tipoMovimientoId="1" valor="111.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-07">
<LecturasMedidor>
<Lectura numeroMedidor="M-1004" tipoMovimientoId="1" valor="118.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-09">
<LecturasMedidor>
<Lectura numeroMedidor="M-1005" tipoMovimientoId="1" valor="125.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-10">
<LecturasMedidor>
<Lectura numeroMedidor="M-1006" tipoMovimientoId="1" valor="132.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-12">
<LecturasMedidor>
<Lectura numeroMedidor="M-1007" tipoMovimientoId="1" valor="139.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-14">
<LecturasMedidor>
<Lectura numeroMedidor="M-1008" tipoMovimientoId="1" valor="146.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-16">
<LecturasMedidor>
<Lectura numeroMedidor="M-1009" tipoMovimientoId="1" valor="153.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-18">
<LecturasMedidor>
<Lectura numeroMedidor="M-1010" tipoMovimientoId="1" valor="160.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-20">
<LecturasMedidor>
<Lectura numeroMedidor="M-1011" tipoMovimientoId="1" valor="167.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-21">
<LecturasMedidor>
<Lectura numeroMedidor="M-1012" tipoMovimientoId="1" valor="174.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-23">
<LecturasMedidor>
<Lectura numeroMedidor="M-1013" tipoMovimientoId="1" valor="181.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-26">
<LecturasMedidor>
<Lectura numeroMedidor="M-1014" tipoMovimientoId="1" valor="188.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-28">
<LecturasMedidor>
<Lectura numeroMedidor="M-1015" tipoMovimientoId="1" valor="195.0"/>
</LecturasMedidor>
</FechaOperacion>
<!--   AJUSTES JUNIO   -->
<FechaOperacion fecha="2025-06-06">
<LecturasMedidor>
<!--   M-1002: Ajuste Débito (TipoMov=3) suma 6 m³ faltantes   -->
<Lectura numeroMedidor="M-1002" tipoMovimientoId="3" valor="6"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-06-25">
<LecturasMedidor>
<!--   M-1011: Ajuste Débito (TipoMov=3) suma 4 m³ faltantes   -->
<Lectura numeroMedidor="M-1011" tipoMovimientoId="3" valor="4"/>
</LecturasMedidor>
</FechaOperacion>
<!--   PAGOS JUNIO   -->
<FechaOperacion fecha="2025-06-15">
<Pagos>
<Pago numeroFinca="F-0001" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0001"/>
<Pago numeroFinca="F-0002" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0002"/>
<Pago numeroFinca="F-0003" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0003"/>
<Pago numeroFinca="F-0004" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0004"/>
<Pago numeroFinca="F-0005" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0005"/>
<Pago numeroFinca="F-0006" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0006"/>
<Pago numeroFinca="F-0007" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0007"/>
<Pago numeroFinca="F-0008" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0008"/>
</Pagos>
</FechaOperacion>
<FechaOperacion fecha="2025-06-30">
<Pagos>
<Pago numeroFinca="F-0009" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0009"/>
<Pago numeroFinca="F-0010" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0010"/>
<Pago numeroFinca="F-0011" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0011"/>
<Pago numeroFinca="F-0012" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0012"/>
<Pago numeroFinca="F-0013" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0013"/>
<Pago numeroFinca="F-0014" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0014"/>
<Pago numeroFinca="F-0015" tipoMedioPagoId="1" numeroReferencia="RCPT-202506-F-0015"/>
</Pagos>
</FechaOperacion>
<!--   LECTURAS JULIO (TipoMov=1)   -->
<FechaOperacion fecha="2025-07-02">
<LecturasMedidor>
<Lectura numeroMedidor="M-1001" tipoMovimientoId="1" valor="108.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-03">
<LecturasMedidor>
<Lectura numeroMedidor="M-1002" tipoMovimientoId="1" valor="116.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-05">
<LecturasMedidor>
<Lectura numeroMedidor="M-1003" tipoMovimientoId="1" valor="119.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-07">
<LecturasMedidor>
<Lectura numeroMedidor="M-1004" tipoMovimientoId="1" valor="127.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-09">
<LecturasMedidor>
<Lectura numeroMedidor="M-1005" tipoMovimientoId="1" valor="135.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-10">
<LecturasMedidor>
<Lectura numeroMedidor="M-1006" tipoMovimientoId="1" valor="143.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-12">
<LecturasMedidor>
<Lectura numeroMedidor="M-1007" tipoMovimientoId="1" valor="151.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-14">
<LecturasMedidor>
<Lectura numeroMedidor="M-1008" tipoMovimientoId="1" valor="154.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-16">
<LecturasMedidor>
<Lectura numeroMedidor="M-1009" tipoMovimientoId="1" valor="162.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-18">
<LecturasMedidor>
<Lectura numeroMedidor="M-1010" tipoMovimientoId="1" valor="170.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-20">
<LecturasMedidor>
<Lectura numeroMedidor="M-1011" tipoMovimientoId="1" valor="178.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-21">
<LecturasMedidor>
<Lectura numeroMedidor="M-1012" tipoMovimientoId="1" valor="186.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-23">
<LecturasMedidor>
<Lectura numeroMedidor="M-1013" tipoMovimientoId="1" valor="189.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-26">
<LecturasMedidor>
<Lectura numeroMedidor="M-1014" tipoMovimientoId="1" valor="197.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-07-28">
<LecturasMedidor>
<Lectura numeroMedidor="M-1015" tipoMovimientoId="1" valor="205.0"/>
</LecturasMedidor>
</FechaOperacion>
<!--   AJUSTE JULIO   -->
<FechaOperacion fecha="2025-07-10">
<LecturasMedidor>
<!--   M-1004: Ajuste Crédito (TipoMov=2) resta 3 m³ sobre-leídos   -->
<Lectura numeroMedidor="M-1004" tipoMovimientoId="2" valor="3"/>
</LecturasMedidor>
</FechaOperacion>
<!--   PAGOS JULIO (morosos: F-0003, F-0007, F-0011, F-0014)   -->
<FechaOperacion fecha="2025-07-15">
<Pagos>
<Pago numeroFinca="F-0001" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0001"/>
<Pago numeroFinca="F-0002" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0002"/>
<Pago numeroFinca="F-0004" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0004"/>
<Pago numeroFinca="F-0005" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0005"/>
<Pago numeroFinca="F-0006" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0006"/>
<Pago numeroFinca="F-0008" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0008"/>
</Pagos>
</FechaOperacion>
<FechaOperacion fecha="2025-07-30">
<Pagos>
<Pago numeroFinca="F-0009" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0009"/>
<Pago numeroFinca="F-0010" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0010"/>
<Pago numeroFinca="F-0012" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0012"/>
<Pago numeroFinca="F-0013" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0013"/>
<Pago numeroFinca="F-0015" tipoMedioPagoId="2" numeroReferencia="RCPT-202507-F-0015"/>
</Pagos>
</FechaOperacion>
<!--   LECTURAS AGOSTO (TipoMov=1)   -->
<FechaOperacion fecha="2025-08-02">
<LecturasMedidor>
<Lectura numeroMedidor="M-1001" tipoMovimientoId="1" valor="118.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-03">
<LecturasMedidor>
<Lectura numeroMedidor="M-1002" tipoMovimientoId="1" valor="128.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-05">
<LecturasMedidor>
<Lectura numeroMedidor="M-1003" tipoMovimientoId="1" valor="133.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-07">
<LecturasMedidor>
<Lectura numeroMedidor="M-1004" tipoMovimientoId="1" valor="143.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-09">
<LecturasMedidor>
<Lectura numeroMedidor="M-1005" tipoMovimientoId="1" valor="146.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-10">
<LecturasMedidor>
<Lectura numeroMedidor="M-1006" tipoMovimientoId="1" valor="156.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-12">
<LecturasMedidor>
<Lectura numeroMedidor="M-1007" tipoMovimientoId="1" valor="166.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-14">
<LecturasMedidor>
<Lectura numeroMedidor="M-1008" tipoMovimientoId="1" valor="164.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-16">
<LecturasMedidor>
<Lectura numeroMedidor="M-1009" tipoMovimientoId="1" valor="174.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-18">
<LecturasMedidor>
<Lectura numeroMedidor="M-1010" tipoMovimientoId="1" valor="184.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-20">
<LecturasMedidor>
<Lectura numeroMedidor="M-1011" tipoMovimientoId="1" valor="194.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-21">
<LecturasMedidor>
<Lectura numeroMedidor="M-1012" tipoMovimientoId="1" valor="197.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-23">
<LecturasMedidor>
<Lectura numeroMedidor="M-1013" tipoMovimientoId="1" valor="202.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-26">
<LecturasMedidor>
<Lectura numeroMedidor="M-1014" tipoMovimientoId="1" valor="212.0"/>
</LecturasMedidor>
</FechaOperacion>
<FechaOperacion fecha="2025-08-28">
<LecturasMedidor>
<Lectura numeroMedidor="M-1015" tipoMovimientoId="1" valor="215.0"/>
</LecturasMedidor>
</FechaOperacion>
<!--   PAGOS AGOSTO (con reconexión de F-0003 y F-0011)   -->
<FechaOperacion fecha="2025-08-15">
<Pagos>
<Pago numeroFinca="F-0001" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0001"/>
<Pago numeroFinca="F-0002" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0002"/>
<Pago numeroFinca="F-0003" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0003-REC"/>
<Pago numeroFinca="F-0004" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0004"/>
<Pago numeroFinca="F-0005" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0005"/>
<Pago numeroFinca="F-0006" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0006"/>
<Pago numeroFinca="F-0008" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0008"/>
</Pagos>
</FechaOperacion>
<FechaOperacion fecha="2025-08-30">
<Pagos>
<Pago numeroFinca="F-0009" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0009"/>
<Pago numeroFinca="F-0010" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0010"/>
<Pago numeroFinca="F-0011" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0011-REC"/>
<Pago numeroFinca="F-0012" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0012"/>
<Pago numeroFinca="F-0013" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0013"/>
<Pago numeroFinca="F-0015" tipoMedioPagoId="1" numeroReferencia="RCPT-202508-F-0015"/>
</Pagos>
</FechaOperacion>
</Operaciones>'
);

