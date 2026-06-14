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
import stripe

stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")

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

    def parse_date(val):
        if not val:
            return None
        try:
            if isinstance(val, dict) and "_seconds" in val:
                return datetime.utcfromtimestamp(val["_seconds"])
            return datetime.fromisoformat(str(val).replace("Z", "+00:00"))
        except Exception:
            return None

    event_dt = parse_date(ticket.get("eventDate")) or parse_date(ticket.get("createdAt"))
    date_str = event_dt.strftime("%-d %b").upper() if event_dt else "SAT"
    time_str = event_dt.strftime("%-I:%M %p") if event_dt else "10:00 PM"
    name = (ticket.get("userName") or "").strip().upper() or "GUEST"

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
        "logoText": "MANSION",
        "eventTicket": {
            "headerFields": [
                {
                    "key": "date",
                    "label": "DATE",
                    "value": date_str
                },
                {
                    "key": "time",
                    "label": "DOORS",
                    "value": time_str
                }
            ],
            "primaryFields": [
                {
                    "key": "event",
                    "label": "EVENT",
                    "value": ticket.get("eventName", "MANSION NIGHTCLUB").upper()
                }
            ],
            "secondaryFields": [
                {
                    "key": "tier",
                    "label": "TICKET",
                    "value": ticket.get("tierName", "General Admission").upper()
                },
                {
                    "key": "holder",
                    "label": "NAME",
                    "value": name,
                    "textAlignment": "PKTextAlignmentRight"
                }
            ],
            "auxiliaryFields": [
                {
                    "key": "venue",
                    "label": "VENUE",
                    "value": "MANSION NIGHTCLUB, LIVERPOOL"
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
                    "key": "terms",
                    "label": "TERMS",
                    "value": "This ticket is non-transferable. Valid ID required. Mansion Nightclub reserves the right to refuse entry."
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
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_pass = os.environ.get("SMTP_PASS", "")
    return jsonify({
        "status": "ok",
        "passTypeId": PASS_TYPE_ID,
        "smtp_configured": bool(smtp_user and smtp_pass),
        "smtp_user": smtp_user if smtp_user else "NOT SET",
    })


@app.route("/guestlist", methods=["POST"])
def guestlist_pass():
    """Generate pass AND email it in one request — faster than two round trips."""
    import smtplib, threading
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.mime.base import MIMEBase
    from email import encoders

    ticket = request.get_json()
    if not ticket:
        return jsonify({"error": "Missing ticket data"}), 400

    to_email = ticket.get("userEmail", "")
    name = ticket.get("userName", "Guest")
    event_name = ticket.get("eventName", "Mansion Nightclub")

    if not to_email:
        return jsonify({"error": "Missing userEmail"}), 400

    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_pass = os.environ.get("SMTP_PASS", "")
    if not smtp_user or not smtp_pass:
        return jsonify({"error": "Email not configured"}), 500

    try:
        pkpass_bytes = build_pkpass(ticket)
    except Exception as e:
        return jsonify({"error": f"Pass generation failed: {e}"}), 500

    def send_email():
        msg = MIMEMultipart()
        msg["From"] = f"Mansion Nightclub <{smtp_user}>"
        msg["To"] = to_email
        msg["Subject"] = f"You're on the guestlist — {event_name}"
        html = f"""
        <div style="background:#000;color:#fff;font-family:sans-serif;padding:40px;max-width:500px;margin:0 auto;">
          <h1 style="color:#d4af37;letter-spacing:4px;font-size:24px;">MANSION</h1>
          <h2 style="color:#fff;margin-top:0;">You're on the guestlist</h2>
          <p style="color:#aaa;">Hi {name}, your pass for <strong style="color:#fff;">{event_name}</strong> is attached.</p>
          <p style="color:#aaa;">Open the .pkpass file on your iPhone to add it to Apple Wallet.</p>
          <p style="color:#555;font-size:12px;">Show your QR code at the door. ID required. 18+.</p>
        </div>
        """
        msg.attach(MIMEText(html, "html"))
        part = MIMEBase("application", "vnd.apple.pkpass")
        part.set_payload(pkpass_bytes)
        encoders.encode_base64(part)
        part.add_header("Content-Disposition", "attachment", filename="mansion-guestlist.pkpass")
        msg.attach(part)
        try:
            with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as server:
                server.starttls()
                server.login(smtp_user, smtp_pass)
                server.sendmail(smtp_user, to_email, msg.as_string())
        except Exception as ex:
            print(f"❌ Email failed: {ex}")

    resend_key = os.environ.get("RESEND_API_KEY", "")
    if not resend_key:
        return jsonify({"error": "RESEND_API_KEY not set"}), 500

    html = f"""
    <div style="background:#000;color:#fff;font-family:sans-serif;padding:40px;max-width:500px;margin:0 auto;">
      <h1 style="color:#d4af37;letter-spacing:4px;font-size:24px;">MANSION</h1>
      <h2 style="color:#fff;margin-top:0;">You're on the guestlist</h2>
      <p style="color:#aaa;">Hi {name}, your pass for <strong style="color:#fff;">{event_name}</strong> is attached.</p>
      <p style="color:#aaa;">Open the .pkpass file on your iPhone to add it to Apple Wallet.</p>
      <p style="color:#555;font-size:12px;">Show your QR code at the door. ID required. 18+.</p>
    </div>
    """

    import urllib.request as _urllib
    import json as _json

    attachment_b64 = base64.b64encode(pkpass_bytes).decode("utf-8")
    payload_out = _json.dumps({
        "from": "Mansion Nightclub <hello@sharecollective.co.uk>",
        "to": [to_email],
        "subject": f"You're on the guestlist — {event_name}",
        "html": html,
        "attachments": [{
            "filename": "mansion-guestlist.pkpass",
            "content": attachment_b64
        }]
    }).encode("utf-8")

    req_out = _urllib.Request(
        "https://api.resend.com/emails",
        data=payload_out,
        headers={
            "Authorization": f"Bearer {resend_key}",
            "Content-Type": "application/json"
        }
    )
    try:
        with _urllib.urlopen(req_out, timeout=20) as resp:
            result = _json.loads(resp.read())
            return jsonify({"status": "sent", "to": to_email, "id": result.get("id")})
    except Exception as ex:
        return jsonify({"error": str(ex)}), 500


@app.route("/notification-icon.png")
def notification_icon():
    img_bytes = _load_image("icon@3x.png")
    return send_file(io.BytesIO(img_bytes), mimetype="image/png")


@app.route("/create-payment-intent", methods=["POST"])
def create_payment_intent():
    """Create a Stripe PaymentIntent for ticket purchase."""
    if not stripe.api_key:
        return jsonify({"error": "Stripe not configured"}), 500

    data = request.get_json()
    if not data:
        return jsonify({"error": "Missing request body"}), 400

    amount = data.get("amountInPence")
    event_id = data.get("eventId", "")
    event_name = data.get("eventName", "Mansion Nightclub")
    tier_name = data.get("tierName", "General Admission")
    user_email = data.get("userEmail", "")
    quantity = data.get("quantity", 1)

    if not amount or amount <= 0:
        return jsonify({"error": "Invalid amount"}), 400

    try:
        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency="gbp",
            automatic_payment_methods={"enabled": True},
            metadata={
                "eventId": event_id,
                "eventName": event_name,
                "tierName": tier_name,
                "userEmail": user_email,
                "quantity": str(quantity),
            },
            receipt_email=user_email if user_email else None,
        )
        return jsonify({
            "clientSecret": intent.client_secret,
            "paymentIntentId": intent.id,
        })
    except stripe.error.StripeError as e:
        return jsonify({"error": str(e)}), 400


@app.route("/stripe-webhook", methods=["POST"])
def stripe_webhook():
    """Handle Stripe webhook — on payment_intent.succeeded generate and email the ticket."""
    import urllib.request as _urllib
    import json as _json

    webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET", "")
    payload = request.get_data()
    sig_header = request.headers.get("Stripe-Signature", "")

    if webhook_secret:
        try:
            event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
        except stripe.error.SignatureVerificationError:
            return jsonify({"error": "Invalid signature"}), 400
    else:
        event = request.get_json()

    if event["type"] == "payment_intent.succeeded":
        intent = event["data"]["object"]
        meta = intent.get("metadata", {})
        user_email = meta.get("userEmail", "")
        event_name = meta.get("eventName", "Mansion Nightclub")
        tier_name = meta.get("tierName", "General Admission")
        event_id = meta.get("eventId", "")
        quantity = int(meta.get("quantity", 1))
        amount = intent.get("amount", 0)

        import uuid, datetime
        resend_key = os.environ.get("RESEND_API_KEY", "")

        for i in range(quantity):
            ticket_id = str(uuid.uuid4())
            qr_code = f"MNS-{ticket_id[:8].upper()}"
            ticket = {
                "id": ticket_id,
                "orderId": intent["id"],
                "userId": "",
                "userEmail": user_email,
                "userName": user_email.split("@")[0].title(),
                "eventId": event_id,
                "eventName": event_name,
                "tierId": tier_name.lower().replace(" ", "-"),
                "tierName": tier_name,
                "tierPriceInPence": amount // quantity,
                "qrCode": qr_code,
                "status": "valid",
                "createdAt": datetime.datetime.utcnow().isoformat(),
            }

            try:
                pkpass_bytes = build_pkpass(ticket)
            except Exception as e:
                print(f"❌ Pass generation failed: {e}")
                continue

            if resend_key and user_email:
                html = f"""
                <div style="background:#000;color:#fff;font-family:sans-serif;padding:40px;max-width:500px;margin:0 auto;">
                  <h1 style="color:#d4af37;letter-spacing:4px;font-size:24px;">MANSION</h1>
                  <h2 style="color:#fff;margin-top:0;">Your ticket is confirmed</h2>
                  <p style="color:#aaa;">Thanks for your purchase! Your <strong style="color:#fff;">{tier_name}</strong> ticket for <strong style="color:#fff;">{event_name}</strong> is attached.</p>
                  <p style="color:#aaa;">Open the .pkpass file on your iPhone to add it to Apple Wallet.</p>
                  <p style="color:#d4af37;font-size:13px;">QR Code: {qr_code}</p>
                  <p style="color:#555;font-size:12px;">Show your QR code at the door. Valid ID required. 18+.</p>
                </div>
                """
                attachment_b64 = base64.b64encode(pkpass_bytes).decode("utf-8")
                payload_out = _json.dumps({
                    "from": "Mansion Nightclub <hello@sharecollective.co.uk>",
                    "to": [user_email],
                    "subject": f"Your ticket for {event_name} 🎫",
                    "html": html,
                    "attachments": [{
                        "filename": f"mansion-ticket-{qr_code}.pkpass",
                        "content": attachment_b64
                    }]
                }).encode("utf-8")
                try:
                    req_out = _urllib.Request(
                        "https://api.resend.com/emails",
                        data=payload_out,
                        headers={"Authorization": f"Bearer {resend_key}", "Content-Type": "application/json"}
                    )
                    _urllib.urlopen(req_out, timeout=20)
                    print(f"✅ Ticket emailed to {user_email}")
                except Exception as ex:
                    print(f"❌ Email failed: {ex}")

    return jsonify({"status": "ok"})


if __name__ == "__main__":
    print("🎫 Mansion Pass Signing Service running on http://localhost:5050")
    app.run(host="0.0.0.0", port=5050, debug=False)


# MARK: - Email endpoint (sends pkpass as attachment)

@app.route("/email", methods=["POST"])
def email_pass():
    import smtplib
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.mime.base import MIMEBase
    from email import encoders

    to_email = request.form.get("to")
    name = request.form.get("name", "Guest")
    event_name = request.form.get("eventName", "Mansion Nightclub")
    qr_code = request.form.get("qrCode", "")
    pass_file = request.files.get("pass")

    if not all([to_email, pass_file]):
        return jsonify({"error": "Missing fields"}), 400

    smtp_host = os.environ.get("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(os.environ.get("SMTP_PORT", "587"))
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_pass = os.environ.get("SMTP_PASS", "")

    if not smtp_user or not smtp_pass:
        return jsonify({"error": "Email not configured — set SMTP_USER and SMTP_PASS env vars"}), 500

    msg = MIMEMultipart()
    msg["From"] = f"Mansion Nightclub <{smtp_user}>"
    msg["To"] = to_email
    msg["Subject"] = f"You're on the guestlist — {event_name}"

    html = f"""
    <div style="background:#000;color:#fff;font-family:sans-serif;padding:40px;max-width:500px;margin:0 auto;">
      <h1 style="color:#d4af37;letter-spacing:4px;font-size:24px;">MANSION</h1>
      <h2 style="color:#fff;margin-top:0;">You're on the guestlist</h2>
      <p style="color:#aaa;">Hi {name}, your General Admission pass for <strong style="color:#fff;">{event_name}</strong> is attached.</p>
      <p style="color:#aaa;">Add it to Apple Wallet by opening the attached .pkpass file on your iPhone.</p>
      <p style="color:#555;font-size:12px;">Show your QR code at the door. ID required. 18+.</p>
    </div>
    """
    msg.attach(MIMEText(html, "html"))

    part = MIMEBase("application", "vnd.apple.pkpass")
    part.set_payload(pass_file.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", "attachment", filename="mansion-guestlist.pkpass")
    msg.attach(part)

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.sendmail(smtp_user, to_email, msg.as_string())
        return jsonify({"status": "sent"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
