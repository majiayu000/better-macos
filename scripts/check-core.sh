#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
check_build_dir="$(mktemp -d)"
trap 'rm -rf "$check_build_dir"' EXIT

xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$project_dir/Sources/Models.swift" \
  "$project_dir/Sources/AppIconController.swift" \
  "$project_dir/Sources/DecisionEngine.swift" \
  "$project_dir/Sources/ReminderService.swift" \
  "$project_dir/Sources/AppStore.swift" \
  "$project_dir/Sources/CodexPlanningService.swift" \
  "$project_dir/Sources/CodexCoachService.swift" \
  "$project_dir/Sources/GitContextService.swift" \
  "$project_dir/Checks/CoreChecks.swift" \
  -o "$check_build_dir/better-core-checks"

"$check_build_dir/better-core-checks"
