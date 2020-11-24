-- EMPIEZA ABAJO EL EJEMPLO
USE almacen
GO

CREATE TABLE Docencia
(
	Esc INT,
	CveEmp INT,
	Horas INT,
	PRIMARY KEY(Esc, CveEmp)
)
GO

CREATE TABLE Asesoria
(
	Esc INT,
	CveEmp INT,
	Horas INT,
	PRIMARY KEY(Esc, CveEmp)
)
GO

CREATE TABLE Inv
(
	Esc INT,
	CveEmp INT,
	Horas INT,
	PRIMARY KEY(Esc, CveEmp)
)
GO

CREATE TABLE TAuxDocencia
(
	CveEmp INT PRIMARY KEY,
	DWSumHoras INT,
	DWMaxHoras INT
)
GO

CREATE TABLE TAuxAsesoria
(
	CveEmp INT PRIMARY KEY,
	DWSumHoras INT,
	DWCountHoras INT,
	DWAvgHoras NUMERIC(6, 2)
)
GO

CREATE TABLE TAuxInvestigacion
(
	CveEmp INT PRIMARY KEY,
	DWSumHoras INT,
	DWCountHoras INT
)
GO

CREATE TABLE TablaVH
(
	CveEmp INT PRIMARY KEY,
	UltimoVN INT
)
GO

CREATE TABLE TablaControl
(
	CurrentVN INT PRIMARY KEY,
	MaintenanceActive BIT
)
GO

CREATE TABLE TablaVD
(
	CveEmp INT,
	HDoc INT,
	HAse INT,
	HInv INT,
	MaxDoc INT,
	CountAse INT,
	AvgAse NUMERIC(6, 2),
	CountInv INT,
	VnInicio INT,
	VnFin INT,
	operacion VARCHAR(6),
	PRIMARY KEY(CveEmp, VnInicio)
)
GO

CREATE TABLE AsociadaDocencia 
(
	CveEmp INT,
	AttrNombre VARCHAR(15),
	AttrValor INT,
	AttrVeces INT,
	PRIMARY KEY(CveEmp, AttrValor)
)


