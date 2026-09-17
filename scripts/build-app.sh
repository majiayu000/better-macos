#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_dir="$project_dir/dist/Better.app"
contents_dir="$app_dir/Contents"
bundle_id="com.starlight.better"
entitlements_path="$project_dir/Resources/Better.entitlements"
identity="${BETTER_SIGNING_IDENTITY:-${APPLE_SIGNING_IDENTITY:--}}"

swift build --package-path "$project_dir" -c release
binary_dir="$(swift build --package-path "$project_dir" -c release --show-bin-path)"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
install -m 755 "$binary_dir/Better" "$contents_dir/MacOS/Better"
install -m 644 "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
install -m 644 "$project_dir/Resources/Better.icns" "$contents_dir/Resources/Better.icns"
ditto "$project_dir/Resources/IconCandidates" "$contents_dir/Resources/IconCandidates"
find "$contents_dir/Resources/IconCandidates" -maxdepth 1 -name '*-chroma.png' -delete

[[ -f "$entitlements_path" ]] || {
    echo "missing entitlements: $entitlements_path" >&2
    exit 1
}

if [[ "${BETTER_REQUIRE_DEVELOPER_ID:-}" == "1" ]]; then
    if [[ "$identity" == "-" || "$identity" != Developer\ ID\ Application:* ]]; then
        echo "BETTER_REQUIRE_DEVELOPER_ID=1 needs APPLE_SIGNING_IDENTITY to be a Developer ID Application identity" >&2
        exit 1
    fi
fi

codesign_args=(
    --force
    --sign "$identity"
    --identifier "$bundle_id"
    --options runtime
    --entitlements "$entitlements_path"
)
if [[ "$identity" == "-" ]]; then
    codesign_args+=(--timestamp=none)
else
    codesign_args+=(--timestamp)
fi

codesign "${codesign_args[@]}" "$contents_dir/MacOS/Better"
codesign "${codesign_args[@]}" "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"
