#!/usr/bin/env python3
"""Package a square icon master into the macOS asset catalog's declared sizes."""
import json
import sys
from pathlib import Path

from PIL import Image


def main():
    source = Path(sys.argv[1])
    catalog = Path(__file__).resolve().parents[1] / "Nockpad/Resources/Assets.xcassets/NockpadIcon.appiconset"
    with Image.open(source) as original:
        if original.width != original.height or original.width < 1024:
            raise ValueError("Icon master must be square and at least 1024 pixels wide")
        master = original.convert("RGBA")
    manifest = json.loads((catalog / "Contents.json").read_text())
    for item in manifest["images"]:
        points = int(item["size"].split("x")[0])
        pixels = points * int(item["scale"].removesuffix("x"))
        output = catalog / item["filename"]
        master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(output)
        with Image.open(output) as check:
            assert check.size == (pixels, pixels)
            assert check.mode == "RGBA"
        print(f"{output.name}: {pixels} × {pixels}")


if __name__ == "__main__":
    main()