-- PROCEDIMIENTO ALMACENADO
CREATE PROCEDURE usp_updateDW (@id INT, @operacion VARCHAR(6))
AS
BEGIN
	DECLARE @sesion INT, @VnIni INT, @VnFin INT, @HDoc INT, @HAse INT,
	@HInv INT, @suma INT, @maxDoc INT, @countAse INT, @avgAse NUMERIC(6, 2), @countInv INT


	SELECT t1.CveEmp, t1.DWSumHoras AS HDoc, t2.DWSumHoras AS HAse, t3.DWSumHoras AS HInv,
	t1.DWMaxHoras AS MaxDoc, t2.DWCountHoras AS CountAse, t2.DWAvgHoras AS AvgAse,
	t3.DWCountHoras AS CountInv,
		(t1.DWSumHoras + t2.DWSumHoras + t3.DWSumHoras) AS acumulado
	INTO #TWD
	FROM TAuxDocencia t1
		JOIN TAuxAsesoria t2 ON t2.CveEmp = t1.CveEmp
		JOIN TAuxInvestigacion t3 ON t3.CveEmp = t1.CveEmp
	WHERE t1.CveEmp = @id
	
	-- De existir join, entra a este if
	IF (EXISTS
	(SELECT 1
	FROM #TWD))
	BEGIN

		IF @operacion = 'delete'
		BEGIN
			
			IF (SELECT acumulado
			FROM #TWD) = 0
			BEGIN
				-- Este if entra si el acumulado de las funciones de agregación es cero
				DELETE FROM TAuxDocencia WHERE CveEmp = @id
				DELETE FROM TAuxInvestigacion WHERE CveEmp = @id
				DELETE FROM TAuxAsesoria WHERE CveEmp = @id

			END
			ELSE
			BEGIN
				DECLARE @sumaCero BIT
				SET @sumaCero = 0
				
				-- Buscamos si alguna de las tablas auxiliares queda en cero
				SELECT @suma = DWSumHoras
				FROM TAuxDocencia
				WHERE CveEmp = @id

				IF (@suma) = 0
				BEGIN
					SET @sumaCero = 1
					DELETE FROM TAuxDocencia WHERE CveEmp = @id
				END

				SELECT @suma = DWSumHoras
				FROM TAuxInvestigacion
				WHERE CveEmp = @id

				IF (@suma) = 0
				BEGIN
					SET @sumaCero = 1
					DELETE FROM TAuxInvestigacion WHERE CveEmp = @id
				END

				SELECT @suma =  DWSumHoras
				FROM TAuxAsesoria
				WHERE CveEmp = @id
				
				IF (@suma) = 0
				BEGIN
					SET @sumaCero = 1
					DELETE FROM TAuxAsesoria WHERE CveEmp = @id
				END

				-- Si alguna quedó en cero se borraron datos de la tabla auxiliar para
				-- evitar join falsos. La operación fue un delete
				IF @sumaCero = 0
				BEGIN
					SET @operacion = 'insert'	
				END

			END
		END
		
		-- De la tabla de Control obtenemos la sesión actual
		SELECT @sesion = CurrentVN
		FROM TablaControl

		-- AQUÍ COMIENZA LA ACTUALIZACIÓN
		IF(@id NOT IN (SELECT CveEmp
		FROM TablaVH))
		BEGIN
			-- Si no está el ID en la tabla VH quiere decir que es la primera vez que hace join
			-- Lo insertamos en VH
			INSERT INTO TablaVH
			VALUES(@id, @sesion)

			-- Insertamos en la tabla de hechos
			INSERT INTO TablaVD
			SELECT CveEmp, HDoc, HAse, HInv, MaxDoc, CountAse, AvgAse, CountInv, @sesion, 2147000, @operacion
			FROM #TWD
		END
		ELSE
		BEGIN
			-- Ya existía en el almacén
			SELECT @VnIni = VnInicio,
				@VnFin = VnFin
			FROM TablaVD
			WHERE CveEmp = @id AND VnFin = 2147000

			IF @VnIni = @sesion
			BEGIN
				-- Hacemos un update al almacén si la versión de inicio 
				-- es la misma que la última versión de la tabla de control
				SELECT
					@HDoc = HDoc,
					@HAse = HAse,
					@HInv = HInv,
					@maxDoc = MaxDoc,
					@countAse = CountAse,
					@avgAse = AvgAse,
					@countInv = CountInv
				FROM #TWD

				UPDATE TablaVD SET HDoc = @HDoc, HAse = @HAse, HInv = @HInv, MaxDoc = @maxDoc, CountAse = @countAse,
				AvgAse = @avgAse, CountInv = @countInv,operacion = @operacion
			END
			ELSE
			BEGIN
				-- Si es una versión diferente actualizamos la versión final del almacén
				UPDATE TablaVD SET VNFin = @sesion - 1 
					WHERE CveEmp = @id AND VnFin = 2147000

				INSERT INTO TablaVD
				SELECT CveEmp, HDoc, HAse, HInv, MaxDoc, CountAse, AvgAse, CountInv, @sesion, 2147000, @operacion
				FROM #TWD
			END
		END
		UPDATE TablaVH SET UltimoVN = @sesion
		UPDATE TablaControl SET MaintenanceActive = 'True'
	END
END
GO



-- TRIGGERS
-- Docencia
CREATE TRIGGER actualizarDocenciaInsert
ON Docencia
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6)

	-- Recuperación de los datos de la tabla inserted
	SET @operacion = 'insert'
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM inserted

	-- Aquí es donde checamos si el docente que se acaba de insertar en docencia
	-- Ya está en la tabla auxiliar
	IF NOT EXISTS(SELECT *
	FROM TAuxDocencia
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está en la tabla auxiliar se agrega
		INSERT INTO TAuxDocencia
			(CveEmp, DWSumHoras, DWMaxHoras)
		VALUES(@id, @horas, @horas)

		INSERT INTO AsociadaDocencia VALUES(@id, 'Horas', @horas, 1)
	END
	ELSE
	BEGIN
		-- Si se encuentra al docente en la tabla auxiliar se hace update
		UPDATE TAuxDocencia
		SET DWSumHoras += @horas
		WHERE CveEmp = @id

		IF EXISTS(SELECT * FROM AsociadaDocencia 
		WHERE CveEmp = @id AND AttrValor = @horas)
		BEGIN
			
			UPDATE AsociadaDocencia SET AttrVeces = AttrVeces + 1
			WHERE CveEmp = @id AND AttrValor = @horas
		END
		ELSE
		BEGIN

			INSERT INTO AsociadaDocencia VALUES(@id, 'Horas', @horas, 1)
			
			DECLARE @dwmax INT
			SELECT @dwmax = DWMaxHoras FROM TAuxDocencia
			
			IF @horas > @dwmax
			BEGIN
			
				UPDATE TAuxDocencia SET DWMaxHoras = @horas
				WHERE CveEmp = @id
			END
		END
	END
	
	EXEC usp_updateDW @id, @operacion
END
GO


CREATE TRIGGER actualizarDocenciaDelete
ON Docencia
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6),
	@maximo INT, @attrVeces INT

	SET @operacion = 'delete'
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted

	UPDATE TAuxDocencia
	SET DWSumHoras -= @horas
	WHERE CveEmp = @id
	
	SELECT @attrVeces = AttrVeces - 1 FROM AsociadaDocencia

	UPDATE AsociadaDocencia SET AttrVeces = @attrVeces
	WHERE CveEmp = @id AND AttrValor = @horas

	IF @attrVeces = 0
	BEGIN
		DELETE FROM AsociadaDocencia 
		WHERE CveEmp = @id AND AttrVeces = 0 AND AttrNombre = 'horas'
		
		SELECT @maximo = MAX(AttrValor) FROM AsociadaDocencia
		WHERE CveEmp = @id AND AttrNombre = 'horas'

		IF @maximo IS NULL
		BEGIN
			SET @maximo = 0
		END
		
		UPDATE TAuxDocencia SET DWMaxHoras = @maximo
		WHERE CveEmp = @id
	END

	EXEC usp_updateDW @id, @operacion
END
GO



-- Asesorías
CREATE TRIGGER actualizarAsesoriaInsert
ON Asesoria
AFTER INSERT
AS
BEGIN
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6)
	
	-- Primero sacamos los datos de la tabla inserted. Todo normal.
	SET @operacion = 'insert'
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM inserted

	-- Aquí es donde checamos si el docente que se acaba de insertar en docencia
	-- Ya está en la tabla auxiliar
	IF NOT EXISTS(SELECT *
	FROM TAuxAsesoria
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está lo ponemos nosotros.
		INSERT INTO TAuxAsesoria
			(CveEmp, DWSumHoras, DWCountHoras, DWAvgHoras)
		VALUES(@id, @horas, 1, @horas)
	END
	ELSE
	BEGIN
		-- Si ya está lo actualizamos
		UPDATE TAuxAsesoria
		SET DWSumHoras += @horas, DWCountHoras += 1,
			DWAvgHoras = CAST(DWSumHoras+@horas AS NUMERIC(6, 2))/CAST(DWCountHoras+1 AS NUMERIC(6, 2))
		WHERE CveEmp = @id
	END

	EXEC usp_updateDW @id, @operacion
END
GO


CREATE TRIGGER actualizarAsesoriaDelete
ON Asesoria
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6)

	SET @operacion = 'delete'
	-- Primero obtenemos los datos de la tabla deleted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted

	DECLARE @AVG NUMERIC(6, 2)
	SET @AVG = 0
	IF 1 < (SELECT DWCountHoras FROM TAuxAsesoria WHERE CveEmp = @id)
	BEGIN
		DECLARE @DWSumHoras INT, @DWCountHoras INT
		SELECT @DWSumHoras = DWSumHoras, @DWCountHoras = DWCountHoras FROM TAuxAsesoria WHERE CveEmp = @id
		SET @AVG = cast(@DWSumHoras-@horas as numeric(6, 2))/cast(@DWCountHoras-1 as numeric(6, 2))
	END

	UPDATE TAuxAsesoria
	SET DWSumHoras -= @horas, DWCountHoras -= 1, DWAvgHoras = @AVG
	WHERE CveEmp = @id

	EXEC usp_updateDW @id, @operacion
END
GO


-- Investigación
CREATE TRIGGER actualizarInvInsert
ON Inv
AFTER INSERT
AS
BEGIN
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6)
	
	-- Primero obtenemos los datos de la tabla inserted. Todo normal.
	SET @operacion = 'insert'
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM inserted

	-- Aquí es donde checamos si el docente que se acaba de insertar en investigación
	-- Ya está en la tabla auxiliar
	IF NOT EXISTS(SELECT *
	FROM TAuxInvestigacion
	WHERE CveEmp = @id)
	BEGIN
		-- Si no está lo ponemos nosotros.
		INSERT INTO TAuxInvestigacion
			(CveEmp, DWSumHoras, DWCountHoras)
		VALUES(@id, @horas, 1)
	END
	ELSE
	BEGIN
		-- Si ya está lo actualizamos
		UPDATE TAuxInvestigacion
		SET DWSumHoras += @horas, DWCountHoras += 1
		WHERE CveEmp = @id
	END
	
	EXEC usp_updateDW @id, @operacion
