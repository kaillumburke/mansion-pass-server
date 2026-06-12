#!/usr/bin/env python3
"""
Mansion Nightclub — Apple Wallet Pass Signing Service
Run: python3 sign_pass.py
Port: 5050
"""

import base64
import hashlib
import json
import os
import struct
import subprocess
import tempfile
import zipfile
from flask import Flask, request, jsonify, send_file
import io

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WWDR_PATH = os.path.join(BASE_DIR, "AppleWWDRG4.pem")

# P12 cert and password are loaded from env vars in production,
# falling back to local files for development.
_P12_B64 = os.environ.get("PASS_P12_BASE64")
P12_PASSWORD = os.environ.get("PASS_P12_PASSWORD", "mansion2026")

def _get_p12_bytes() -> bytes:
    if _P12_B64:
        return base64.b64decode(_P12_B64)
    local = os.path.join(BASE_DIR, "MansionPass.p12")
    with open(local, "rb") as f:
        return f.read()
PASS_TYPE_ID = "pass.ShareStudio.MansionNightclub"
TEAM_ID = "4V275QTAVK"


def build_pass_json(ticket: dict) -> dict:
    from datetime import datetime
    # Format event date nicely if available
    created = ticket.get("createdAt", "")
    date_str = ""
    try:
        dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
        date_str = dt.strftime("%-d %b").upper()
    except Exception:
        date_str = ""

    return {
        "formatVersion": 1,
        "passTypeIdentifier": PASS_TYPE_ID,
        "serialNumber": ticket["id"],
        "teamIdentifier": TEAM_ID,
        "organizationName": "Mansion Nightclub",
        "description": ticket.get("eventName", "Mansion Nightclub"),
        "foregroundColor": "rgb(255, 255, 255)",
        "backgroundColor": "rgb(0, 0, 0)",
        "labelColor": "rgb(212, 175, 55)",
        "logoText": "",
        "eventTicket": {
            "headerFields": [
                {
                    "key": "date",
                    "label": "DATE",
                    "value": date_str
                }
            ],
            "primaryFields": [
                {
                    "key": "event",
                    "label": "EVENT",
                    "value": ticket.get("eventName", "MANSION NIGHTCLUB")
                }
            ],
            "secondaryFields": [
                {
                    "key": "tier",
                    "label": "TICKET TYPE",
                    "value": ticket.get("tierName", "General Admission").upper()
                },
                {
                    "key": "holder",
                    "label": "NAME",
                    "value": ticket.get("userName", "Guest").upper(),
                    "textAlignment": "PKTextAlignmentRight"
                }
            ],
            "auxiliaryFields": [
                {
                    "key": "venue",
                    "label": "VENUE",
                    "value": "MANSION NIGHTCLUB"
                },
                {
                    "key": "status",
                    "label": "STATUS",
                    "value": ticket.get("status", "valid").upper(),
                    "textAlignment": "PKTextAlignmentRight"
                }
            ],
            "backFields": [
                {
                    "key": "ticketId",
                    "label": "TICKET ID",
                    "value": ticket.get("id", "")[:8].upper()
                },
                {
                    "key": "orderId",
                    "label": "ORDER ID",
                    "value": ticket.get("orderId", "")[:8].upper()
                },
                {
                    "key": "price",
                    "label": "PRICE PAID",
                    "value": "£{:.2f}".format(ticket.get("tierPriceInPence", 0) / 100)
                },
                {
                    "key": "qr",
                    "label": "QR CODE",
                    "value": ticket.get("qrCode", "")
                }
            ]
        },
        "barcodes": [
            {
                "message": ticket.get("qrCode", ""),
                "format": "PKBarcodeFormatQR",
                "messageEncoding": "iso-8859-1",
                "altText": ticket.get("qrCode", "")
            }
        ]
    }


def create_manifest(files: dict) -> dict:
    manifest = {}
    for name, data in files.items():
        manifest[name] = hashlib.sha1(data).hexdigest()
    return manifest


