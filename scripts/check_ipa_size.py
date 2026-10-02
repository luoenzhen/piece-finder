"""Check the complete uncompressed iPhone app against the PRD size budget."""

import json
from pathlib import Path
import sys
from zipfile import ZipFile


def check_size(ipa: Path) -> dict:
    with ZipFile(ipa) as archive:
        files = [
            entry for entry in archive.infolist()
            if entry.filename.startswith("Payload/") and not entry.is_dir()
        ]
        if not files:
            raise ValueError("IPA contains no app payload")
        size = sum(entry.file_size for entry in files)
        return {
            "ipa_bytes": ipa.stat().st_size,
            "uncompressed_app_bytes": size,
            "budget_bytes": 65_000_000,
            "within_budget": size <= 65_000_000,
            "largest_files": [
                {"path": entry.filename, "bytes": entry.file_size}
                for entry in sorted(files, key=lambda entry: entry.file_size, reverse=True)[:10]
            ],
        }


if __name__ == "__main__":
    report = check_size(Path(sys.argv[1]))
    output = Path(sys.argv[2])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["within_budget"] else 1)
