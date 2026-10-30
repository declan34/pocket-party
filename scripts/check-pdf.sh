#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo "SKIPPED: provide the official blank PDF path and a disposable output directory."
  exit 2
fi
cd "$(dirname "$0")/.."
swift run FolioPDFChecks "$1" "$2"