def sign_manifest(manifest_data: bytes) -> bytes:
    """Sign the manifest using OpenSSL SMIME."""
    with tempfile.TemporaryDirectory() as tmp:
        manifest_path = os.path.join(tmp, "manifest.json")
        sig_path = os.path.join(tmp, "signature")
        cert_path = os.path.join(tmp, "cert.pem")
        key_path = os.path.join(tmp, "key.pem")
        p12_path = os.path.join(tmp, "pass.p12")

        with open(p12_path, "wb") as f:
            f.write(_get_p12_bytes())

        # Extract cert and key from p12
        r1 = subprocess.run([
            "openssl", "pkcs12", "-in", p12_path,
            "-clcerts", "-nokeys", "-out", cert_path,
            "-passin", f"pass:{P12_PASSWORD}", "-legacy"
        ], capture_output=True)
        if r1.returncode != 0:
            # try without -legacy (older openssl)
            r1 = subprocess.run([
                "openssl", "pkcs12", "-in", p12_path,
                "-clcerts", "-nokeys", "-out", cert_path,
                "-passin", f"pass:{P12_PASSWORD}"
            ], capture_output=True)
        if r1.returncode != 0:
            raise RuntimeError(f"cert extract failed: {r1.stderr.decode()}")

        r2 = subprocess.run([
            "openssl", "pkcs12", "-in", p12_path,
            "-nocerts", "-nodes", "-out", key_path,
            "-passin", f"pass:{P12_PASSWORD}", "-legacy"
        ], capture_output=True)
        if r2.returncode != 0:
            r2 = subprocess.run([
                "openssl", "pkcs12", "-in", p12_path,
                "-nocerts", "-nodes", "-out", key_path,
                "-passin", f"pass:{P12_PASSWORD}"
            ], capture_output=True)
        if r2.returncode != 0:
            raise RuntimeError(f"key extract failed: {r2.stderr.decode()}")

        with open(manifest_path, "wb") as f:
            f.write(manifest_data)

        subprocess.run([
            "openssl", "smime", "-binary", "-sign",
            "-certfile", WWDR_PATH,
            "-signer", cert_path,
            "-inkey", key_path,
            "-in", manifest_path,
            "-out", sig_path,
            "-outform", "DER"
        ], check=True, capture_output=True)

        with open(sig_path, "rb") as f:
            return f.read()


def make_placeholder_png(width=300, height=100, color=(0, 0, 0)) -> bytes:
    """Create a minimal valid PNG."""
    import zlib
    def write_chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)

    raw = b""
    for _ in range(height):
        raw += b"\x00"
        for _ in range(width):
            raw += bytes(color)

    png = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png += write_chunk(b"IHDR", ihdr_data)
    png += write_chunk(b"IDAT", zlib.compress(raw))
    png += write_chunk(b"IEND", b"")
    return png


def _load_image(name: str) -> bytes:
    path = os.path.join(BASE_DIR, "images", name)
    if os.path.exists(path):
        with open(path, "rb") as f:
            return f.read()
    # fallback to placeholder
    size = 29 if "icon" in name else (50 if "logo" in name and "@2x" not in name and "@3x" not in name else 100)
    return make_placeholder_png(size, size)


def build_pkpass(ticket: dict) -> bytes:
    pass_json = build_pass_json(ticket)
    pass_bytes = json.dumps(pass_json, indent=2).encode("utf-8")

    files = {
        "pass.json":          pass_bytes,
        "icon.png":           _load_image("icon.png"),
        "icon@2x.png":        _load_image("icon@2x.png"),
        "icon@3x.png":        _load_image("icon@3x.png"),
        "logo.png":           _load_image("logo.png"),
        "logo@2x.png":        _load_image("logo@2x.png"),
        "logo@3x.png":        _load_image("logo@3x.png"),
        "background.png":     _load_image("background.png"),
        "background@2x.png":  _load_image("background@2x.png"),
        "background@3x.png":  _load_image("background@3x.png"),
        "thumbnail.png":      _load_image("thumbnail.png"),
        "thumbnail@2x.png":   _load_image("thumbnail@2x.png"),
        "thumbnail@3x.png":   _load_image("thumbnail@3x.png"),
    }

    manifest = create_manifest(files)
    manifest_bytes = json.dumps(manifest, indent=2).encode("utf-8")
    signature = sign_manifest(manifest_bytes)

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for name, data in files.items():
            zf.writestr(name, data)
        zf.writestr("manifest.json", manifest_bytes)
        zf.writestr("signature", signature)

    return buf.getvalue()


@app.route("/pass", methods=["POST"])
def generate_pass():
    ticket = request.get_json()
    if not ticket:
        return jsonify({"error": "Missing ticket data"}), 400
    try:
        pkpass_bytes = build_pkpass(ticket)
        return send_file(
            io.BytesIO(pkpass_bytes),
            mimetype="application/vnd.apple.pkpass",
            as_attachment=True,
            download_name=f"mansion-{ticket.get('id','ticket')[:8]}.pkpass"
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health")
def health():
    return jsonify({"status": "ok", "passTypeId": PASS_TYPE_ID})


if __name__ == "__main__":
    print("🎫 Mansion Pass Signing Service running on http://localhost:5050")
    app.run(host="0.0.0.0", port=5050, debug=False)
