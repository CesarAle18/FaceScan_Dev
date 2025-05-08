from flask import Flask, request, jsonify
import os
import datetime
import pickle
import cv2
import numpy as np
import face_recognition
import base64
import util
from test import test
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)

# Configuración
DB_DIR = './db'
LOG_PATH = './resources/log.txt'
MODEL_DIR = './resources/anti_spoof_models'

# Configuración de la base de datos MySQL
DB_CONFIG = {
    'host': 'localhost',
    'database': 'facial_recognition',
    'user': 'root',
    'password': ''
}

def create_connection():
    """Crea una conexión a la base de datos MySQL"""
    connection = None
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"Error al conectar a MySQL: {e}")
        return None

def initialize_database():
    """Inicializa la base de datos y crea las tablas si no existen"""
    connection = create_connection()
    if not connection:
        return
    
    cursor = None
    try:
        cursor = connection.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(100) UNIQUE NOT NULL,
                face_encoding BLOB NOT NULL,
                face_image MEDIUMBLOB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT,
                action VARCHAR(10) NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        connection.commit()
        print("Base de datos inicializada correctamente.")
    except Error as e:
        print(f"Error al inicializar la base de datos: {e}")
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

# Verificación de directorios
if not os.path.exists(MODEL_DIR):
    os.makedirs(MODEL_DIR)
    raise FileNotFoundError(f"La carpeta {MODEL_DIR} no existe. Por favor, descarga los modelos de anti-spoofing y colócalos en {MODEL_DIR}.")

if not os.path.exists(DB_DIR):
    os.makedirs(DB_DIR)

# Inicializar la base de datos
initialize_database()

def get_user_by_face_encoding(face_encoding):
    """Busca un usuario en la base de datos por su codificación facial"""
    connection = create_connection()
    if not connection:
        return None
    
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id, username, face_encoding FROM users")
        users = cursor.fetchall()
        
        for user in users:
            stored_encoding = pickle.loads(user['face_encoding'])
            results = face_recognition.compare_faces([stored_encoding], face_encoding)
            if results[0]:
                return user
        
        return None
    except Error as e:
        print(f"Error al buscar usuario: {e}")
        return None
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

def log_user_action(user_id, action):
    """Registra una acción de usuario en la base de datos"""
    connection = create_connection()
    if not connection:
        return False
    
    cursor = None
    try:
        cursor = connection.cursor()
        query = "INSERT INTO logs (user_id, action) VALUES (%s, %s)"
        cursor.execute(query, (user_id, action))
        connection.commit()
        return True
    except Error as e:
        print(f"Error al registrar acción: {e}")
        return False
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

def save_user(username, face_encoding, img=None):
    """Guarda un nuevo usuario en la base de datos"""
    connection = create_connection()
    if not connection:
        return False
    
    cursor = None
    try:
        cursor = connection.cursor()
        serialized_encoding = pickle.dumps(face_encoding)
        
        if img is not None:
            _, img_encoded = cv2.imencode('.jpg', img)
            img_bytes = img_encoded.tobytes()
            query = "INSERT INTO users (username, face_encoding, face_image) VALUES (%s, %s, %s)"
            cursor.execute(query, (username, serialized_encoding, img_bytes))
        else:
            query = "INSERT INTO users (username, face_encoding) VALUES (%s, %s)"
            cursor.execute(query, (username, serialized_encoding))
        
        connection.commit()
        return True
    except Error as e:
        print(f"Error al guardar usuario: {e}")
        return False
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

@app.route('/login', methods=['POST'])
def login():
    image_data = request.json.get('image', '')
    try:
        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return jsonify({
                'success': False,
                'message': 'Error al decodificar la imagen.'
            })
        
        height, width = img.shape[:2]
        if width/height != 3/4:
            new_width = int(height * 3/4)
            img = cv2.resize(img, (new_width, height))
        
        label = test(image=img, model_dir=MODEL_DIR, device_id=0)
        if label != 1:
            return jsonify({
                'success': False,
                'message': 'Detección de spoofing. No es un rostro real.'
            })
        
        face_locations = face_recognition.face_locations(img)
        if not face_locations:
            return jsonify({
                'success': False,
                'message': 'No se detectó ningún rostro en la imagen.'
            })
        
        face_encodings = face_recognition.face_encodings(img, face_locations)
        if not face_encodings:
            return jsonify({
                'success': False,
                'message': 'Error al generar la codificación facial.'
            })
        
        face_encoding = face_encodings[0]
        user = get_user_by_face_encoding(face_encoding)
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'Usuario desconocido. Por favor regístrese o intente de nuevo.'
            })
        
        log_user_action(user['id'], 'in')
        return jsonify({
            'success': True,
            'message': f'Bienvenido, {user["username"]}.',
            'name': user["username"]
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        })

