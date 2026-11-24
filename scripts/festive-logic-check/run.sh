#!/bin/sh
# Compiles the pure festive logic together with its checks and runs them.
set -e
cd "$(dirname "$0")/../.."
SRC="CSI Hymns App/Services/Festive"
OUT="$(mktemp -d)/festive-logic-check"
swiftc -O -o "$OUT" "$SRC/FestiveLogic.swift" "$SRC/FestiveMotionMath.swift" "$SRC/CarolInterop.swift" "$SRC/FestiveEngine.swift" "$SRC/FestiveGifts.swift" "$SRC/CarolSearch.swift" "$SRC/CarolPermissions.swift" "CSI Hymns App/Models/CarolSong.swift" scripts/festive-logic-check/main.swift
"$OUT"
