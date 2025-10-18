#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-GrindLab}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
PROJECT="${PROJECT:-GrindLab.xcodeproj}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/.derived_data}"
mkdir -p "$DERIVED_DATA_PATH"

echo "🔎 Preflight: scheme=$SCHEME configuration=$CONFIGURATION destination=$DESTINATION"
echo "Using project: $PROJECT"
echo "Derived data: $DERIVED_DATA_PATH"

# optional: verify scheme exists in the project
xcodebuild -list -json -project "$PROJECT" >/dev/null

set +e
SETTINGS_TEXT="$(
  xcodebuild \
    -showBuildSettings \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" 2>&1
)"
BSTATUS=$?
set -e
if [[ $BSTATUS -ne 0 ]]; then
  echo "$SETTINGS_TEXT"
  echo "❌ xcodebuild -showBuildSettings failed (exit $BSTATUS)"
  exit $BSTATUS
fi

BUNDLE_ID="$(printf '%s\n' "$SETTINGS_TEXT" | awk -F' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*=/{print $2; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
DEV_TEAM="$(printf '%s\n' "$SETTINGS_TEXT" | awk -F' = ' '/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=/{print $2; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
CODE_SIGN_STYLE="$(printf '%s\n' "$SETTINGS_TEXT" | awk -F' = ' '/^[[:space:]]*CODE_SIGN_STYLE[[:space:]]*=/{print $2; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
PROV_SPECIFIER="$(printf '%s\n' "$SETTINGS_TEXT" | awk -F' = ' '/^[[:space:]]*PROVISIONING_PROFILE_SPECIFIER[[:space:]]*=/{print $2; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

echo "Bundle ID: $BUNDLE_ID"
echo "Dev Team:  $DEV_TEAM"
echo "Code Sign: $CODE_SIGN_STYLE"

[ -n "$BUNDLE_ID" ] || { echo "❌ Missing PRODUCT_BUNDLE_IDENTIFIER"; exit 1; }
[ -n "$DEV_TEAM" ]  || { echo "❌ Missing DEVELOPMENT_TEAM"; exit 1; }
[[ "$BUNDLE_ID" != *"*"* ]] || { echo "❌ Wildcard bundle ID in project: $BUNDLE_ID"; exit 1; }
if [[ "$CODE_SIGN_STYLE" == "Manual" && -z "$PROV_SPECIFIER" ]]; then
  echo "❌ Manual signing selected but no PROVISIONING_PROFILE_SPECIFIER set."
  exit 1
fi

echo "✅ Preflight checks passed."
