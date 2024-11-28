from flask import Flask
import os

app = Flask(__name__)

container_id = os.getenv("HOSTNAME", "Unknown Container")

@app.route("/")
def home():
    return f"Hello, AKS! This is a Python container app. Served by container ID: {container_id}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)