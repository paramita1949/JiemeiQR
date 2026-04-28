#!/usr/bin/env python3
import argparse
from pathlib import Path

from client import receive_backup


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
