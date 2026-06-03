#!/bin/bash

CONFIG_FILE="keymap_drawer.config.yaml"
OUTPUT_YAML="keymap.yaml"
OUTPUT_SVG="keymap.svg"
KEYMAP_FILE="config/keymap.keymap"
INFO_JSON="config/info.json"
LAYOUT_DTSI="boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_layouts.dtsi"
OUTPUT_M_YAML="keymap_m.yaml"
SIZE="${1:-M}"

# 設定ファイルがない場合はデフォルト設定を出力
if [ ! -f "$CONFIG_FILE" ]; then
    echo "構成ファイル (${CONFIG_FILE}) が見つかりません。デフォルト設定を生成します。"
    python3 -m keymap_drawer dump-config > "$CONFIG_FILE"
fi

echo "1. ZMKのkeymapをパースしてYAMLに変換しています..."
python3 -m keymap_drawer -c "$CONFIG_FILE" parse -z "$KEYMAP_FILE" -o "$OUTPUT_YAML"

if [ "$SIZE" = "M" ]; then
    echo "2. Mサイズ用にキー配列を変換しています..."
    python3 - <<'PY'
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

new_combos = []
for combo in data.get("combos", []):
    pos = combo.get("p", [])
    if all(p in index_map for p in pos):
        combo["p"] = [index_map[p] for p in pos]
        new_combos.append(combo)
data["combos"] = new_combos

with dst.open("w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
PY

    echo "3. Mサイズの物理レイアウトでSVGを描画しています..."
    python3 -m keymap_drawer -c "$CONFIG_FILE" draw "$OUTPUT_M_YAML" -d "$LAYOUT_DTSI" -l physical_layout_m -o "$OUTPUT_SVG"
else
    echo "2. LサイズのレイアウトでSVGを描画しています..."
    python3 -m keymap_drawer -c "$CONFIG_FILE" draw "$OUTPUT_YAML" -j "$INFO_JSON" -l LAYOUT -o "$OUTPUT_SVG"
fi

echo "完了しました！ ${OUTPUT_SVG} が生成されました。（size=${SIZE}）"
