import re, requests as std_requests
from flask import Flask, request, jsonify
from collections import Counter

app = Flask(__name__)

OLLAMA_HOST = "http://localhost:11434"
MODELS = ["glm-ocr", "qwen2-vl:2b"]

def call_ollama(model, prompt, img_b64):
    try:
        payload = {
            "model": model, 
            "prompt": prompt, 
            "images": [img_b64], 
            "stream": False
        }
        resp = std_requests.post(f"{OLLAMA_HOST}/api/generate", json=payload, timeout=40)
        if resp.status_code == 200:
            return resp.json().get('response', '').strip()
        return None
    except:
        return None

def solve_digits(img_b64, target_len):
    prompts = [
        f"Read the {target_len} digits from left to right. Only numbers.",
        "Read all numbers and text in this image accurately."
    ]
    
    results = []
    for m in MODELS:
        for p in prompts:
            res = call_ollama(m, p, img_b64)
            if res:
                results.append(res)

    candidates = []
    for res in results:
        clean = "".join(re.findall(r'\d+', res))
        if clean:
            candidates.append(clean)
    
    if not candidates:
        return None

    vote_result = Counter(candidates)
    winner, _ = vote_result.most_common(1)[0]

    for cand in candidates:
        if len(cand) == target_len:
            return cand
            
    return winner

def solve_math(img_b64):
    prompts = [
        "Read the math expression. Return only numbers and operator (e.g. 5+5). No = or ?",
        "Read all text in this image accurately."
    ]
    
    results = []
    for m in MODELS:
        for p in prompts:
            res = call_ollama(m, p, img_b64)
            if res:
                results.append(res)

    candidates = []
    for res in results:
        text = res.lower().replace('x', '*').replace('÷', '/').replace(':', '/')
        
        match = re.search(r'(\d+[\+\-\*/%]+\d*)', text)
        
        if match:
            val = match.group(1).rstrip('+-*/')
            candidates.append(val)
        else:
            fallback = "".join(re.findall(r'[\d\+\-\*/%]', text))
            if fallback:
                candidates.append(fallback)

    if not candidates:
        return None

    return Counter(candidates).most_common(1)[0][0]

@app.route('/solve', methods=['POST'])
def solve():
    try:
        body = request.json
        img_b64 = body.get("image").split(",")[-1]
        method = body.get("method", "text")
        instruct = body.get("instruct", "")

        digit_match = re.search(r'(\d+)digits', instruct.lower()) if instruct else None
        
        if digit_match:
            target_len = int(digit_match.group(1))
            final_data = solve_digits(img_b64, target_len)
        elif method == "math":
            final_data = solve_math(img_b64)
        else:
            final_data = call_ollama("qwen2-vl:2b", "Read all text in this image.", img_b64)
            if final_data:
                final_data = final_data.replace("\n", " ").strip()

        if not final_data:
            return jsonify({"status": "error", "message": "Failed to get solution"}), 500

        return jsonify({
            "status": "success", 
            "data": final_data
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
