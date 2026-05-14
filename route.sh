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
        instruct_manual = body.get("instruct")
        
        if not img_b64:
            return jsonify({"status": "error", "message": "Missing image data"}), 400

        prompt = ""
        
        if instruct_manual:
            digit_match = re.search(r'(\d+)digits', instruct_manual.lower())
            
            if digit_match:
                n = digit_match.group(1)
                # Tambahkan 'from left to right' untuk memaksa urutan horizontal
                prompt = f"Read the {n} digits in this image from left to right. Output only the numbers without spaces, text, or newlines."
            else:
                prompt = instruct_manual

        if not prompt:
            if method == "math":
                prompt = "Read the math expression in this image. Return ONLY the numbers and operator (example: 4*8). Do not solve it."
            elif method == "text":
                prompt = "Read the characters in this image. Return ONLY the text found."
            else:
                prompt = "Describe this image."

        clean_b64 = img_b64.split(",")[-1] if "," in img_b64 else img_b64

        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": [clean_b64],
            "stream": False
        }
        
        ollama_resp = std_requests.post(f"{OLLAMA_HOST}/api/generate", json=payload, timeout=60)
        
        if ollama_resp.status_code != 200:
            return jsonify({"status": "error", "message": f"Ollama Error: {ollama_resp.text}"}), 500
            
        ocr_text = ollama_resp.json().get('response', '').strip()

        if instruct_manual and "digits" in instruct_manual.lower():
            ocr_text = "".join(ocr_text.split())

        return jsonify({
            "status": "success", 
            "data": ocr_text
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
