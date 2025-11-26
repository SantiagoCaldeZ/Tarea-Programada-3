const express = require("express");
const sql = require("mssql");
const path = require("path");

const dbconfig = {
    user: "bdsc",
    password: "Franco2025",
    server: "francobd12025.database.windows.net",
    database: "bdt3",
    options: {
        encrypt: true,
        trustServerCertificate: false
    }
};

const app = express();
const port = 3000;

// Middlewares
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public")));

// ============================================================================
// LOGIN ADMIN  -> usa usp_AdminLogin
// ============================================================================
app.post("/login-admin", async (req, res) => {
    try {
        const { valorDocumento } = req.body;

        if (!valorDocumento) {
            return res.status(400).json({
                success: false,
                message: "Debe ingresar el documento del administrador."
            });
        }

        const pool = await sql.connect(dbconfig);

        const result = await pool.request()
            .input("inValorDocumento", sql.NVarChar(32), valorDocumento)
            .output("outResultCode", sql.Int)
            .execute("usp_AdminLogin");

        if (result.output.outResultCode !== 0 || result.recordset.length === 0) {
            return res.json({
                success: false,
                message: "Administrador inválido."
            });
        }

        return res.json({
            success: true,
            message: "Login correcto."
        });

    } catch (err) {
        console.error("Error en /login-admin:", err);
        return res.status(500).json({
            success: false,
            message: "Error en el servidor."
        });
    }
});

// ============================================================================
// BUSCAR PROPIEDAD POR FINCA -> usa usp_PropiedadPorFinca
// ============================================================================
app.get("/api/propiedad-por-finca/:finca", async (req, res) => {
    const finca = req.params.finca;

    try {
        const pool = await sql.connect(dbconfig);
        const result = await pool.request()
            .input("inNumeroFinca", sql.NVarChar(64), finca)
            .output("outResultCode", sql.Int)
            .execute("usp_PropiedadPorFinca");

        const code = result.output.outResultCode;

        if (code !== 0) {
            return res.json({ success: false, message: "Error SP: " + code });
        }

        const propiedad = result.recordsets[0][0] || null;
        const facturas = result.recordsets[1] || [];

        return res.json({
            success: true,
            propiedad,
            facturasPendientes: facturas
        });

    } catch (err) {
        console.error("🔥 Error en /api/propiedad-por-finca:", err);
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ============================================================================
// BUSCAR PROPIEDADES POR DOCUMENTO -> usa usp_PropiedadesPorPersona
// ============================================================================
app.get("/api/propiedades-por-persona/:valorDocumento", async (req, res) => {
    try {
        const { valorDocumento } = req.params;

        const pool = await sql.connect(dbconfig);

        const result = await pool.request()
            .input("inValorDocumento", sql.NVarChar(64), valorDocumento)
            .output("outResultCode", sql.Int)
            .execute("usp_PropiedadesPorPersona");

        if (result.output.outResultCode !== 0 || result.recordset.length === 0) {
            return res.json({
                success: false,
                message: "No se encontraron propiedades para ese propietario."
            });
        }

        return res.json({
            success: true,
            propiedades: result.recordset
        });

    } catch (err) {
        console.error("Error en /api/propiedades-por-persona:", err);
        return res.status(500).json({
            success: false,
            message: "Error en el servidor."
        });
    }
});

// ============================================================================
// PAGO INDIVIDUAL -> usa usp_RegistrarPagoIndividual
// ============================================================================
app.post("/api/pagar-factura", async (req, res) => {
    console.log("📌 Datos recibidos en /api/pagar-factura:", req.body);

    const { idFactura, tipoMedioPagoId, numeroReferencia } = req.body;

    try {
        const pool = await sql.connect(dbconfig);

        const result = await pool.request()
            .input("inIdFactura", sql.Int, idFactura)
            .input("inTipoMedioPagoId", sql.Int, tipoMedioPagoId)
            .input("inNumeroReferencia", sql.VarChar(100), numeroReferencia)
            .output("outResultCode", sql.Int)
            .execute("usp_RegistrarPagoIndividual");  // ← CORREGIDO

        console.log("📌 Resultado SP RegistrarPagoIndividual:", result);

        const code = result.output.outResultCode;

        if (code !== 0) {
            console.error("❌ SP devolvió error:", code);
            return res.json({ success: false, message: "Error SP: " + code });
        }

        return res.json({ success: true, message: "Pago registrado correctamente." });

    } catch (err) {
        console.error("🔥 ERROR en /api/pagar-factura:", err);
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ============================================================================
// ARRANCAR SERVIDOR
// ============================================================================
app.listen(port, () => {
    console.log(`Servidor corriendo en http://localhost:${port}`);
});