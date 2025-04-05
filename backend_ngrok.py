from flask import Flask, request, jsonify
import PyPDF2
import io
import google.generativeai as genai
import os
from dotenv import load_dotenv
import moviepy as mp
import speech_recognition as sr
from pydub import AudioSegment
import uuid
from flask_cors import CORS
from pyngrok import ngrok

MORSE_CODE_DICT = {
    'A': '._', 'B': '_...', 'C': '_._.', 'D': '_..', 'E': '.', 'F': '.._.',
    'G': '__.', 'H': '....', 'I': '..', 'J': '.___', 'K': '_._', 'L': '._..',
    'M': '__', 'N': '_.', 'O': '___', 'P': '.__.', 'Q': '__._', 'R': '._.',
    'S': '...', 'T': '_', 'U': '.._', 'V': '..._', 'W': '.__', 'X': '_.._',
    'Y': '_.__', 'Z': '__..',
    '0': '_____', '1': '.____', '2': '..___', '3': '...__', '4': '...._',
    '5': '.....', '6': '_....', '7': '__...', '8': '___..', '9': '____.',
    ' ': ' / '
}


load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("models/gemini-1.5-pro-latest")

app = Flask(__name__)
CORS(app)
def text_to_morse(text):
    return ' '.join(MORSE_CODE_DICT.get(char.upper(), '') for char in text) + ''


def ai_simplify(text):
    prompt = (
        "You are a helpful assistant. Summarize the following academic text into a short, simplified version that's easy to understand:\n\n"
        f"{text}\n\n"
        "Keep the output concise and clear."
    )
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        return f"[AI Error] {str(e)}"

@app.route('/morse', methods=['POST'])
def morse_api():
    data = request.get_json()
    input_text = data.get('text', '')
    morse = text_to_morse(input_text)
    print("====================================")
    print(str(morse))
    print("====================================")
    return jsonify({'morse': morse})

@app.route('/', methods=['GET'])
def test_homepage():
    return jsonify({'display': "Hello World!"})

@app.route('/morsifyPDF', methods=['POST'])
def morsify_pdf():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    try:
        # Read PDF text
        reader = PyPDF2.PdfReader(file)
        full_text = ''
        for page in reader.pages:
            full_text += page.extract_text()

        # Simplify text using AI (mock here)
        print(full_text)
        simplified = ai_simplify(full_text)

        # Convert to morse
        morse = text_to_morse(simplified)
        print("====================================")
        print(str(morse))
        print("====================================")
        return jsonify({'morse': morse})

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/convertVideo', methods=['POST'])
def convert_video():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    video_file = request.files['file']
    if video_file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    try:
        # Save video temporarily
        filename = f"temp_{uuid.uuid4()}.mp4"
        video_path = os.path.join("temp", filename)
        os.makedirs("temp", exist_ok=True)
        video_file.save(video_path)

        # Extract audio from video
        clip = mp.VideoFileClip(video_path)
        audio_path = video_path.replace(".mp4", ".wav")
        clip.audio.write_audiofile(audio_path)
        clip.close()

        # Transcribe audio
        recognizer = sr.Recognizer()
        with sr.AudioFile(audio_path) as source:
            audio_data = recognizer.record(source)
            raw_text = recognizer.recognize_google(audio_data)

        # Send text to Gemini for cleanup
        simplified_text = ai_simplify(raw_text)
        morse_code = text_to_morse(simplified_text)
        print(str(morse_code))

        # Clean up temp files
        os.remove(video_path)
        os.remove(audio_path)

        
        return jsonify({
            "morse": morse_code
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # app.run(host="0.0.0.0", port=5000)
    public_url = ngrok.connect(5000)
    print(" * ngrok tunnel:", public_url)
    
    # Start Flask server
    app.run(port=5000)