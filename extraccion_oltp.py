from dotenv import load_dotenv
from datetime import datetime
import pyodbc
import os


consulta = '''
    INSERT INTO importacion (Id, Movimiento, PaisOrigen, PaisDestino, Año, Fecha, Producto, Transporte, Marca, Importe)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    '''


def obtener_conexion():
    """Los valores necesarios para la cadena de conexión son definidos en el archivo .env"""
    connection_string = os.getenv("CONNECTION_STRING")
    print(connection_string)
    conexion = pyodbc.connect(connection_string)
    return conexion


def separar_columnas(linea: str) -> list:
    '''Recibe un String y retora una tupla con los datos separados por comas y sin salto de línea'''
    columnas = linea.replace('\n', '').replace('\'', '') .split(',')
    if len(columnas) == 10:
        columnas[5] = datetime.strptime(columnas[5], '%d/%m/%y')
        return columnas
    else:
        return None


def lectura(ruta: str):
    '''Lectura por renglón del archivo. Aparentemente la última línea está incompleta'''
    archivo = open(ruta, 'r')
    conexion = obtener_conexion()
    # cursor = conexion.cursor()
    for linea in archivo:
        columnas = separar_columnas(linea)
        # if columnas:
            # cursor.execute(consulta, *columnas)
        print(columnas)
    # conexion.commit()


if __name__ == '__main__':
    load_dotenv()
    ruta = 'BD_OLAP.TXT'
    lectura(ruta)
