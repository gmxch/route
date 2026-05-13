from flask import Flask, request, jsonify
import requests as std_requests
import re, base64

app = Flask(__name__)

OLLAMA_HOST = "http://localhost:11434"
OLLAMA_MODEL = "glm-ocr"

@app.route('/solve', methods=['POST'])
def solve():
    try:
        body = request.json
        img_b64 = body.get("image")
        method = body.get("method", "text")
        
        if not img_b64:
            return jsonify({"status": "error", "message": "Missing image data"}), 400

        # --- SET PROMPT ---
        if method == "math":
            prompt = "Read the math expression in this image. Return ONLY the numbers and operator (example: 4*8). Do not solve it."
        elif method == "text":
            prompt = "Read the characters in this image. Return ONLY the text found."
        else:
            prompt = body.get("instruct", "Describe this image.")

        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": [img_b64.split(",")[-1]],
            "stream": False
        }
        
        ollama_resp = std_requests.post(f"{OLLAMA_HOST}/api/generate", json=payload, timeout=60)
        ocr_text = ollama_resp.json().get('response', '').strip()

        return jsonify({
            "status": "success", 
            "data": ocr_text
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
