USE almacen
GO

-- En equipo
-- 1. Tomando el archivo BD_OLAP.TXT realizar las transformaciones requeridas para convertirla en una tabla de un gestor de base de datos relacional. 
-- Crear una tabla de hechos donde modelen una de las actividades del negocio (Importaciones o exportaciones). 
-- OlapCube: Definir el modelo estrella, las jerarquías y genere el cubo y realice la explotación del cubo.

-- 2. Actualizar el almacén de datos (una tabla de hechos) en tiempo real.


-- Esta tabla ya está bien.
CREATE TABLE Operaciones
(
	Id DECIMAL(12) NOT NULL,
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

INSERT INTO Operaciones
	(Id, Movimiento, PaisOrigen, PaisDestino, Año, Fecha, Producto, Transporte, Marca, Importe)
SELECT *
FROM operaciones

-- A esta hay que seguir metiéndole mano.
CREATE TABLE DimensionTiempo
(
	Fecha DATE PRIMARY KEY,
	NombreDia NVARCHAR(9),
	Dia TINYINT,
	Asueto BIT,
	NombreMes NVARCHAR(10),
	Mes TINYINT,
	SemanaAño TINYINT,
	Año SMALLINT,
	HorarioVerano BIT,
	Bimestre TINYINT,
	Trimestre TINYINT,
	Cuatrimestre TINYINT,
	Semestre TINYINT,
	Temporada NVARCHAR(9),
)
GO

-- DROP TABLE DimensionTiempo
-- GO

-- DROP PROCEDURE CrearDimensionFecha
-- GO

-- DELETE FROM DimensionTiempo

CREATE PROCEDURE CrearDimensionFecha
	@fechaActual DATETIME,
	@fechaFinal DATETIME
AS
DECLARE @nombreDia VARCHAR(9), @dia TINYINT, @mes TINYINT, @nombreMes NVARCHAR(10),
@año SMALLINT, @bimestre TINYINT, @trimestre TINYINT, @cuatrimestre TINYINT, @semestre TINYINT,
@asueto BIT, @horarioVerano BIT, @numeroSemana TINYINT, @temporada NVARCHAR(9), @añoVarchar VARCHAR(4)
SET LANGUAGE Spanish
WHILE @fechaActual <= @fechaFinal
BEGIN
	SELECT @dia=DATEPART(day, @fechaActual),
		@nombreMes=DATENAME(month, @fechaActual),
		@mes=DATEPART(month, @fechaActual),
		@año=DATEPART(year, @fechaActual),
		@nombreDia=DATENAME(weekday, @fechaActual),
		@numeroSemana=DATEPART(wk, @fechaActual)


	-- Bimestre
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
			@fechaActual, @nombreDia, @dia, @asueto, @nombreMes , @mes , @numeroSemana, @año,
			@horarioVerano, @bimestre, @trimestre, @cuatrimestre, @semestre, @temporada
		 )

	SET @fechaActual += 1
END
GO

-- Creación de la dimensión tiempo
EXEC CrearDimensionFecha '01-01-2015', '01-01-2025'
GO

-- Seleccionar la dimensión tiempo
SELECT *
FROM DimensionTiempo
GO

-- Verificando los meses
SELECT DISTINCT MONTH(Fecha) AS mes
FROM Operaciones
ORDER BY mes

SELECT *
FROM Operaciones

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
CREATE TABLE HechosImportacion
(
	PaisDestino INT,
	Fecha DATE,
	Producto INT,
	Marca INT,
	ImporteTotal DECIMAL(10),
	FOREIGN KEY(PaisDestino) REFERENCES DimensionPaises(Id),
	FOREIGN KEY(Fecha) REFERENCES DimensionTiempo(Fecha),
	FOREIGN KEY(Producto) REFERENCES DimensionProducto(Id),
	FOREIGN KEY(Marca) REFERENCES DimensionMarca(Id)
)
GO


INSERT INTO HechosImportacion
	(PaisDestino, Fecha, Producto, Marca, ImporteTotal)
SELECT dpais.Id, dtiempo.Fecha, dprod.Id, dmarca.Id, Importe AS ImporteTotal
FROM Operaciones
	JOIN dimensionPaises AS dpais ON  dpais.NombrePais = Operaciones.PaisDestino
	JOIN DimensionTiempo AS dtiempo ON dtiempo.Fecha = Operaciones.Fecha
	JOIN DimensionProducto AS dprod ON dprod.Producto = Operaciones.Producto
	JOIN DimensionMarca AS dmarca ON dmarca.Empresa = Operaciones.Marca
WHERE Movimiento = 'Imports'
GO


SELECT *
FROM hechosImportacion
GO

SELECT *
FROM INFORMATION_SCHEMA.TABLES

-- Dimensión país
CREATE TABLE DimensionPaises
(
	Id INT PRIMARY KEY,
	NombrePais NVARCHAR(50),
	Continente NVARCHAR(50),
	Giro NVARCHAR(30),
	Regimen NVARCHAR(50),
	IdiomaPrincipal NVARCHAR(20),
	Tamaño NVARCHAR(15),
	Poblacion INT,
	PIB BIGINT,
	IndiceDeDesarrollo NVARCHAR(30),
	Moneda NVARCHAR(30)
)
GO


BULK
INSERT DimensionPaises
FROM 'D:\Documentos\Escuela\Semestre 9\Temas selectos de base de datos\Proyecto-DW\DimensionPais.csv'
WITH
(
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	FIRSTROW = 2,
	CODEPAGE = '65001'
)
GO

SELECT *
FROM DimensionPaises

-- Dimensión producto
CREATE TABLE DimensionProducto
(
	Id INT PRIMARY KEY,
	Producto NVARCHAR(50),
	Categoria NVARCHAR(50),
)
GO


BULK
INSERT DimensionProducto
FROM 'D:\Documentos\Escuela\Semestre 9\Temas selectos de base de datos\Proyecto-DW\DimensionProducto.csv'
WITH
(
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	FIRSTROW = 2,
	CODEPAGE = '65001'
)
GO

SELECT *
FROM DimensionProducto
GO

-- Dimensión Marca
CREATE TABLE DimensionMarca
(
	Id INT PRIMARY KEY,
	Empresa NVARCHAR(50),
	Industria NVARCHAR(50),
	FormaLegal NVARCHAR(50),
	Sede NVARCHAR(50),
	ProductoPrincipal NVARCHAR(50),
	Empleados INT
)
GO


BULK
INSERT DimensionMarca
FROM 'D:\Documentos\Escuela\Semestre 9\Temas selectos de base de datos\Proyecto-DW\DimensionMarca.csv'
WITH
(
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	FIRSTROW = 2,
	CODEPAGE = '65001'
)
GO


SELECT *
FROM DimensionMarca
GO
