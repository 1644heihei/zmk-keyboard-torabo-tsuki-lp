param(
    [ValidateSet("M", "L")]
    [string]$Size = "M"
)

$ErrorActionPreference = "Stop"

$configFile = "keymap_drawer.config.yaml"
$keymapFile = "config/keymap.keymap"
$infoJson = "config/info.json"
$layoutDtsi = "boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_layouts.dtsi"
$outputYaml = "keymap.yaml"
$outputSvg = "keymap.svg"
$outputMYaml = "keymap_m.yaml"

if (-not (Test-Path $configFile)) {
    Write-Host "Config file ($configFile) not found. Generating default config."
    py -m keymap_drawer dump-config | Out-File -Encoding utf8 $configFile
}

Write-Host "1. Parsing ZMK keymap to YAML..."
py -m keymap_drawer -c $configFile parse -z $keymapFile -o $outputYaml

if ($Size -eq "M") {
    Write-Host "2. Building M-size remapped YAML..."
    @'
import yaml
from pathlib import Path

src = Path("keymap.yaml")
dst = Path("keymap_m.yaml")
keep = [
    12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
    24, 25, 26, 27, 28, 29, 32, 33, 34, 35, 36, 37,
    38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
    50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61,
    62, 63, 64, 65,
]

with src.open("r", encoding="utf-8") as f:
    data = yaml.safe_load(f)

index_map = {old: new for new, old in enumerate(keep)}
for layer_name, layer in data["layers"].items():
    data["layers"][layer_name] = [layer[i] for i in keep]

# Replace shifted US-style legends with JIS-style symbol legends for rendering.
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
    "Sft+\\": "|",
    "Sft+[": "{",
    "Sft+]": "}",
    "Sft+YEN": "|",
}

for i, key in enumerate(data["layers"].get("2", [])):
    if isinstance(key, str):
        data["layers"]["2"][i] = legend_map.get(key, key)
    elif isinstance(key, dict) and "t" in key:
        key["t"] = legend_map.get(key["t"], key["t"])

new_combos = []
for combo in data.get("combos", []):
    pos = combo.get("p", [])
    if all(p in index_map for p in pos):
        combo["p"] = [index_map[p] for p in pos]
        new_combos.append(combo)
data["combos"] = new_combos

with dst.open("w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
'@ | py -

    Write-Host "3. Drawing SVG with physical_layout_m..."
    py -m keymap_drawer -c $configFile draw $outputMYaml -d $layoutDtsi -l physical_layout_m -o $outputSvg
}
else {
    Write-Host "2. Drawing SVG with L-size layout..."
    py -m keymap_drawer -c $configFile draw $outputYaml -j $infoJson -l LAYOUT -o $outputSvg
}

Write-Host "Done: $outputSvg generated (size: $Size)."
