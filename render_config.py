#!/usr/bin/env python3
"""Erzeugt die vdirsyncer-Config aus Umgebungsvariablen/Secrets.

Bewusst TOML-sicher (json.dumps) statt sed/envsubst, damit Sonderzeichen in
Passwörtern oder Kalender-IDs weder die Config zerschießen noch eine Injection
ermöglichen. Pflichtwerte werden validiert, HTTPS wird erzwungen.
"""
import json
import os
import sys
import urllib.parse


def fail(msg: str) -> None:
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(1)


def secret(name: str, required: bool = True) -> str:
    """Liest VAR oder - bevorzugt - die Datei aus VAR_FILE (Docker-Secret-Konvention)."""
    file_var = os.environ.get(f"{name}_FILE")
    if file_var:
        try:
            with open(file_var, encoding="utf-8") as fh:
                val = fh.read().strip("\n")
        except OSError as exc:
            fail(f"Secret-Datei fuer {name} nicht lesbar: {exc}")
    else:
        val = os.environ.get(name, "")
    if required and not val:
        fail(f"Pflichtvariable fehlt: {name} (oder {name}_FILE)")
    return val


def q(value: str) -> str:
    """TOML-/JSON-sicher gequotete Zeichenkette (escaped \" und \\)."""
    return json.dumps(value)


def main() -> None:
    apple_id = secret("APPLE_ID")
    apple_pw = secret("APPLE_APP_PASSWORD")
    syno_url = secret("SYNOLOGY_CALDAV_URL")
    syno_user = secret("SYNOLOGY_USER")
    syno_pw = secret("SYNOLOGY_PASSWORD")

    if urllib.parse.urlparse(syno_url).scheme != "https":
        fail("SYNOLOGY_CALDAV_URL muss HTTPS verwenden (Klartext-Uebertragung ist verboten).")

    conflict = os.environ.get("CONFLICT_RESOLUTION", "a wins")
    if conflict not in ("a wins", "b wins"):
        fail('CONFLICT_RESOLUTION muss "a wins" oder "b wins" sein.')

    mode = os.environ.get("COLLECTIONS_MODE", "auto")
    if mode == "auto":
        collections = '["from a", "from b"]'
    elif mode == "named":
        names = [s.strip() for s in os.environ.get("COLLECTIONS", "").split(",") if s.strip()]
        if not names:
            fail("COLLECTIONS_MODE=named, aber COLLECTIONS ist leer.")
        collections = json.dumps(names)
    elif mode == "mapping":
        raw = os.environ.get("COLLECTION_MAPPING", "").strip()
        if not raw:
            fail("COLLECTIONS_MODE=mapping, aber COLLECTION_MAPPING ist leer.")
        try:
            collections = json.dumps(json.loads(raw))
        except json.JSONDecodeError as exc:
            fail(f"COLLECTION_MAPPING ist kein gueltiges JSON: {exc}")
    else:
        fail(f"Unbekannter COLLECTIONS_MODE: {mode}")

    verify_line = ""
    if os.environ.get("SYNOLOGY_VERIFY", "true").lower() in ("false", "0", "no"):
        print(
            "⚠️  SYNOLOGY_VERIFY=false: TLS-Zertifikat wird NICHT geprueft "
            "(nur fuer vertrauenswuerdige LAN-Verbindungen mit self-signed Cert).",
            file=sys.stderr,
        )
        verify_line = "verify = false\n"

    sys.stdout.write(
        f"""[general]
status_path = "/config/status"

[pair icloud_synology]
a = "iCloud"
b = "Synology"
collections = {collections}
conflict_resolution = {q(conflict)}

[storage iCloud]
type = "caldav"
url = "https://caldav.icloud.com/"
username = {q(apple_id)}
password = {q(apple_pw)}

[storage Synology]
type = "caldav"
url = {q(syno_url)}
username = {q(syno_user)}
password = {q(syno_pw)}
{verify_line}"""
    )


if __name__ == "__main__":
    main()
