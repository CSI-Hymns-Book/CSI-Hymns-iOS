#!/bin/sh
# Builds and runs the FreeShow formatter check without needing an Xcode test target.
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/check-freeshow-formatter"
swiftc -o "$OUT" "CSI Hymns App/Services/FreeShowFormatter.swift" "CSI Hymns App/Services/SimpleZipArchive.swift" scripts/freeshow-formatter-check/main.swift
"$OUT"
