from flask import Flask, request, jsonify
import os.path
import datetime
import pickle
import cv2
import numpy as np
import face_recognition
import base64
import util
from test import test

app = Flask(__name__)

# Configuración
DB_DIR = './db'
LOG_PATH = './resources/log.txt'
MODEL_DIR = './resources/anti_spoof_models'

if not os.path.exists(MODEL_DIR):
    os.makedirs(MODEL_DIR)
    raise FileNotFoundError(f"La carpeta {MODEL_DIR} no existe. Por favor, descarga los modelos de anti-spoofing y colócalos en {MODEL_DIR}.")

if not os.path.exists(DB_DIR):
    os.mkdir(DB_DIR)

if not os.path.exists(LOG_PATH):
    with open(LOG_PATH, 'w') as f:
        f.write('name,timestamp,action\n')

@app.route('/login', methods=['POST'])
def login():
    image_data = request.json.get('image', '')
    try:
        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        height, width = img.shape[:2]
        if width/height != 3/4:
            new_width = int(height * 3/4)
            img = cv2.resize(img, (new_width, height))
        label = test(image=img, model_dir=MODEL_DIR, device_id=0)
        if label == 1:
            name = util.recognize(img, DB_DIR)
            if name in ['unknown_person', 'no_persons_found']:
                return jsonify({
                    'success': False,
                    'message': 'Usuario desconocido. Por favor regístrese o intente de nuevo.'
                })
            else:
                with open(LOG_PATH, 'a') as f:
                    f.write('{},{},in\n'.format(name, datetime.datetime.now()))
                return jsonify({
                    'success': True,
                    'message': f'Bienvenido, {name}.',
                    'name': name
                })
        else:
            return jsonify({
                'success': False,
                'message': 'Detección de spoofing. No es un rostro real.'
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
        height, width = img.shape[:2]
        if width/height != 3/4:
            new_width = int(height * 3/4)
            img = cv2.resize(img, (new_width, height))
        label = test(image=img, model_dir=MODEL_DIR, device_id=0)
        if label == 1:
            name = util.recognize(img, DB_DIR)
            if name in ['unknown_person', 'no_persons_found']:
                return jsonify({
                    'success': False,
                    'message': 'Usuario desconocido. Por favor regístrese o intente de nuevo.'
                })
            else:
                with open(LOG_PATH, 'a') as f:
                    f.write('{},{},out\n'.format(name, datetime.datetime.now()))
                return jsonify({
                    'success': True,
                    'message': f'Hasta la vista, {name}.',
                    'name': name
                })
        else:
            return jsonify({
                'success': False,
                'message': 'Detección de spoofing. No es un rostro real.'
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
        face_locations = face_recognition.face_locations(img)
        if not face_locations:
            return jsonify({
                'success': False,
                'message': 'No se detectó ningún rostro en la imagen.'
            })
        embeddings = face_recognition.face_encodings(img)[0]
        with open(os.path.join(DB_DIR, f'{username}.pickle'), 'wb') as file:
            pickle.dump(embeddings, file)
        return jsonify({
            'success': True,
            'message': 'Usuario registrado exitosamente.',
            'name': username
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error al registrar usuario: {str(e)}'
        })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)