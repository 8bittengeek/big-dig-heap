#!/usr/bin/env bash
set -e

# 🧾 Arguments
PROJECT_NAME="$1"
if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 <project-name>"
  exit 1
fi

echo "🚀 Bootstrapping project: $PROJECT_NAME"

# ----------------------------
# 📁 Create Project Structure
# ----------------------------
mkdir -p "$PROJECT_NAME"/{backend,crawler,qortal,qapp}
cd "$PROJECT_NAME"
echo "📂 Created project folders."

# ----------------------------
# 🐍 Python: virtualenv + deps
# ----------------------------
echo "🐍 Setting up Python environment..."
python3 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip
pip install fastapi uvicorn playwright requests pydantic

# Install Playwright browsers
playwright install

echo "✔️ Python environment ready with FastAPI and Playwright!"

# ----------------------------
# 🧠 Backend API Starter
# ----------------------------
cat > backend/api.py <<'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uuid, subprocess, os

app = FastAPI()
jobs = {}

class ArchiveRequest(BaseModel):
    url: str

@app.post("/archive")
def queue_archive(req: ArchiveRequest):
    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "queued", "url": req.url}
    subprocess.Popen(["python", "../crawler/crawler.py", req.url])
    jobs[job_id]["status"] = "started"
    return {"job_id": job_id, "status": "started"}

@app.get("/archive/{job_id}")
def get_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(404, "Job not found")
    return jobs[job_id]
EOF

echo "✔️ Backend API starter created."

# ----------------------------
# 🕷️ Crawler Starter
# ----------------------------
cat > crawler/crawler.py <<'EOF'
from playwright.sync_api import sync_playwright
from urllib.parse import urlparse
import os

OUTPUT="crawler_output"
os.makedirs(OUTPUT, exist_ok=True)

def snapshot(url):
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(url, wait_until="networkidle")
        html = page.content()
        domain = urlparse(url).netloc.replace(".", "_")
        with open(f"{OUTPUT}/{domain}.html", "w") as f:
            f.write(html)
        page.screenshot(path=f"{OUTPUT}/{domain}.png", full_page=True)
        browser.close()

if __name__ == "__main__":
    import sys
    snapshot(sys.argv[1])
EOF

echo "✔️ Crawler starter created."

# ----------------------------
# 🔗 Qortal Bridge Stub
# ----------------------------
cat > qortal/bridge.py <<'EOF'
import requests, base64

QORTAL_API="http://localhost:1235/api"

def publish_json(name, data):
    payload = base64.b64encode(data.encode()).decode()
    body = {
      "requestType": "publishResource",
      "name": name,
      "service": "JSON",
      "resource": payload,
      "feeQNT":"100000"
    }
    return requests.post(QORTAL_API, json=body).json()
EOF

echo "✔️ Qortal bridge stub created."

# ----------------------------
# 📦 Q-App Frontend Base
# ----------------------------
cat > qapp/index.html <<'EOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>$PROJECT_NAME Q-App</title></head>
<body>
<h1>$PROJECT_NAME Archive Q-App</h1>
<form id="archiveForm">
  <input id="urlInput" placeholder="URL to archive" size="40"/>
  <button>Archive!</button>
</form>
<pre id="output"></pre>
<script>
  document.getElementById("archiveForm").onsubmit = async e => {
    e.preventDefault();
    const url = urlInput.value;
    document.getElementById("output").textContent = "Sending…";
    const res = await fetch("/archive", {
      method:"POST", headers:{"Content-Type":"application/json"},
      body: JSON.stringify({url})
    });
    document.getElementById("output").textContent = JSON.stringify(await res.json(),null,2);
  };
</script>
</body></html>
EOF

echo "✔️ Q-App frontend base created."

# ----------------------------
# 📌 Run Scripts Reminder
# ----------------------------
echo "🎉 All done! Your project is ready."
echo ""
echo "📌 To run the backend API:"
echo "   source .venv/bin/activate"
echo "   uvicorn backend.api:app --reload --host 0.0.0.0 --port 8000"
echo ""
echo "📌 Visit http://localhost:8000/docs for FastAPI UI."
echo "📌 Your crawler lives in crawler/crawler.py"
echo "📌 Qortal bridge helper in qortal/bridge.py"
echo "📌 Q-App frontend placeholder at qapp/index.html"
