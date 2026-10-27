# This script is sourced by wrappers.
#
# Required:
#   APP_NAME    - native executable name
#   FLATPAK_ID  - Flatpak application ID
#
# Optional:
#   FLATPAK_COMMAND      - command to run inside the Flatpak
#                          (e.g. "keepassxc-cli"). Omit for the default GUI.
#   WRAPPER_KEEP_STDERR  - set to 1 to preserve stderr.
#                          Required for interactive CLI prompts.

flatpak_args=(run)
if [ -n "${FLATPAK_COMMAND:-}" ]; then
    flatpak_args+=(--command="$FLATPAK_COMMAND")
fi
flatpak_args+=("$FLATPAK_ID")

# If Flatpak is installed, execute it
if flatpak info "$FLATPAK_ID" &>/dev/null; then
    if [ "${WRAPPER_KEEP_STDERR:-0}" = "1" ]; then
        exec flatpak "${flatpak_args[@]}" "$@"
    fi
    exec flatpak "${flatpak_args[@]}" "$@" 2>/dev/null
fi

# Fallback to native binary
# Because this script is 'sourced', $0 is correctly the caller script (e.g., ~/.config/.bin/code)
SCRIPT_PATH=$(realpath "$0")

for exe in $(type -P -a "$APP_NAME"); do
    if [ "$(realpath "$exe")" != "$SCRIPT_PATH" ]; then
        if [ "${WRAPPER_KEEP_STDERR:-0}" = "1" ]; then
            exec "$exe" "$@"
        fi
        exec "$exe" "$@" 2>/dev/null
    fi
done

# If neither exists
echo "$APP_NAME not found (neither Flatpak nor Native)" >&2
exit 1
