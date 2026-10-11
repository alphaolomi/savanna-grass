#!/usr/bin/env bash
# Vendors MediaPipe GenAI (Apache-2.0) into web/mediapipe/ so the web build
# runs the model with no CDN at runtime — the app has to work outside, offline.
#
#   bash tool/vendor_mediapipe.sh
#
# Pinned to the version flutter_gemma 0.13.x is built against, fetched as the
# official npm tarball and checked against the registry's integrity hash.
set -euo pipefail
VERSION=0.10.27
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/web/mediapipe"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
npm pack "@mediapipe/tasks-genai@$VERSION" --silent >/dev/null
TARBALL="mediapipe-tasks-genai-$VERSION.tgz"
EXPECTED="$(npm view "@mediapipe/tasks-genai@$VERSION" dist.integrity)"
ACTUAL="sha512-$(openssl dgst -sha512 -binary "$TARBALL" | openssl base64 -A)"
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "integrity mismatch for $TARBALL" >&2
  exit 1
fi
tar -xzf "$TARBALL"

rm -rf "$DEST"
mkdir -p "$DEST/wasm"
cp package/genai_bundle.mjs "$DEST/"
cp package/wasm/genai_wasm_internal.js package/wasm/genai_wasm_internal.wasm \
   package/wasm/genai_wasm_nosimd_internal.js package/wasm/genai_wasm_nosimd_internal.wasm "$DEST/wasm/"
cp package/LICENSE "$DEST/" 2>/dev/null || true
echo "MediaPipe GenAI $VERSION → web/mediapipe ($(du -sh "$DEST" | cut -f1))"
