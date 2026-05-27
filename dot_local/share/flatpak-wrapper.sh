# This script is sourced by wrappers. It expects APP_NAME and FLATPAK_ID to be set.

# If Flatpak is installed, execute it
if flatpak info "$FLATPAK_ID" &>/dev/null; then
    exec flatpak run "$FLATPAK_ID" "$@" 2>/dev/null
fi

# Fallback to native binary
# Because this script is 'sourced', $0 is correctly the caller script (e.g., ~/.config/.bin/code)
SCRIPT_PATH=$(realpath "$0")

for exe in $(type -P -a "$APP_NAME"); do
    if [ "$(realpath "$exe")" != "$SCRIPT_PATH" ]; then
        exec "$exe" "$@" 2>/dev/null
    fi
done

# If neither exists
echo "$APP_NAME not found (neither Flatpak nor Native)" >&2
exit 1
