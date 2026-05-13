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

        if method == "math":
            prompt = "Read and solve this math expression. Return ONLY the final numeric answer."
        elif method == "text":
            prompt = "Read the text in this image. Return ONLY the text found."
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

        if method == "math":
            ocr_numbers = re.findall(r'\d+', ocr_text)
            ans = ocr_numbers[0] if ocr_numbers else None
            
            expr_match = re.search(r'(\d+)\s*[\+\-\*x×]\s*(\d+)', ocr_text)
            if expr_match:
                a, b = int(expr_match.group(1)), int(expr_match.group(2))
                if '+' in ocr_text: ans = str(a + b)
                elif '-' in ocr_text: ans = str(a - b)
                else: ans = str(a * b)
            return jsonify({"status": "success", "data": ans})

        return jsonify({"status": "success", "data": ocr_text})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
