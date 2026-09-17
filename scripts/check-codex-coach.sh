#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
smoke_build_dir="$(mktemp -d)"
trap 'rm -rf "$smoke_build_dir"' EXIT

xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$project_dir/Sources/Models.swift" \
  "$project_dir/Sources/CodexPlanningService.swift" \
  "$project_dir/Sources/CodexCoachService.swift" \
  "$project_dir/Checks/CodexCoachSmoke.swift" \
  -o "$smoke_build_dir/better-codex-coach-smoke"

"$smoke_build_dir/better-codex-coach-smoke"
