#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-http://192.168.1.100:3000}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/app"
BACKEND_DIR="$REPO_ROOT/backend"
DIST_DIR="$REPO_ROOT/dist"
BACKEND_PUBLIC_DIR="$BACKEND_DIR/public"

mkdir -p "$DIST_DIR" "$BACKEND_PUBLIC_DIR"

echo "=== Building MyAcrobat Release Artifacts (API_BASE_URL=$API_BASE_URL) ==="

echo "[1/3] Building Backend TypeScript..."
(cd "$BACKEND_DIR" && npm run build)

echo "[2/3] Building Flutter Web Bundle -> backend/public/..."
(cd "$APP_DIR" && flutter pub get && flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL")
cp -R "$APP_DIR/build/web/." "$BACKEND_PUBLIC_DIR/"

echo "[3/3] Building Android Release APK -> dist/MyAcrobat-release.apk..."
(cd "$APP_DIR" && flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL")
cp "$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/MyAcrobat-release.apk"

echo "Done! Artifacts available in $DIST_DIR and $BACKEND_PUBLIC_DIR"
