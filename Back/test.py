# -*- coding: utf-8 -*-
# @Time : 20-6-9 下午3:06
# @Author : zhuying
# @Company : Minivision
# @File : test.py
# @Software : PyCharm

import os
import cv2
import numpy as np
import warnings
import time

from src.anti_spoof_predict import AntiSpoofPredict
from src.generate_patches import CropImage
from src.utility import parse_model_name
warnings.filterwarnings('ignore')

def check_image(image):
    height, width, channel = image.shape
    if width/height != 3/4:
        print("Image is not appropriate!!!\nHeight/Width should be 4/3.")
        return False
    else:
        return True

def test(image, model_dir, device_id):
    result = check_image(image)
    if result is False:
        return 0
    model_test = AntiSpoofPredict(device_id)
    image_cropper = CropImage()
    image_bbox = model_test.get_bbox(image)
    if image_bbox is None or image_bbox[2] <= 0 or image_bbox[3] <= 0:
        return 0
    prediction = np.zeros((1, 3))
    test_speed = 0
    for model_name in os.listdir(model_dir):
        h_input, w_input, model_type, scale = parse_model_name(model_name)
        param = {
            "org_img": image,
            "bbox": image_bbox,
            "scale": scale,
            "out_w": w_input,
            "out_h": h_input,
            "crop": True,
        }
        if scale is None:
            param["crop"] = False
        img = image_cropper.crop(**param)
        start = time.time()
        prediction += model_test.predict(img, os.path.join(model_dir, model_name))
        test_speed += time.time() - start
    label = np.argmax(prediction)
    value = prediction[0][label] / 2
    print("Prediction cost {:.2f} s".format(test_speed))
    print("Score for label {}: {:.2f}".format(label, value))
    return 1 if label == 1 else 0

if __name__ == "__main__":
    import argparse
    desc = "test"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("--device_id", type=int, default=0, help="which gpu id, [0/1/2/3]")
    parser.add_argument("--model_dir", type=str, default="./resources/anti_spoof_models", help="model_lib used to test")
    parser.add_argument("--image_name", type=str, default="image_F1.jpg", help="image used to test")
    args = parser.parse_args()
    SAMPLE_IMAGE_PATH = "./images/sample/"
    image = cv2.imread(SAMPLE_IMAGE_PATH + args.image_name)
    label = test(image, args.model_dir, args.device_id)
    print(f"Resultado: {'Real Face' if label == 1 else 'Fake Face'}")