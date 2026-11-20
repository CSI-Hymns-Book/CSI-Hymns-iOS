#!/bin/sh
# Builds and runs the ticket-format check without needing an Xcode test target.
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/check-lyrics-ticket-format"
swiftc -o "$OUT" "CSI Hymns App/Services/LyricsTicketType.swift" scripts/ticket-format-check/main.swift
"$OUT"
