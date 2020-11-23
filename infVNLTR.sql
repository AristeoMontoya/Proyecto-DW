-- EMPIEZA ABAJO EL EJEMPO
USE almacen
GO

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
GO

CREATE TABLE TAAsesoria
(
	CveEmp INT,
	DWSumHoras INT
)
GO

CREATE TABLE TAInv
(
	CveEmp INT,
	DWSumHoras INT
)
GO

CREATE TABLE TablaVH
(
	CveEmp INT,
	UltimoVN INT
)
GO

CREATE TABLE TablaControl
(
	CurrentVN INT,
	MaintenanceActive BIT
)
GO

CREATE TABLE TablaVD
(
	CveEmp INT,
	HDoc INT,
	HAse INT,
	HInv INT,
	VnInicio INT,
	VnFin INT,
	operacion VARCHAR(6)
)
GO


SELECT *
FROM INFORMATION_SCHEMA.TABLES

DROP TABLE TAAsesoria
GO

DROP TABLE TADocencia
GO

DROP TABLE TAInv
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

DROP TRIGGER actualizarDocenciaInsert

INSERT INTO Docencia
VALUES(1, 31, 12)



-- El trigger, aquí se pone bueno
CREATE TRIGGER actualizarDocenciaInsert
ON Docencia
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @sesion INT, @operacion NVARCHAR(6)
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SET @operacion = 'insert'
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
		-- Si está lo actualizamos
		UPDATE TADocencia
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp

	IF (EXISTS
	(SELECT 1
	FROM #TWD))
	BEGIN
		SELECT *
		INTO #S
		FROM TablaControl
		SELECT @sesion = CurrentVN
		FROM #S

		-- AQUÍ COMIENZA LA ACTUALIZACIÓN
		IF(@id NOT IN (SELECT CveEmp
		FROM TablaVH))
		BEGIN
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
			FROM #TWD
		END
		ELSE
		BEGIN
			SELECT VnInicio, VnFin
			INTO #IniFin
			FROM TablaVD
			WHERE CveEmp = @id AND VnFin = 2147000
			IF (SELECT VnInicio
			FROM #IniFin) = @sesion
			BEGIN
				UPDATE TablaVD SET HDoc =
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
			UPDATE TablaVH SET UltimoVN = @sesion
			UPDATE TablaControl SET MaintenanceActive = 'True'
		END
	END
END
GO





INSERT INTO Docencia
VALUES(1, 1, 5)
GO

INSERT INTO Asesoria
VALUES(1, 1, 5)
GO

INSERT INTO Inv
VALUES(1, 1, 5)
GO


SELECT *
FROM TADocencia
GO

SELECT *
FROM TAAsesoria
GO

SELECT *
FROM TAInv
GO

SELECT *
FROM TablaControl GO

SELECT *
FROM TablaVD GO

SELECT *
FROM TablaVH GO


DELETE FROM Docencia
GO

DELETE FROM Asesoria
GO

DELETE FROM Inv
GO

DELETE FROM TADocencia
GO

DELETE FROM TAAsesoria
GO

DELETE FROM TAInv
GO

DELETE FROM TablaVD
GO

DELETE FROM TablaVH
GO

DELETE FROM TablaControl
GO

INSERT INTO TablaControl
VALUES
	(1, 0)
	GO

-- TRIGGER DELETE
CREATE TRIGGER actualizarDocenciaDelete
ON Docencia
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion NVARCHAR(6), @sesion INT

	-- Primero saco los datos de la tabla inserted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted
	UPDATE TADocencia

	SET DWSumHoras -= @horas
	WHERE CveEmp = @id

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp

	-- Pa' lo de las tablas auxiliares
	IF (EXISTS
	(SELECT 1
	FROM TWD))
	BEGIN
		IF (SELECT acc
		FROM TDW) = 0
		BEGIN
			DELETE FROM TADocencia WHERE CveEmp = @id
			DELETE FROM TAInv WHERE CveEmp = @id
			DELETE FROM TAAsesoria WHERE CveEmp = @id
		END
		ELSE
		BEGIN
			SELECT DWSumHoras AS suma
			INTO acumulado
			FROM TADocencia
			WHERE CveEmp = @id
			IF (SELECT suma
			FROM acumulado) = 0
			BEGIN
				DELETE FROM TADocencia WHERE CveEmp = @id
			END

			SELECT DWSumHoras AS suma
			INTO acumulado
			FROM TADocencia
			WHERE CveEmp = @id
			IF (SELECT suma
			FROM acumulado) = 0
			BEGIN
				DELETE FROM TAInv WHERE CveEmp = @id
			END

			SELECT DWSumHoras AS suma
			INTO acumulado
			FROM TADocencia
			WHERE CveEmp = @id
			IF (SELECT suma
			FROM acumulado) = 0
			BEGIN
				DELETE FROM TAAsesoria WHERE CveEmp = @id
			END
			SET @operacion = 'insert'
		END
		SELECT *
		INTO S
		FROM TablaControl
		SELECT @sesion = CurrentVN
		FROM S
		IF (@id NOT IN (SELECT CveEmp
		FROM TablaVH))
			BEGIN
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
			FROM TDW
		END
		ELSE
		BEGIN
			SELECT VnInicio, VnFin
			INTO IniFin
			FROM TablaVD
			WHERE CveEmp = @id AND VnFin = 2147000
			IF (SELECT VnInicio
			FROM IniFin) = @sesion
			BEGIN
				PRINT 'a'
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM TDW
			END
			UPDATE TablaH SET UltimoVN = @sesion
			UPDATE TablaControl SET MaintenanceActive = 'True'
		END
	END
END
GO








-- Más triggers con los que no he hecho pruebas
CREATE TRIGGER actualizarAsesoriaInsert
ON Asesoria
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
	FROM TAAsesoria
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está pos lo ponemos nosotros.
		INSERT INTO TAAsesoria
			(CveEmp, DWSumHoras)
		VALUES(@id, @horas)
	END
	ELSE
	BEGIN
		UPDATE TAAsesoria
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END

-- SELECT (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acumulado
-- INTO TWD
-- FROM TADocencia t1
-- 	JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
-- 	JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp
-- IF (EXISTS(SELECT 1
-- FROM TWD))
END
GO

CREATE TRIGGER actualizarInv
ON Inv
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
	FROM TAInv
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está pos lo ponemos nosotros.
		INSERT INTO TAInv
			(CveEmp, DWSumHoras)
		VALUES(@id, @horas)
	END
	ELSE
	BEGIN
		UPDATE TAInv
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END

-- SELECT (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acumulado
-- INTO TWD
-- FROM TADocencia t1
-- 	JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
-- 	JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp
-- IF (EXISTS(SELECT 1
-- FROM TWD))
END
GO


/*

trigger de borrado de docencia que hizo en la clase del 5

SELECT @IDPROF=IDPROF, @horas=horas
FROM deleted
UPDATE TAuxDocencia set DWSUMhoras=DWSUMhoras-@horas, DWCOUNThoras=DWCOUNThoras-1
WHERE IDPROF=@IDPROF

-- VALIDAMOS SI HAY JOIN EN LAS TRES

SET @Acumulado = -1
SELECT @Acumulado=SUM(horas) FROM TADocencia D
	INNER JOIN TAAsesoria A ON D.IDPROF=A.IDPROF
	INNER JOIN TAInvestigacion I ON A.IDPROF=I.IDPROF
IF @Acumulado=-1 -- NO HIZO JOIN
	RETURN
IF @Acumulado=0
BEGIN
	DELETE FROM TADocencia WHERE IDPROF = @IDPROF
	DELETE FROM TAAsesoria WHERE IDPROF = @IDPROF
	DELETE FROM TAInvestigacion WHERE IDPROF = @IDPROF
END
ELSE
	SET @Acumulado = -1
	SELECT @Acumulado=SUM(horas) FROM TADocencia D WHERE IDPROF=@IDPROF
	IF @Acumulado = 0
		DELETE FROM TADocencia WHERE IDPROF = @IDPROF
	END

BEGIN
*/