#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /private/tmp/folio-presentation-check.XXXXXX)
swiftc Sources/FolioApp/Presentation.swift Tests/FolioPresentationChecks/main.swift -o "$check_dir/checks"
"$check_dir/checks"
