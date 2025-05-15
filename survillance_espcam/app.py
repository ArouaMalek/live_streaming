from flask import Flask, Response, request
import cv2
import numpy as np
import time

app = Flask(__name__)

latest_frame = None
last_frame_time = 0
FRAME_TIMEOUT = 5  # 5 secondes avant de considérer la caméra déconnectée

@app.route('/upload', methods=['POST'])
def upload_image():
    global latest_frame, last_frame_time
    try:
        file = request.files['image'].read()
        nparr = np.frombuffer(file, np.uint8)
        latest_frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if latest_frame is None:
            return "Erreur : Image invalide", 400
        last_frame_time = time.time()
        return "Image reçue", 200
    except Exception as e:
        return f"Erreur : {str(e)}", 400

def generate_frames():
    global latest_frame, last_frame_time
    while True:
        try:
            if latest_frame is not None and (time.time() - last_frame_time) < FRAME_TIMEOUT:
                ret, buffer = cv2.imencode('.jpg', latest_frame, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
                if not ret:
                    continue
                frame = buffer.tobytes()
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n'
                       b'Content-Length: ' + str(len(frame)).encode() + b'\r\n\r\n'
                       + frame + b'\r\n')
            else:
                # Pas de flux si la caméra est déconnectée
                time.sleep(0.1)
                continue
            time.sleep(0.05)  # 20 FPS max pour fluidité
        except Exception as e:
            print(f"Erreur dans generate_frames : {str(e)}")
            time.sleep(1)

@app.route('/video_feed')
def video_feed():
    return Response(
        generate_frames(),
        mimetype='multipart/x-mixed-replace; boundary=frame',
        headers={
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
        }
    )

@app.route('/status')
def status():
    global last_frame_time
    if (time.time() - last_frame_time) < FRAME_TIMEOUT:
        return "Caméra en ligne", 200
    return "Caméra hors ligne", 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)