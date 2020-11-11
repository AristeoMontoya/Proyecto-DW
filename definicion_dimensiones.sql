USE almacen
GO

-- Pendientes:
-- 1. Enriquecer la dimensión fecha
-- 1.1. Agregar semestre
-- 1.2. Agregar cuatrimestre
-- 1.3. Agregar días de asueto
-- 1.4. Agregar número de semana
-- 1.5. Agregar temporada
-- 2. Extraer los datos del archivo OLTP.
-- 3. Crear la tabla de hechos.
-- 3.1. Modelar importaciones.
-- 3.2. Modelar exportaciones.
-- 4. Crear otras dimensiones supongo xd.
-- 5. Descubrir como se usa OlapCube.

-- En equipo
-- 1. Tomando el archivo BD_OLAP.TXT realizar las transformaciones requeridas para convertirla en una tabla de un gestor de base de datos relacional. 
-- Crear una tabla de hechos donde modelen una de las actividades del negocio (Importaciones o exportaciones). 
-- OlapCube: Definir el modelo estrella, las jerarquías y genere el cubo y realice la explotación del cubo.

-- 2. Actualizar el almacén de datos (una tabla de hechos) en tiempo real.


-- Esta tabla ya está bien.
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


-- A esta hay que seguir metiéndole mano.
CREATE TABLE DimensionTiempo
(
	fecha DATE PRIMARY KEY,
	diaSemana NVARCHAR(9),
	dia TINYINT,
	asueto BIT,
	nombreMes NVARCHAR(10),
	mes TINYINT,
	semanaAño TINYINT,
	año SMALLINT,
	horarioVerano BIT,
	bimestre TINYINT,
	trimestre TINYINT,
	cuatrimestre TINYINT,
	semestre TINYINT,
	temporada NVARCHAR(9),
)
GO

DROP TABLE DimensionTiempo
GO

DROP PROCEDURE crearDimensionFecha
GO

-- DELETE FROM DimensionTiempo

CREATE PROCEDURE crearDimensionFecha
	@fechaActual DATETIME,
	@fechaFinal DATETIME
AS
DECLARE @diaSemana VARCHAR(9), @dia TINYINT, @mes TINYINT, @nombreMes NVARCHAR(10),
@año SMALLINT, @bimestre TINYINT, @trimestre TINYINT, @cuatrimestre TINYINT, @semestre TINYINT,
@asueto BIT, @horarioVerano BIT, @numeroSemana TINYINT, @temporada NVARCHAR(9), @añoVarchar VARCHAR(4)
SET LANGUAGE Spanish
WHILE @fechaActual <= @fechaFinal
BEGIN
	SELECT @dia=DATEPART(day, @fechaActual),
		@nombreMes=DATENAME(month, @fechaActual),
		@mes=DATEPART(month, @fechaActual),
		@año=DATEPART(year, @fechaActual),
		@diaSemana=DATENAME(weekday, @fechaActual),
		@numeroSemana=DATEPART(wk, @fechaActual)


	-- Trimestre
	IF @mes <= 2
		SET @bimestre = 1

	ELSE IF @mes BETWEEN 3 AND 4
		SET @bimestre = 2

	ELSE IF @mes BETWEEN 5 AND 6
		SET @bimestre = 3

	ELSE IF @mes BETWEEN 7 AND 8
		SET @bimestre = 4

	ELSE IF @mes BETWEEN 9 AND 10
		SET @bimestre = 5

	ELSE
		SET @bimestre = 6


	-- Trimestre
	IF @mes <= 3
		SET @trimestre = 1

	ELSE IF @mes BETWEEN 4 AND 6
		SET @trimestre = 2

	ELSE IF @mes BETWEEN 7 AND 9
		SET @trimestre = 3

	ELSE
		SET @trimestre = 4


	-- Cuatrimestre
	IF @mes <= 4
		SET @cuatrimestre = 1

	ELSE IF @mes BETWEEN 5 AND 8
		SET @cuatrimestre = 2

	ELSE
		SET @cuatrimestre = 3


	-- Semestre
	IF @mes <= 6
		SET @semestre = 1

	ELSE
		SET @semestre = 2


	-- Temporada
	SET @añoVarchar = CAST(@año AS VARCHAR(4))

	IF @fechaActual BETWEEN @añoVarchar + '-20-03' AND @añoVarchar + '-19-06'
		SET @temporada = 'Primavera'

	ELSE IF @fechaActual BETWEEN @añoVarchar + '-20-06' AND @añoVarchar + '-21-09'
		SET @temporada = 'Verano'

	ELSE IF @fechaActual BETWEEN @añoVarchar + '-22-09' AND @añoVarchar + '-20-12'
		SET @temporada = 'Otoño'
	
	ELSE
		SET @temporada = 'Invierno'


	-- Horario de verano
	IF @fechaActual BETWEEN @añoVarchar + '-05-04' AND @añoVarchar + '-25-10'
		SET @horarioVerano = 1
	ELSE 
		SET @horarioVerano = 0

	-- Días de asueto
	IF @fechaActual = @añoVarchar + '-01-01'
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-03-02' 
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-16-03' 
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-01-05' 
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-16-09' 
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-16-11' 
		SET @asueto = 1

	ELSE IF @fechaActual = @añoVarchar + '-25-12' 
		SET @asueto = 1

	ELSE 
		SET @asueto = 0

	INSERT INTO DimensionTiempo
	VALUES(
			@fechaActual, @diaSemana, @dia, @asueto, @nombreMes , @mes , @numeroSemana, @año,
			@horarioVerano, @bimestre, @trimestre, @cuatrimestre, @semestre, @temporada
		 )

	SET @fechaActual += 1
