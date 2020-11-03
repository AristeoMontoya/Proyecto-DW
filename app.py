from dotenv import load_dotenv
from datetime import datetime
import pyodbc
import os


load_dotenv()

consulta = '''
    INSERT INTO importacion (Id, Movimiento, PaisOrigen, PaisDestino, Año, Fecha, Producto, Transporte, Marca, Importe)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    '''


def obtener_conexion():
    """Los valores necesarios para la cadena de conexión son definidos en el archivo .env"""
    driver = os.getenv("DRIVER")
    server = os.getenv("SERVER")
    database = os.getenv("DATABASE")
    uid = os.getenv("UID")  # Usuario de la base de datos
    pwd = os.getenv("PASS")
    conexion = pyodbc.connect(
        f'DRIVER={driver};SERVER={server};DATABASE={database};UID={uid};PWD={pwd}'
    )
    return conexion


def separar_columnas(linea):
    '''Recibe un String y retora una tupla con los datos separados por comas y sin salto de línea'''
    columnas = linea.replace('\n', '').replace('\'', '') .split(',')
    if len(columnas) == 10:
        columnas[5] = datetime.strptime(columnas[5], '%d/%m/%y')
        return columnas
    else:
        return None


def lectura(ruta):
    '''Lectura por renglón del archivo. Aparentemente la última línea está incompleta'''
    archivo = open(ruta, 'r')
    conexion = obtener_conexion()
    cursor = conexion.cursor()
    for linea in enumerate(archivo):
        columnas = separar_columnas(linea)
        if columnas:
            cursor.execute(consulta, *columnas)
        print(columnas)
    conexion.commit()


if __name__ == '__main__':
    ruta = 'BD_OLAP.TXT'
    lectura(ruta)