@app.route('/logout', methods=['POST'])
def logout():
    image_data = request.json.get('image', '')
    try:
        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return jsonify({
                'success': False,
                'message': 'Error al decodificar la imagen.'
            })
        
        height, width = img.shape[:2]
        if width/height != 3/4:
            new_width = int(height * 3/4)
            img = cv2.resize(img, (new_width, height))
        
        label = test(image=img, model_dir=MODEL_DIR, device_id=0)
        if label != 1:
            return jsonify({
                'success': False,
                'message': 'Detección de spoofing. No es un rostro real.'
            })
        
        face_locations = face_recognition.face_locations(img)
        if not face_locations:
            return jsonify({
                'success': False,
                'message': 'No se detectó ningún rostro en la imagen.'
            })
        
        face_encodings = face_recognition.face_encodings(img, face_locations)
        if not face_encodings:
            return jsonify({
                'success': False,
                'message': 'Error al generar la codificación facial.'
            })
        
        face_encoding = face_encodings[0]
        user = get_user_by_face_encoding(face_encoding)
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'Usuario desconocido. Por favor regístrese o intente de nuevo.'
            })
        
        log_user_action(user['id'], 'out')
        return jsonify({
            'success': True,
            'message': f'Hasta la vista, {user["username"]}.',
            'name': user["username"]
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        })

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    image_data = data.get('image', '')
    username = data.get('username', '')
    
    if not username:
        return jsonify({
            'success': False,
            'message': 'Por favor, proporcione un nombre de usuario.'
        })
    
    try:
        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return jsonify({
                'success': False,
                'message': 'Error al decodificar la imagen.'
            })
        
        face_locations = face_recognition.face_locations(img)
        if not face_locations:
            return jsonify({
                'success': False,
                'message': 'No se detectó ningún rostro en la imagen.'
            })
        
        face_encodings = face_recognition.face_encodings(img, face_locations)
        if not face_encodings:
            return jsonify({
                'success': False,
                'message': 'Error al generar la codificación facial.'
            })
        
        face_encoding = face_encodings[0]
        
        if save_user(username, face_encoding, img):
            return jsonify({
                'success': True,
                'message': 'Usuario registrado exitosamente.',
                'name': username
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Error al guardar el usuario en la base de datos.'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error al registrar usuario: {str(e)}'
        })

@app.route('/users', methods=['GET'])
def get_users():
    """Obtiene la lista de usuarios registrados"""
    connection = create_connection()
    if not connection:
        return jsonify({
            'success': False,
            'message': 'Error al conectar con la base de datos.'
        })
    
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id, username, created_at FROM users")
        users = cursor.fetchall()
        
        for user in users:
            user['created_at'] = user['created_at'].strftime('%Y-%m-%d %H:%M:%S')
        
        return jsonify({
            'success': True,
            'users': users
        })
    except Error as e:
        return jsonify({
            'success': False,
            'message': f'Error al obtener usuarios: {str(e)}'
        })
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

@app.route('/user/<int:user_id>/image', methods=['GET'])
def get_user_image(user_id):
    """Obtiene la imagen de un usuario por su ID"""
    connection = create_connection()
    if not connection:
        return jsonify({
            'success': False,
            'message': 'Error al conectar con la base de datos.'
        })
    
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT face_image FROM users WHERE id = %s", (user_id,))
        result = cursor.fetchone()
        
        if not result or not result['face_image']:
            return jsonify({
                'success': False,
                'message': 'Imagen no encontrada para el usuario.'
            })
        
        image_base64 = base64.b64encode(result['face_image']).decode('utf-8')
        return jsonify({
            'success': True,
            'image': image_base64
        })
    except Error as e:
        return jsonify({
            'success': False,
            'message': f'Error al obtener imagen: {str(e)}'
        })
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

@app.route('/logs', methods=['GET'])
def get_logs():
    """Obtiene el registro de acciones de usuarios"""
    connection = create_connection()
    if not connection:
        return jsonify({
            'success': False,
            'message': 'Error al conectar con la base de datos.'
        })
    
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT l.id, u.username, l.action, l.timestamp 
            FROM logs l
            JOIN users u ON l.user_id = u.id
            ORDER BY l.timestamp DESC
        """)
        logs = cursor.fetchall()
        
        for log in logs:
            log['timestamp'] = log['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
        
        return jsonify({
            'success': True,
            'logs': logs
        })
    except Error as e:
        return jsonify({
            'success': False,
            'message': f'Error al obtener logs: {str(e)}'
        })
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)