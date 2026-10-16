#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
check_dir=$(mktemp -d /tmp/nockpad-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library \
  Nockpad/Models/Models.swift \
  Nockpad/Services/AppSettings.swift \
  Nockpad/Services/TimerEngine.swift \
  Nockpad/Theme/Theme.swift \
  Nockpad/Views/JotpadView.swift \
  Nockpad/Views/EditionFeatures.swift \
  Tests/Smoke.swift -o "$check_dir/NockpadSmoke"
"$check_dir/NockpadSmoke"