END
GO


CREATE TRIGGER actualizarInvDelete
ON Inv
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @esc INT, @id INT, @horas INT, @operacion VARCHAR(6)

	SET @operacion = 'delete'
	-- Primero saco los datos de la tabla deleted. Todo normal.
	SELECT @esc = Esc, @id = CveEmp, @horas = Horas
	FROM deleted

	UPDATE TAuxInvestigacion
	SET DWSumHoras -= @horas, DWCountHoras -= 1
	WHERE CveEmp = @id

	EXEC usp_updateDW @id, @operacion
END
GO




-- PRUEBAS
DELETE FROM Docencia 
GO

DELETE FROM Asesoria 
GO

DELETE FROM Inv 
GO

DELETE FROM TAuxAsesoria 
GO

DELETE FROM TAuxDocencia 
GO

DELETE FROM TAuxInvestigacion 
GO

DELETE FROM TablaVD 
GO

DELETE FROM TablaVH 
GO

DELETE FROM TablaControl 
GO

INSERT INTO TablaControl VALUES(1,0)
GO




SELECT * FROM TAuxDocencia GO

SELECT * FROM TAuxAsesoria GO

SELECT * FROM TAuxInvestigacion GO

SELECT * FROM TablaVD GO

SELECT * FROM TablaVH GO

