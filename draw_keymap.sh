#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-M}"
KEYMAP_FILE="config/keymap.keymap"
INFO_JSON="config/info.json"
LAYOUTS_DTSI="boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_layouts.dtsi"
PARSED_YAML="keymap.yaml"
RENDER_YAML="keymap_render.yaml"
OUTPUT_SVG="keymap.svg"
TMP_LAYOUT=".tmp_keymap_layouts_draw.dtsi"

echo "1. Parsing ZMK keymap..."
python3 -m keymap_drawer parse -z "$KEYMAP_FILE" -o "$PARSED_YAML"

echo "2. Preparing render YAML ($SIZE)..."
KEYMAP_SIZE="$SIZE" PARSED_YAML="$PARSED_YAML" RENDER_YAML="$RENDER_YAML" python3 - <<'PY'
import os
import yaml
from pathlib import Path

src = Path(os.environ["PARSED_YAML"])
dst = Path(os.environ["RENDER_YAML"])
size = os.environ["KEYMAP_SIZE"]

with src.open("r", encoding="utf-8") as f:
    data = yaml.safe_load(f)

if size == "M":
    keep = [
        12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 32, 33, 34, 35, 36, 37,
        38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
        50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61,
        62, 63, 64, 65,
    ]
    index_map = {old: new for new, old in enumerate(keep)}
    for layer_name, layer in data["layers"].items():
        data["layers"][layer_name] = [layer[i] for i in keep]

    new_combos = []
    for combo in data.get("combos", []):
        pos = combo.get("p", [])
        if all(p in index_map for p in pos):
            combo["p"] = [index_map[p] for p in pos]
            new_combos.append(combo)
    data["combos"] = new_combos

legend_map = {
    "Sft+1": "!",
    "Sft+2": "\"",
    "Sft+3": "#",
    "Sft+4": "$",
    "Sft+5": "%",
    "Sft+6": "&",
    "Sft+7": "'",
    "Sft+8": "(",
    "Sft+9": ")",
    "Sft+0": "~",
    "Sft+-": "=",
    "Sft+=": "+",
    "Sft+\\": "|",
    "Sft+[": "{",
    "Sft+]": "}",
    "Sft+YEN": "|",
}
for i, key in enumerate(data.get("layers", {}).get("2", [])):
    if isinstance(key, str):
        data["layers"]["2"][i] = legend_map.get(key, key)
    elif isinstance(key, dict) and "t" in key:
        key["t"] = legend_map.get(key["t"], key["t"])

with dst.open("w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
PY

if [[ "$SIZE" == "M" ]]; then
  echo "3. Preparing M layout source..."
  LAYOUTS_DTSI="$LAYOUTS_DTSI" TMP_LAYOUT="$TMP_LAYOUT" python3 - <<'PY'
import os
from pathlib import Path

src = Path(os.environ["LAYOUTS_DTSI"])
dst = Path(os.environ["TMP_LAYOUT"])
text = src.read_text(encoding="utf-8")

for marker in (
    "physical_layout_s: physical_layout_0 {",
    "physical_layout_m: physical_layout_1 {",
    "physical_layout_l: physical_layout_2 {",
):
    if marker in text:
        block_start = text.index(marker)
        block_end = text.index("};", block_start)
        block = text[block_start:block_end]
        if 'compatible = "zmk,physical-layout";' not in block:
            text = text.replace(marker, marker + '\n        compatible = "zmk,physical-layout";', 1)

dst.write_text(text, encoding="utf-8")
PY

  echo "4. Drawing M-size SVG..."
  python3 -m keymap_drawer draw "$RENDER_YAML" -d "$TMP_LAYOUT" -l physical_layout_m -o "$OUTPUT_SVG"
  rm -f "$TMP_LAYOUT"
else
  echo "3. Drawing L-size SVG..."
  python3 -m keymap_drawer draw "$RENDER_YAML" -j "$INFO_JSON" -l LAYOUT -o "$OUTPUT_SVG"
fi

echo "Done: $OUTPUT_SVG generated (size: $SIZE)"
