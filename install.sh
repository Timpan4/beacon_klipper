#!/bin/bash

set -u

BKDIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd -P)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

KLIPPER_PATH="${KLIPPER_PATH:-$HOME/klipper}"
if [ ! -d "$KLIPPER_PATH/klippy/extras" ]; then
    echo "beacon: ERROR: Klipper path invalid: $KLIPPER_PATH"
    echo "beacon:        expected: $KLIPPER_PATH/klippy/extras"
    echo "beacon:        set KLIPPER_PATH to override"
    exit 1
fi

PRINTER_DATA="${PRINTER_DATA:-$HOME/printer_data}"
if [ ! -d "$PRINTER_DATA" ] && [ ! -d "$PRINTER_DATA/config" ]; then
    echo "beacon: WARNING: printer_data not found at $PRINTER_DATA (continuing)"
fi

KLIPPY_ENV="${KLIPPY_ENV:-$HOME/klippy-env}"

DEST_FILE="$KLIPPER_PATH/klippy/extras/beacon.py"
SRC_FILE="$BKDIR/beacon.py"

if [ ! -f "$SRC_FILE" ]; then
    echo "beacon: ERROR: source file missing: $SRC_FILE"
    exit 1
fi

if [ -d "$KLIPPY_ENV" ] && [ -x "$KLIPPY_ENV/bin/pip" ]; then
    echo "beacon: installing python requirements into $KLIPPY_ENV"
    "$KLIPPY_ENV/bin/pip" install -r "$BKDIR/requirements.txt" || \
        echo "beacon: WARNING: pip install failed (continuing)"
else
    echo "beacon: WARNING: KLIPPY_ENV not found or pip missing, skipping requirements"
fi

if [ -e "$DEST_FILE" ] || [ -L "$DEST_FILE" ]; then
    BACKUP_FILE="$DEST_FILE.$TIMESTAMP.bak"
    echo "beacon: backing up existing beacon.py -> $BACKUP_FILE"
    cp -a "$DEST_FILE" "$BACKUP_FILE" || {
        echo "beacon: ERROR: backup failed"
        exit 1
    }
    rm -f "$DEST_FILE"
fi

echo "beacon: linking $DEST_FILE -> $SRC_FILE"
ln -s "$SRC_FILE" "$DEST_FILE" || {
    echo "beacon: ERROR: failed to install beacon.py"
    exit 1
}

if [ -f "$KLIPPER_PATH/.git/info/exclude" ] \
    && ! grep -q "^klippy/extras/beacon.py$" "$KLIPPER_PATH/.git/info/exclude"; then
    echo "klippy/extras/beacon.py" >> "$KLIPPER_PATH/.git/info/exclude"
fi

echo "beacon: installation successful"

if [ -x "$KLIPPY_ENV/bin/python" ]; then
    echo "beacon: updating firmware"
    "$KLIPPY_ENV/bin/python" "$BKDIR/update_firmware.py" update all || \
        echo "beacon: WARNING: firmware update helper failed"
fi
