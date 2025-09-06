from flask import Flask, Response
import cv2
import threading
import subprocess
import time

app = Flask(__name__)
camera = cv2.VideoCapture(0)  # 0 is usually the default webcam

def generate_frames():
    while True:
        success, frame = camera.read()
        if not success:
            break
        else:
            _, buffer = cv2.imencode('.jpg', frame)
            frame = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

def rtsp_stream():
    time.sleep(5) 
    print("Starting FFmpeg restream (http://localhost:5000/video → rtsp://0.0.0.0:8554/live)")
    command = [
        "ffmpeg",
        "-re",
        "-i", "http://127.0.0.1:5000/video", 
        "-c:v", "libx264",
        "-f", "rtsp",
        "rtsp://0.0.0.0:8554/live"
    ]

    subprocess.run(command)

@app.route('/')
@app.route('/video')
def video():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/test')
def index():
    return '''
    <html>
    <body>
        <h1>Live Camera Test</h1>
        <img src="/">
    </body>
    </html>
    '''

if __name__ == '__main__':
    # threading.Thread(target=rtsp_stream, daemon=True).start()
    app.run(host='0.0.0.0', port=5000)