END
GO

-- Creación de la dimensión tiempo
EXEC crearDimensionFecha '01-01-2015', '01-01-2025'
GO

-- Seleccionar la dimensión tiempo
SELECT *
FROM DimensionTiempo
GO

-- Verificando los meses
SELECT count(MONTH(Fecha)) AS mes
FROM Importacion
GROUP BY MONTH(Fecha)

SELECT *
FROM Importacion

/*
TABLA DE HECHOS: IMPORTACIÓN
Movimiento
PaisOrigen
PaisDestino
Año
Fecha
Producto
Transporte
Marca
Importe (En millones)
*/
SELECT Movimiento, PaisOrigen, PaisDestino, Año, Fecha, Producto, Transporte, Marca, (Importe / 1000000) AS Importe
INTO hechosImportacion
FROM Importacion
WHERE Movimiento = 'Imports'

SELECT *
FROM hechosImportacion

/*
TABLA DE HECHOS: EXPORTACIÓN
Movimiento
PaisOrigen
PaisDestino
Año
Fecha
Producto
Transporte
Marca
Importe (En millones)
*/
SELECT Movimiento, PaisOrigen, PaisDestino, Año, Fecha, Producto, Transporte, Marca, (Importe / 1000000) AS Importe
INTO hechosExportacion
FROM Importacion
WHERE Movimiento = 'Exports'

SELECT *
FROM hechosExportacion

-- Por categoría
SELECT DISTINCT Producto 
INTO dimensionProducto
FROM Importacion

SELECT * from dimensionProducto

-- Por país
SELECT PaisOrigen
INTO dimensionPais
FROM 
(SELECT DISTINCT PaisOrigen FROM Importacion
UNION
SELECT DISTINCT PaisDestino FROM Importacion) as Paises

SELECT * FROM dimensionPais

-- Por marca
SELECT DISTINCT Marca 
INTO dimensionMarca
FROM Importacion

SELECT * FROM dimensionMarca

-- Por transporte
SELECT DISTINCT Transporte
INTO dimensionTransporte
FROM Importacion

SELECT * FROM dimensionTransporte