#!/bin/bash
# Экспорт веб-версии в build/web. Нужны Godot 4.7.2 и шаблоны экспорта той же версии.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cp web/loader.png build/web/loader.png
rm -f build/web/loader.jpg
echo "Готово: build/web/index.html (с загрузочным экраном)"
