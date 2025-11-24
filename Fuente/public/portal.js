document.addEventListener("DOMContentLoaded", () => {
    const txtFinca = document.getElementById("txtFinca");
    const btnBuscarFinca = document.getElementById("btnBuscarFinca");

    const txtIdentificacion = document.getElementById("txtIdentificacion");
    const btnBuscarID = document.getElementById("btnBuscarID");
    const divListaPropiedades = document.getElementById("listaPropiedades");

    const seccionPropiedad = document.getElementById("resultado-propiedad");
    const cardPropiedad = document.getElementById("cardPropiedad");

    const seccionFacturas = document.getElementById("facturas-pendientes");
    const cardFacturas = document.getElementById("cardFacturas");

    let ultimaPropiedadCargada = null;
    let ultimasFacturas = [];

    // -------------------------
    // Helper: pintar propiedad
    // -------------------------
    function renderPropiedad(propiedad) {
        seccionPropiedad.classList.remove("oculto");
        cardPropiedad.innerHTML = `
            <h2>Propiedad: ${propiedad.numeroFinca}</h2>
            <p><strong>Metros cuadrados:</strong> ${propiedad.metrosCuadrados}</p>
            <p><strong>Uso:</strong> ${propiedad.tipoUso || "N/D"}</p>
            <p><strong>Zona:</strong> ${propiedad.tipoZona || "N/D"}</p>
            <p><strong>Valor fiscal:</strong> ₡${propiedad.valorFiscal}</p>
            <p><strong>Fecha registro:</strong> ${propiedad.fechaRegistro?.substring(0, 10) || "N/D"}</p>
        `;
    }

    // -------------------------
    // Helper: pintar facturas
    // -------------------------
    function renderFacturas(facturas) {
        ultimasFacturas = facturas;

        if (!facturas || facturas.length === 0) {
            seccionFacturas.classList.remove("oculto");
            cardFacturas.innerHTML = `
                <h2>Facturas pendientes</h2>
                <p>No hay facturas pendientes para esta propiedad.</p>
            `;
            return;
        }

        seccionFacturas.classList.remove("oculto");

        let filas = "";
        facturas.forEach((f, index) => {
            const esMasVieja = index === 0;
            filas += `
                <tr class="${esMasVieja ? "factura-mas-vieja" : ""}">
                    <td>${f.id}</td>
                    <td>${f.fecha?.substring(0,10) || ""}</td>
                    <td>${f.fechaVenc?.substring(0,10) || ""}</td>
                    <td>₡${f.totalOriginal}</td>
                    <td>₡${f.totalFinal}</td>
                    <td>
                        <span class="badge badge-pendiente">Pendiente</span>
                    </td>
                </tr>
            `;
        });

        cardFacturas.innerHTML = `
            <h2>Facturas pendientes</h2>
            <p>La fila resaltada es la factura más vieja (la única que se puede pagar).</p>
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Fecha</th>
                        <th>Vence</th>
                        <th>Total original</th>
                        <th>Total final</th>
                        <th>Estado</th>
                    </tr>
                </thead>
                <tbody>
                    ${filas}
                </tbody>
            </table>

            <div style="margin-top:0.75rem;">
                <button id="btnPagarMasVieja" class="btn btn-primary">
                    Pagar factura más vieja
                </button>
            </div>
        `;

        const btnPagarMasVieja = document.getElementById("btnPagarMasVieja");
        btnPagarMasVieja.addEventListener("click", onPagarMasVieja);
    }

    // -------------------------
    // Acción: pagar factura más vieja
    // -------------------------
    async function onPagarMasVieja() {
        if (!ultimasFacturas || ultimasFacturas.length === 0) {
            Swal.fire("Sin facturas", "No hay facturas pendientes.", "info");
            return;
        }

        const factura = ultimasFacturas[0];

        const { value: formValues } = await Swal.fire({
            title: `Pagar factura #${factura.id}`,
            html: `
                <p>Total a pagar (actual): <strong>₡${factura.totalFinal}</strong></p>
                <label for="swalMedio">Medio de pago</label>
                <select id="swalMedio" class="swal2-input">
                    <option value="1">Efectivo</option>
                    <option value="2">Tarjeta</option>
                    <option value="3">Transferencia</option>
                </select>
                <label for="swalRef">Número de referencia</label>
                <input id="swalRef" class="swal2-input" placeholder="Ref. bancaria / comprobante">
            `,
            focusConfirm: false,
            preConfirm: () => {
                const medio = document.getElementById("swalMedio").value;
                const ref = document.getElementById("swalRef").value.trim();
                if (!ref) {
                    Swal.showValidationMessage("Debe ingresar un número de referencia.");
                    return false;
                }
                return { medio, ref };
            },
            showCancelButton: true,
            confirmButtonText: "Confirmar pago",
            cancelButtonText: "Cancelar"
        });

        if (!formValues) return;

        try {
            const resp = await fetch("/api/pagar-factura", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    idFactura: factura.id,
                    tipoMedioPagoId: parseInt(formValues.medio),
                    numeroReferencia: formValues.ref
                })
            });

            const data = await resp.json();

            if (!data.success) {
                Swal.fire("Error", data.message || "No fue posible procesar el pago.", "error");
                return;
            }

            Swal.fire("Pago registrado", data.message || "Pago procesado correctamente.", "success");

            // Recargar datos de la propiedad actual
            if (ultimaPropiedadCargada) {
                buscarPorFinca(ultimaPropiedadCargada.numeroFinca);
            }

        } catch (err) {
            console.error(err);
            Swal.fire("Error", "Error de comunicación con el servidor.", "error");
        }
    }

    // -------------------------
    // Búsqueda por finca
    // -------------------------
    async function buscarPorFinca(finca) {
        if (!finca) {
            Swal.fire("Dato requerido", "Debe ingresar un número de finca.", "warning");
            return;
        }

        try {
            const resp = await fetch(`/api/propiedad-por-finca/${encodeURIComponent(finca)}`);
            const data = await resp.json();

            if (!data.success) {
                Swal.fire("Sin resultados", data.message || "No se encontró la propiedad.", "info");
                seccionPropiedad.classList.add("oculto");
                seccionFacturas.classList.add("oculto");
                return;
            }

            ultimaPropiedadCargada = data.propiedad;
            renderPropiedad(data.propiedad);
            renderFacturas(data.facturasPendientes);

        } catch (err) {
            console.error(err);
            Swal.fire("Error", "Error de comunicación con el servidor.", "error");
        }
    }

    // -------------------------
    // Búsqueda por documento
    // -------------------------
    async function buscarPorDocumento(doc) {
        if (!doc) {
            Swal.fire("Dato requerido", "Debe ingresar una identificación.", "warning");
            return;
        }

        try {
            const resp = await fetch(`/api/propiedades-por-persona/${encodeURIComponent(doc)}`);
            const data = await resp.json();

            if (!data.success) {
                Swal.fire("Sin resultados", data.message || "No se encontraron propiedades.", "info");
                divListaPropiedades.innerHTML = "";
                return;
            }

            const props = data.propiedades;
            let html = "<p>Propiedades asociadas:</p><ul>";

            props.forEach(p => {
                html += `
                    <li>
                        <button class="btn btn-secondary btn-sm" data-finca="${p.numeroFinca}">
                            ${p.numeroFinca}
                        </button>
                    </li>
                `;
            });

            html += "</ul>";
            divListaPropiedades.innerHTML = html;

            // Asignar eventos a los botones
            divListaPropiedades.querySelectorAll("button[data-finca]").forEach(btn => {
                btn.addEventListener("click", () => {
                    const finca = btn.getAttribute("data-finca");
                    txtFinca.value = finca;
                    buscarPorFinca(finca);
                });
            });

        } catch (err) {
            console.error(err);
            Swal.fire("Error", "Error de comunicación con el servidor.", "error");
        }
    }

    // Eventos botones
    btnBuscarFinca.addEventListener("click", () => {
        const finca = txtFinca.value.trim();
        buscarPorFinca(finca);
    });

    btnBuscarID.addEventListener("click", () => {
        const doc = txtIdentificacion.value.trim();
        buscarPorDocumento(doc);
    });
});