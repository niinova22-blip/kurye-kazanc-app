#!/usr/bin/env bash
# TESTFLIGHT_NOTES.md dosyasindaki ILK "## " basligi altindaki bolumu (en guncel surum notu)
# Codemagic'in TestFlight "What to Test" alani icin okudugu release_notes.json dosyasina cevirir.
set -euo pipefail

python3 - <<'EOF'
import json, pathlib, sys

text = pathlib.Path("TESTFLIGHT_NOTES.md").read_text(encoding="utf-8")
sections = text.split("\n## ")
if len(sections) < 2:
    sys.exit("TESTFLIGHT_NOTES.md icinde '## ' ile baslayan surum bolumu yok")

latest = "## " + sections[1].strip()
# TestFlight "What to Test" alani en fazla 4000 karakter
notes = latest[:4000]
pathlib.Path("release_notes.json").write_text(
    json.dumps([{"language": "tr", "text": notes}], ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print(notes)
EOF
