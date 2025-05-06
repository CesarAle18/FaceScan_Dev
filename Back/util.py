import os
import pickle
import face_recognition
import numpy as np
import cv2

def recognize(img, db_dir):
    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    face_locations = face_recognition.face_locations(rgb_img)
    if not face_locations:
        return 'no_persons_found'
    face_encodings = face_recognition.face_encodings(rgb_img, face_locations)
    if not face_encodings:
        return 'no_persons_found'
    face_encoding = face_encodings[0]
    for filename in os.listdir(db_dir):
        if filename.endswith('.pickle'):
            with open(os.path.join(db_dir, filename), 'rb') as f:
                stored_encoding = pickle.load(f)
            matches = face_recognition.compare_faces([stored_encoding], face_encoding, tolerance=0.6)
            if matches[0]:
                return filename.replace('.pickle', '')
    return 'unknown_person'