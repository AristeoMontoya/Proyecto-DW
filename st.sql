USE almacen
GO

CREATE TABLE Importacion
(
	Id INT NOT NULL,
	Movimiento VARCHAR(30),
	PaisOrigen VARCHAR(30),
	PaisDestino VARCHAR(30),
	Año VARCHAR(5),
	Fecha DATE,
	Producto VARCHAR(30),
	Transporte VARCHAR(30),
	Marca NVARCHAR(50),
	Importe INT,
	PRIMARY KEY (Id)
)
GO

CREATE TABLE DimensionTiempo
(
	fecha DATE PRIMARY KEY,
	diaSemana VARCHAR(9),
	dia TINYINT,
	mes TINYINT,
	año SMALLINT,
	trimestre TINYINT
)
GO

DROP TABLE DimensionTiempo
GO

DROP PROCEDURE dimensionFecha
GO

-- DELETE FROM DimensionTiempo


CREATE PROCEDURE dimensionFecha
	@fechaActual DATETIME,
	@fechaFinal DATETIME
AS
DECLARE @diaSemana VARCHAR(9), @dia TINYINT, @mes TINYINT, @año SMALLINT, @trimestre TINYINT
SET LANGUAGE Spanish
WHILE @fechaActual <= @fechaFinal
BEGIN
	SELECT @dia=DATEPART(day, @fechaActual),
		@mes=DATEPART(month, @fechaActual),
		@año=DATEPART(year, @fechaActual),
		@diaSemana=DATENAME(weekday, @fechaActual)

	IF @mes <= 3
		SET @trimestre = 1

	ELSE IF @mes BETWEEN 4 AND 6
		SET @trimestre = 2

	ELSE IF @mes BETWEEN 7 AND 9
		SET @trimestre = 3

	ELSE
		SET @trimestre = 4


	INSERT INTO DimensionTiempo
	VALUES(@fechaActual, @diaSemana, @dia, @mes, @año, @trimestre)


	SET @fechaActual += 1
END
GO

EXEC dimensionFecha '01-01-2015', '01-01-2016'
GO

SELECT *
FROM DimensionTiempo
GO

-- Semana mes, Semana año, Temporada, Cuatrimestre, Semestre, Asueto, Horario de verano