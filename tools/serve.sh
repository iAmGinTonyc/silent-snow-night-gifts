#!/bin/bash
# Локальный сервер для проверки веб-сборки: http://localhost:8060
cd "$(dirname "$0")/.."
python3 -m http.server 8060 --directory build/web
