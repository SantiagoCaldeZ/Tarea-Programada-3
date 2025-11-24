const express = require("express");
const sql = require("mssql");
const path = require("path");

const dbconfig = {
    user: "bdsc",
    password: "Franco2025",
    server: "francobd12025.database.windows.net",
    database: "bdtp3",
    options: {
        encrypt: true,
        trustServerCertificate: false
    }
};


const app = express();
const port = 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));


app.listen(port, () => {
    console.log(`Servidor corriendo en http://localhost:${port}`);
});