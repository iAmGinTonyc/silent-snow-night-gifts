#!/bin/bash
# Собирает веб-версию и публикует её в ветку gh-pages (GitHub Pages).
# Нужны Godot 4.7.2 с шаблонами экспорта и настроенный remote origin.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./tools/build_web.sh
REMOTE="$(git remote get-url origin)"
NAME="$(git config user.name)"
EMAIL="$(git config user.email)"
TMP="$(mktemp -d)"
cp -R build/web/. "$TMP/"
rm -f "$TMP"/*.import
touch "$TMP/.nojekyll"
cd "$TMP"
git init -q -b gh-pages
git add -A
git -c user.name="$NAME" -c user.email="$EMAIL" commit -q -m "Deploy web build"
git push -f -q "$REMOTE" gh-pages
rm -rf "$TMP"
echo "Опубликовано в ветку gh-pages"
