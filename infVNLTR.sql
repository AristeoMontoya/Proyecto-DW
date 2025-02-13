-- EMPIEZA ABAJO EL EJEMPO
USE almacen
GO

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

CREATE TABLE TADocencia
(
	CveEmp INT,
	DWSumHoras INT
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


-- Comeinzo del trigger
CREATE TRIGGER actualizarDocenciaInsert
ON Docencia
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @sesion INT, @operacion NVARCHAR(6),
	 @HDoc INT, @HAse INT, @HInv INT
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
	WHERE t1.CveEmp = @id

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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO


-- TRIGGER DELETE
CREATE TRIGGER actualizarDocenciaDelete
ON Docencia
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion NVARCHAR(6), @sesion INT, @suma INT,
	@HDoc INT, @HAse INT, @HInv INT

	SET @operacion = 'insert'
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

	-- COMIENZO DE LA ACTUALIZACIÓN
	IF (EXISTS
	(SELECT 1
	FROM #TWD))
	BEGIN
		IF (SELECT acc
		FROM #TWD) = 0
		BEGIN
			DELETE FROM TADocencia WHERE CveEmp = @id
			DELETE FROM TAInv WHERE CveEmp = @id
			DELETE FROM TAAsesoria WHERE CveEmp = @id

		END
		ELSE
		BEGIN
			SELECT @suma = DWSumHoras
			FROM TADocencia
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TADocencia WHERE CveEmp = @id
			END

			SELECT @suma = DWSumHoras
			FROM TAInv
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAInv WHERE CveEmp = @id
			END

			SELECT @suma =  DWSumHoras
			FROM TAAsesoria
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAAsesoria WHERE CveEmp = @id
			END

		END
		SELECT *
		INTO #S
		FROM TablaControl

		SELECT @sesion = CurrentVN
		FROM #S

		IF (@id NOT IN (SELECT CveEmp
		FROM TablaVH))
		BEGIN
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
			FROM #TDW
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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO








-- Asesorías

CREATE TRIGGER actualizarAsesoriaInsert
ON Asesoria
AFTER INSERT
AS
BEGIN
	DECLARE @esc INT, @id INT, @horas INT, @sesion INT, @operacion NVARCHAR(6),
	 @HDoc INT, @HAse INT, @HInv INT
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SET @operacion = 'insert'
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
		-- Si está lo actualizamos
		UPDATE TAAsesoria
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp
	WHERE t1.CveEmp = @id

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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO

CREATE TRIGGER actualizarAsesoriaDelete
ON Asesoria
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion NVARCHAR(6), @sesion INT, @suma INT,
	@HDoc INT, @HAse INT, @HInv INT

	SET @operacion = 'insert'
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted
	UPDATE TAAsesoria

	SET DWSumHoras -= @horas
	WHERE CveEmp = @id

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp

	-- COMIENZO DE LA ACTUALIZACIÓN
	IF (EXISTS
	(SELECT 1
	FROM #TWD))
	BEGIN
		IF (SELECT acc
		FROM #TWD) = 0
		BEGIN
			DELETE FROM TADocencia WHERE CveEmp = @id
			DELETE FROM TAInv WHERE CveEmp = @id
			DELETE FROM TAAsesoria WHERE CveEmp = @id

		END
		ELSE
		BEGIN
			SELECT @suma = DWSumHoras
			FROM TADocencia
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TADocencia WHERE CveEmp = @id
			END

			SELECT @suma = DWSumHoras
			FROM TAInv
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAInv WHERE CveEmp = @id
			END

			SELECT @suma =  DWSumHoras
			FROM TAAsesoria
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAAsesoria WHERE CveEmp = @id
			END

		END
		SELECT *
		INTO #S
		FROM TablaControl

		SELECT @sesion = CurrentVN
		FROM #S

		IF (@id NOT IN (SELECT CveEmp
		FROM TablaVH))
		BEGIN
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
			FROM #TDW
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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO

-- Investigación

CREATE TRIGGER actualizarInvInsert
ON Inv
AFTER INSERT
AS
BEGIN
	DECLARE @esc INT, @id INT, @horas INT, @sesion INT, @operacion NVARCHAR(6),
	 @HDoc INT, @HAse INT, @HInv INT
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SET @operacion = 'insert'
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
		-- Si está lo actualizamos
		UPDATE TAInv
		SET DWSumHoras += @horas
		WHERE CveEmp = @id
	END

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp
	WHERE t1.CveEmp = @id

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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO


CREATE TRIGGER actualizarInvDelete
ON Inv
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion NVARCHAR(6), @sesion INT, @suma INT,
	@HDoc INT, @HAse INT, @HInv INT

	SET @operacion = 'insert'
	-- Primero saco los datos de la tabla inserted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted
	UPDATE TAInv

	SET DWSumHoras -= @horas
	WHERE CveEmp = @id

	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv, (t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acc
	INTO #TWD
	FROM TADocencia t1
		JOIN TAAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAInv t3 ON t3.CveEmp = t1.CveEmp

	-- COMIENZO DE LA ACTUALIZACIÓN
	IF (EXISTS
	(SELECT 1
	FROM #TWD))
	BEGIN
		IF (SELECT acc
		FROM #TWD) = 0
		BEGIN
			DELETE FROM TADocencia WHERE CveEmp = @id
			DELETE FROM TAInv WHERE CveEmp = @id
			DELETE FROM TAAsesoria WHERE CveEmp = @id

		END
		ELSE
		BEGIN
			SELECT @suma = DWSumHoras
			FROM TADocencia
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TADocencia WHERE CveEmp = @id
			END

			SELECT @suma = DWSumHoras
			FROM TAInv
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAInv WHERE CveEmp = @id
			END

			SELECT @suma =  DWSumHoras
			FROM TAAsesoria
			WHERE CveEmp = @id

			IF (@suma) = 0
			BEGIN
				SET @operacion = 'delete'
				DELETE FROM TAAsesoria WHERE CveEmp = @id
			END

		END
		SELECT *
		INTO #S
		FROM TablaControl

		SELECT @sesion = CurrentVN
		FROM #S

		IF (@id NOT IN (SELECT CveEmp
		FROM TablaVH))
		BEGIN
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
			FROM #TDW
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
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, operacion = @operacion
			END
			ELSE
			BEGIN
				UPDATE TablaVD SET VNFin = @sesion - 1 
				WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO



SELECT *
FROM TADocencia GO

SELECT *
FROM TAAsesoria GO

SELECT *
FROM TAInv GO

SELECT *
FROM TablaVH GO

SELECT *
FROM TablaVD GO

SELECT *
FROM TablaControl GO

-- PRUEBAS

INSERT INTO TablaControl
VALUES(1, 0)
GO

UPDATE TablaControl SET CurrentVN = 2, MaintenanceActive = 'false'

INSERT INTO Docencia
VALUES
	(20, 5, 10)
	GO

INSERT INTO Inv
VALUES
	(20, 5, 5)
	GO

INSERT INTO Asesoria
VALUES
	(20, 5, 3)
	GO

INSERT INTO Asesoria
VALUES
	(30, 5, 15)
	GO

DELETE FROM Asesoria WHERE Esc = 30 AND CveEmp = 5 AND Horas = 4
DELETE FROM Asesoria WHERE Esc = 20 AND CveEmp = 5 AND Horas = 3

-- DELETES
DELETE FROM TADocencia 
GO

DELETE FROM TAAsesoria 
GO

DELETE FROM TAInv 
GO

DELETE FROM TablaVH 
GO

DELETE FROM TablaVD 
GO

DELETE FROM TablaControl 
GO