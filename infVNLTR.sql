-- EMPIEZA ABAJO EL EJEMPO
USE almacen
GO

SELECT *
FROM INFORMATION_SCHEMA.TABLES

DROP TABLE prueba
GO
DROP VIEW vista
GO

CREATE TABLE prueba
(
	id INT IDENTITY PRIMARY KEY,
	nombre NVARCHAR(30),
	ahorros INT
)


-- Las funciones de agregación llevan el prefijo DW<función><atributo>
CREATE VIEW vista
AS
	SELECT id, nombre, ahorros, max(ahorros) AS maximo
	FROM prueba
	GROUP BY id, nombre, ahorros
GO


SELECT *
FROM vista

INSERT INTO prueba
VALUES('Aristeo', 50)
INSERT INTO prueba
VALUES('Aristeo', 30)

-- ACÁ EMPIEZA EL EJEMPLO DE CLASE
CREATE TABLE Docencia
(
	Esc INT,
	CveEmp INT,
	Horas INT
)
GO

CREATE TABLE Asesoria
(
	Esc INT,
	CveEmp INT,
	Horas INT
)
GO

CREATE TABLE Inv
(
	Esc INT,
	CveEmp INT,
	Horas INT
)
GO

-- En teoría esto debe ser una vista, pero hay un problema
-- Una parte del algoritmo necesita verificar si la inserción en Docencia
-- no está en TADocencia, y al ser TADocencia una vista, siempre está la inserción
-- Esto lo menciona en la clase del 4 de noviembre.
-- Apenas así lo pude hacer funcionar.
CREATE TABLE TADocencia
(
	CveEmp INT,
	DWSumHoras INT
	-- Creo que esto debería ser una función de agregación
)

-- Otras tablas auxiliares con las que no he hecho más pruebas
CREATE VIEW TADocencia
AS
	SELECT CveEmp, sum(horas) AS DWSumHoras
	FROM Docencia
	GROUP BY CveEmp
	GO

CREATE VIEW TAAsesoria
AS
	SELECT CveEmp, sum(horas) AS DWSumHoras
	FROM Asesoria
	GROUP BY CveEmp
	GO

CREATE VIEW TAInv
AS
	SELECT CveEmp, sum(horas) AS DWSumHoras
	FROM Inv
	GROUP BY CveEmp
	GO

-- Se supone que los datos van a parar acá ya que las tres tablas
-- auxiliares tengan datos que hagan join. O sea si en las tres está
-- El profesor 5 esos datos se meten a la vista materializada.
CREATE VIEW vistaMaterializada
AS
	SELECT D.CveEmp, sum(D.Horas) AS HDoc, sum(A.Horas) AS HAse,
		SUM(I.Horas) AS HInv
	FROM Docencia D, Asesoria A, Inv I
	WHERE D.CveEmp = A.CveEmp AND D.CveEmp = I.CveEmp
	GROUP BY D.CveEmp
GO

DELETE FROM Docencia
GO
DELETE FROM TADocencia
GO

SELECT *
FROM TADocencia

DROP TRIGGER actualizarDocencia

INSERT INTO Docencia
VALUES(1, 31, 12)

-- El trigger, aquí se pone bueno
CREATE TRIGGER actualizarDocencia
ON Docencia
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM inserted

	-- Aquí es donde checamos si el docente que se acaba de insertar en docencia
	-- Ya está en la tabla auxiliar
	IF NOT EXISTS(SELECT *
	FROM TADocencia
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está pos lo ponemos nosotros.
		INSERT INTO TADocencia
			(CveEmp, DWSumHoras)
		VALUES(@id, @horas)
	END
	ELSE
	BEGIN
		UPDATE TADocencia
		-- Esta parte no me convence. Estoy sumando las horas del docente
		-- pero de una forma que se mria marrana.
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END
END
GO

-- Más triggers con los que no he hecho pruebas
CREATE TRIGGER actualizarAsesoria
ON Asesoria
AFTER INSERT, DELETE
AS
BEGIN
	PRINT 'Wenas'
END
GO

CREATE TRIGGER actualizarInv
ON Inv
AFTER INSERT, DELETE
AS
BEGIN
	PRINT 'Wenas'
END
GO