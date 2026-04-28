#!/usr/bin/env python3
import argparse
import base64
import json
from datetime import datetime
from pathlib import Path

import requests


def parse_connection_code(raw: str) -> tuple[str, str]:
    payload = raw.strip()
    normalized = payload + "=" * (-len(payload) % 4)
    decoded = base64.urlsafe_b64decode(normalized.encode("utf-8"))
    data = json.loads(decoded.decode("utf-8"))
    base_url = data["baseUrl"]
    pairing_code = data["pairingCode"]
    if not base_url or not pairing_code:
        raise ValueError("connection code missing baseUrl or pairingCode")
    return base_url, pairing_code


def receive_backup(connection_code: str, output_dir: Path) -> Path:
    base_url, pairing_code = parse_connection_code(connection_code)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest_resp = requests.get(f"{base_url}/manifest", timeout=15)
    manifest_resp.raise_for_status()
    manifest = manifest_resp.json()

    sender_pairing = manifest.get("pairingCode")
    if sender_pairing != pairing_code:
        raise RuntimeError("pairing code mismatch")

    database_path = manifest.get("databasePath", "")
    db_name = Path(database_path).name
    if not db_name:
        raise RuntimeError("invalid manifest: missing databasePath")

    db_resp = requests.get(f"{base_url}/database/{db_name}", timeout=30)
    db_resp.raise_for_status()
    content = db_resp.content
    if not content.startswith(b"SQLite format 3"):
        raise RuntimeError("downloaded file is not sqlite database")

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_name = f"jiemei-backup-{stamp}.sqlite"
    backup_path = output_dir / backup_name
    backup_path.write_bytes(content)

    info_path = output_dir / f"jiemei-backup-{stamp}.backup_info.json"
    info_path.write_text(
        json.dumps(
            {
                "createdAt": datetime.now().isoformat(),
                "sourceBaseUrl": base_url,
                "databaseFileName": db_name,
                "savedBackupPath": str(backup_path),
                "reason": "pc_pull_from_phone",
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return backup_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Receive QRSCAN backup snapshot from phone sender."
    )
    parser.add_argument(
        "--code",
        required=True,
        help="Connection code copied from phone sender QR content.",
    )
    parser.add_argument(
        "--output",
        default=".",
        help="Directory to save sqlite backup file.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output).resolve()
    try:
        result = receive_backup(args.code, output_dir)
        print(f"Backup received: {result}")
    except Exception as exc:  # noqa: BLE001
        print(f"Failed: {exc}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