SELECT * FROM TablaControl GO



delete from Docencia where CveEmp = 5 and Horas = 50

DELETE FROM Docencia

INSERT INTO Docencia VALUES (30, 5, 10)
GO

INSERT INTO Docencia VALUES (20, 5, 50)
GO

INSERT INTO Inv VALUES (20, 5, 5)
GO

INSERT INTO Asesoria VALUES (20, 5, 3)
GO

INSERT INTO Asesoria VALUES (30, 5, 4)
GO

DELETE FROM Asesoria Where Esc = 20 AND CveEmp = 5 AND Horas = 3
GO

DELETE FROM Asesoria Where Esc = 30 AND CveEmp = 5 AND Horas = 4
GO

UPDATE TablaControl SET CurrentVN = 2, MaintenanceActive = 'False'
GO

INSERT INTO Asesoria VALUES (30, 5, 15)
GO

DELETE FROM TAuxDocencia where CveEmp = 5


-- ZONA DE PELIGRO
SELECT * FROM INFORMATION_SCHEMA.tables

DROP TRIGGER actualizarDocenciaInsert
GO

DROP TRIGGER actualizarDocenciaDelete
GO

DROP TRIGGER actualizarAsesoriaInsert
GO

DROP TRIGGER actualizarAsesoriaDelete
GO

DROP TRIGGER actualizarInvInsert
GO

DROP TRIGGER actualizarInvDelete
GO

DROP PROCEDURE usp_updateDW
GO

DROP TABLE Docencia, Asesoria, Inv, TAuxDocencia, TAuxAsesoria, 
TAuxInvestigacion, TablaVD, TablaControl, TablaVH, AsociadaDocencia
GO