#!/usr/bin/env python3
"""Verify edition identity, universal binaries, signatures, integrity, and hashes."""
import hashlib
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDITIONS = [
    ("original", "0.1.0", "Nockpad", "app.nockpad.mac"),
    ("return", "0.2.0", "Nockpad Return", "app.nockpad.mac.return"),
    ("quiet", "0.3.0", "Nockpad Quiet", "app.nockpad.mac.quiet"),
    ("fieldnotes", "0.4.0", "Nockpad Fieldnotes", "app.nockpad.mac.fieldnotes"),
    ("rhythm", "0.5.0", "Nockpad Rhythm", "app.nockpad.mac.rhythm"),
]

for edition, version, name, identifier in EDITIONS:
    archive = ROOT / "dist" / f"Nockpad-{version}-{edition}-universal-macOS.zip"
    expected, filename = archive.with_suffix(".sha256").read_text().strip().split(None, 1)
    assert filename == archive.name
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None
        paths = package.namelist()
        forbidden = (".sqlite", ".sqlite-wal", ".sqlite-shm", ".store", ".db", "Jotpad.json", ".env")
        assert not any(p.endswith(forbidden) or "/.git/" in p for p in paths)
        info = plistlib.loads(package.read(f"{name}.app/Contents/Info.plist"))
        assert info["CFBundleIdentifier"] == identifier
        assert info["CFBundleShortVersionString"] == version
        assert info["CFBundleDisplayName"] == name
        assert info.get("NockpadEdition", "original") == edition
    with tempfile.TemporaryDirectory(prefix="nockpad-package-check-") as check_dir:
        subprocess.run(["ditto", "-x", "-k", str(archive), check_dir], check=True)
        app = Path(check_dir) / f"{name}.app"
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
        architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
        assert set(architectures) == {"arm64", "x86_64"}
    print(f"PASS: {edition} {version}: identity, ZIP, checksum, extracted signature, both architectures")
