select * 
from Factura
select * 
from Pago

INSERT INTO Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
VALUES (3, '2025-11-30', '2025-12-10', 5000, 5000, 1);

INSERT INTO DetalleFactura (idFactura, idCC, descripcion, monto)
VALUES (SCOPE_IDENTITY(), 1, 'Consumo de agua', 5000);
INSERT INTO Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
VALUES (2, '2025-10-15', '2025-12-01', 3200, 3200, 1);

INSERT INTO DetalleFactura (idFactura, idCC, descripcion, monto)
VALUES (SCOPE_IDENTITY(), 4, 'Impuesto de propiedad', 3200);
INSERT INTO Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
VALUES (1, '2025-09-20', '2025-12-05', 6700, 6700, 1);

INSERT INTO DetalleFactura (idFactura, idCC, descripcion, monto)
VALUES (SCOPE_IDENTITY(), 3, 'Recolección de basura', 6700);
INSERT INTO Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
VALUES (4, '2025-08-10', '2025-12-01', 2800, 2800, 1);

INSERT INTO DetalleFactura (idFactura, idCC, descripcion, monto)
VALUES (SCOPE_IDENTITY(), 2, 'Patente comercial', 2800);
INSERT INTO Factura (idPropiedad, fecha, fechaVenc, totalOriginal, totalFinal, estado)
VALUES (5, '2025-07-01', '2025-12-20', 1500, 1500, 1);

INSERT INTO DetalleFactura (idFactura, idCC, descripcion, monto)
VALUES (SCOPE_IDENTITY(), 5, 'Mantenimiento de parques', 1500);
