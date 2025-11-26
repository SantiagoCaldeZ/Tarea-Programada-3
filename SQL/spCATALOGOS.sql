CREATE OR ALTER PROCEDURE dbo.usp_Xml_CargarCatalogos
(
	@inIdXml		INT,
	@outResultCode  INT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @xml XML;

	SET @outResultCode = 0;

	BEGIN TRY
		SELECT
			@xml = xf.XmlContenido
		FROM dbo.XmlFuente AS xf
		WHERE xf.IdXml = @inIdXml;

		IF (@xml IS NULL)
		BEGIN
			SET @outResultCode = 50001;  --Id nulo, mal entregado
			RETURN;
		END;

		BEGIN TRAN;

		/* ParametrosSistema -> ParametroSistema */
        INSERT INTO dbo.ParametroSistema
        (
            clave
          , valor
        )
		SELECT
			N'DiasVencimientoFactura',
			T.N.value('(DiasVencimientoFactura/text())[1]', N'nvarchar(64)')
        FROM @xml.nodes('/Catalogos/ParametrosSistema') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.ParametroSistema AS ps
            WHERE (ps.clave = N'DiasVencimientoFactura')
        );

        INSERT INTO dbo.ParametroSistema
        (
            clave
          , valor
        )
        SELECT
            N'DiasGraciaCorta'
          , T.N.value('(DiasGraciaCorta/text())[1]', N'nvarchar(64)')
        FROM @xml.nodes('/Catalogos/ParametrosSistema') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.ParametroSistema AS ps
            WHERE (ps.clave = N'DiasGraciaCorta')
        );

        /* TipoMovimientoLecturaMedidor */
        INSERT INTO dbo.TipoMovimientoLecturaMedidor
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoMovimientoLecturaMedidor/TipoMov') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoMovimientoLecturaMedidor AS tm
            WHERE tm.id = T.N.value('@id', 'int')
        );

        /* TipoUsoPropiedad */
        INSERT INTO dbo.TipoUsoPropiedad
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoUsoPropiedad/TipoUso') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoUsoPropiedad AS tu
            WHERE tu.id = T.N.value('@id', 'int')
        );

        /* TipoZonaPropiedad */
        INSERT INTO dbo.TipoZonaPropiedad
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoZonaPropiedad/TipoZona') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoZonaPropiedad AS tz
            WHERE tz.id = T.N.value('@id', 'int')
        );

        /* TipoAsociacion */
        INSERT INTO dbo.TipoAsociacion
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoAsociacion/TipoAso') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoAsociacion AS ta
            WHERE ta.id = T.N.value('@id', 'int')
        );

        /* TipoMedioPago */
        INSERT INTO dbo.TipoMedioPago
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoMedioPago/MedioPago') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoMedioPago AS tmp
            WHERE tmp.id = T.N.value('@id', 'int')
        );

        /* PeriodoMontoCC */
        INSERT INTO dbo.PeriodoMontoCC
        (
            id
          , nombre
          , qMeses
          , dias
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
          , T.N.value('@qMeses', 'int')
          , NULLIF(T.N.value('@dias', 'int'), 0)
        FROM @xml.nodes('/Catalogos/PeriodoMontoCC/PeriodoMonto') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.PeriodoMontoCC AS pm
            WHERE pm.id = T.N.value('@id', 'int')
        );

        /* TipoMontoCC */
        INSERT INTO dbo.TipoMontoCC
        (
            id
          , nombre
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
        FROM @xml.nodes('/Catalogos/TipoMontoCC/TipoMonto') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoMontoCC AS tm
            WHERE tm.id = T.N.value('@id', 'int')
        );

        /* CC base */
        INSERT INTO dbo.CC
        (
            id
          , nombre
          , TipoMontoCC
          , PeriodoMontoCC
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')
          , T.N.value('@TipoMontoCC', 'int')
          , T.N.value('@PeriodoMontoCC', 'int')
        FROM @xml.nodes('/Catalogos/CCs/CC') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC AS c
            WHERE c.id = T.N.value('@id', 'int')
        );

        /* CC_ConsumoAgua */
        INSERT INTO dbo.CC_ConsumoAgua
        (
            id
          , ValorMinimo
          , ConsumoAgua
          , ValorFijoM3Adicional
          , ValorMinimoM3
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(INT, NULLIF(T.N.value('@ValorMinimo', N'nvarchar(32)'), N''))
          , CONVERT(INT, NULLIF(T.N.value('@ValorMinimoM3', N'nvarchar(32)'), N''))   -- se usa como consumo base
          , CONVERT(INT, NULLIF(T.N.value('@ValorFijoM3Adicional', N'nvarchar(32)'), N''))
          , CONVERT(INT, NULLIF(T.N.value('@ValorMinimoM3', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="ConsumoAgua"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_ConsumoAgua AS cca
            WHERE cca.id = T.N.value('@id', 'int')
        );

        /* CC_PatenteComercial */
        INSERT INTO dbo.CC_PatenteComercial
        (
            id
          , ValorFijo
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(INT, NULLIF(T.N.value('@ValorFijo', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="PatenteComercial"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_PatenteComercial AS cp
            WHERE cp.id = T.N.value('@id', 'int')
        );

        /* CC_ImpuestoPropiedad */
        INSERT INTO dbo.CC_ImpuestoPropiedad
        (
            id
          , ValorPorcentual
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(DECIMAL(6,5), NULLIF(T.N.value('@ValorPorcentual', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="ImpuestoPropiedad"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_ImpuestoPropiedad AS ci
            WHERE ci.id = T.N.value('@id', 'int')
        );

        /* CC_RecoleccionBasura */
        INSERT INTO dbo.CC_RecoleccionBasura
        (
            id
          , ValorMinimo
          , ValorFijo
          , ValorM2Minimo
          , ValorTramosM2
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(INT, NULLIF(T.N.value('@ValorMinimo', N'nvarchar(32)'), N''))
          , CONVERT(INT, NULLIF(T.N.value('@ValorFijo', N'nvarchar(32)'), N''))
          , CONVERT(INT, NULLIF(T.N.value('@ValorM2Minimo', N'nvarchar(32)'), N''))
          , CONVERT(INT, NULLIF(T.N.value('@ValorTramosM2', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="RecoleccionBasura"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_RecoleccionBasura AS cr
            WHERE cr.id = T.N.value('@id', 'int')
        );

        /* CC_MantenimientoParques */
        INSERT INTO dbo.CC_MantenimientoParques
        (
            id
          , ValorFijo
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(INT, NULLIF(T.N.value('@ValorFijo', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="MantenimientoParques"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_MantenimientoParques AS cmp
            WHERE cmp.id = T.N.value('@id', 'int')
        );

        /* CC_ReconexionAgua */
        INSERT INTO dbo.CC_ReconexionAgua
        (
            id
          , ValorFijo
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(INT, NULLIF(T.N.value('@ValorFijo', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="ReconexionAgua"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_ReconexionAgua AS cra
            WHERE cra.id = T.N.value('@id', 'int')
        );

        /* CC_InteresesMoratorios */
        INSERT INTO dbo.CC_InteresesMoratorios
        (
            id
          , ValorPorcentual
        )
        SELECT
            T.N.value('@id', 'int')
          , CONVERT(DECIMAL(6,5), NULLIF(T.N.value('@ValorPorcentual', N'nvarchar(32)'), N''))
        FROM @xml.nodes('/Catalogos/CCs/CC[@nombre="InteresesMoratorios"]') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.CC_InteresesMoratorios AS cim
            WHERE cim.id = T.N.value('@id', 'int')
        );

        /* TipoUsuario y Usuario admin (combinando PDF + XML)  */
        IF NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoUsuario AS tu
            WHERE tu.id = 1
        )
        BEGIN
            INSERT INTO dbo.TipoUsuario
            (
                id
              , nombre
            )
            VALUES
            (
                1
              , N'Administrador'
            );
        END;

        IF NOT EXISTS
        (
            SELECT
                1
            FROM dbo.TipoUsuario AS tu
            WHERE tu.id = 2
        )
        BEGIN
            INSERT INTO dbo.TipoUsuario
            (
                id
              , nombre
            )
            VALUES
            (
                2
              , N'Propietario'
            );
        END;

        /* Usuario admin desde <UsuarioAdmin> */
        INSERT INTO dbo.Usuario
        (
            id
          , ValorDocumento
          , idTipoUsuario
        )
        SELECT
            T.N.value('@id', 'int')
          , T.N.value('@nombre', N'nvarchar(32)')   -- puedes cambiarlo a algún valorDocumento fijo si prefieres
          , 1                                       -- Administrador
        FROM @xml.nodes('/Catalogos/UsuarioAdmin/Admin') AS T(N)
        WHERE NOT EXISTS
        (
            SELECT
                1
            FROM dbo.Usuario AS u
            WHERE u.id = T.N.value('@id', 'int')
        );

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0)
        BEGIN
            ROLLBACK TRAN;
        END;

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

        SET @outResultCode = 50002;
    END CATCH;
END;
GO

-- EJECUCIÓN DEL SP
DECLARE @rc INT;

EXEC dbo.usp_Xml_CargarCatalogos
    @inIdXml       = 1,   -- el IdXml del catalogosV3
    @outResultCode = @rc OUTPUT;

SELECT @rc AS ResultCode;