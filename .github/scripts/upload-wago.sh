#!/usr/bin/env bash
# Uploads $ZIP to Wago Addons as a Forever file.
# Needs: WAGO_API_TOKEN, WAGO_PROJECT_ID, ZIP, VERSION, STABILITY, PATCH, NOTES_FILE.
set -euo pipefail

patches=$(curl -fsS https://addons.wago.io/api/data/game | jq -c '.patches.forever // []')
if ! jq -e --arg v "$PATCH" 'index($v)' <<<"$patches" >/dev/null; then
	echo "Wago has no Forever patch $PATCH (known: $patches)" >&2
	exit 1
fi

stability="$STABILITY"
[ "$stability" = "release" ] && stability="stable"

metadata=$(jq -n \
	--arg label "$VERSION" \
	--arg patch "$PATCH" \
	--arg stability "$stability" \
	--rawfile changelog "$NOTES_FILE" \
	'{label: $label, supported_forever_patches: [$patch], stability: $stability, changelog: $changelog}')

echo "Uploading $ZIP to Wago project $WAGO_PROJECT_ID (Forever $PATCH, $stability)"
curl -fsS -H "authorization: Bearer $WAGO_API_TOKEN" -H "accept: application/json" \
	-F "metadata=$metadata" -F "file=@$ZIP" \
	"https://addons.wago.io/api/projects/$WAGO_PROJECT_ID/version"
echo
