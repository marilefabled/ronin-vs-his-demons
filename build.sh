#!/usr/bin/env bash
# Vercel build entry point for the Flutter web target.

set -euo pipefail

FLUTTER_DIR="${PWD}/flutter"

if [ -d "${FLUTTER_DIR}" ]; then
  echo "→ updating cached Flutter SDK"
  (cd "${FLUTTER_DIR}" && git pull --ff-only || true)
else
  echo "→ cloning Flutter stable"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

echo "→ flutter doctor"
flutter doctor -v || true

echo "→ flutter pub get"
flutter pub get

echo "→ flutter build web"
flutter build web --release --no-tree-shake-icons

echo "→ done"
ls -la build/web | head -10
