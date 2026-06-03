param(
    [ValidateSet("M", "L")]
    [string]$Size = "M"
)

$ErrorActionPreference = "Stop"

$keymapFile = "config/keymap.keymap"
$infoJson = "config/info.json"
$layoutsDtsi = "boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_layouts.dtsi"
$parsedYaml = "keymap.yaml"
$renderYaml = "keymap_render.yaml"
$outputSvg = "keymap.svg"
$tempLayout = ".tmp_keymap_layouts_draw.dtsi"

Write-Host "1. Parsing ZMK keymap..."
py -m keymap_drawer parse -z $keymapFile -o $parsedYaml

Write-Host "2. Preparing render YAML ($Size)..."
$env:KEYMAP_SIZE = $Size
$env:PARSED_YAML = $parsedYaml
$env:RENDER_YAML = $renderYaml
@'
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

# Convert shifted legends to readable JIS symbols in layer 2.
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
'@ | py -
Remove-Item Env:KEYMAP_SIZE, Env:PARSED_YAML, Env:RENDER_YAML

if ($Size -eq "M") {
    Write-Host "3. Preparing M layout source..."
    $env:LAYOUT_SRC = $layoutsDtsi
    $env:LAYOUT_TMP = $tempLayout
    @'
import os
from pathlib import Path

src = Path(os.environ["LAYOUT_SRC"])
dst = Path(os.environ["LAYOUT_TMP"])
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
'@ | py -
    Remove-Item Env:LAYOUT_SRC, Env:LAYOUT_TMP

    Write-Host "4. Drawing M-size SVG..."
    py -m keymap_drawer draw $renderYaml -d $tempLayout -l physical_layout_m -o $outputSvg
    Remove-Item $tempLayout -ErrorAction SilentlyContinue
}
else {
    Write-Host "3. Drawing L-size SVG..."
    py -m keymap_drawer draw $renderYaml -j $infoJson -l LAYOUT -o $outputSvg
}

Write-Host "Done: $outputSvg generated (size: $Size)"
