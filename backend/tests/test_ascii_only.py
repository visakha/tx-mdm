"""Guard: every tracked text file in the repo is plain ASCII.

Rule (Vamsi, 2026-11-22): no emoji, icons, glyphs or special Unicode anywhere - code, logs,
terminal output or docs - because Windows terminals garble them.
Excluded: binary files (PDF, Office, images) and vendor originals we must not edit.
"""

import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BINARY_SUFFIXES = {".pdf", ".pptx", ".xlsx", ".docx", ".png", ".jpg", ".jpeg", ".gif", ".ico"}


def _tracked_text_files() -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files"], cwd=REPO, capture_output=True, text=True, check=True
    ).stdout
    paths = [REPO / line for line in out.splitlines() if line]
    return [p for p in paths if p.suffix.lower() not in BINARY_SUFFIXES and p.is_file()]


def test_tracked_text_files_are_ascii_only() -> None:
    offenders = []
    for path in _tracked_text_files():
        data = path.read_bytes()
        for line_no, line in enumerate(data.splitlines(), start=1):
            if any(b > 0x7F for b in line):
                offenders.append(f"{path.relative_to(REPO)}:{line_no}")
                break
    assert not offenders, "Non-ASCII characters found (ASCII only rule):\n" + "\n".join(offenders)
