#!/bin/sh

set -eu

REPOSITORY=${ORBIT_REPOSITORY:-SuuSoJeat/orbit}
INSTALL_PREFIX=${ORBIT_INSTALL_PREFIX:-${HOME}/.local}
DOWNLOAD_ROOT=${ORBIT_DOWNLOAD_ROOT:-https://github.com/${REPOSITORY}/releases/latest/download}
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/orbit-install.XXXXXX")

cleanup() {
    /bin/rm -rf "$TEMP_ROOT"
}
trap cleanup 0 HUP INT TERM

ARCHIVE="${TEMP_ROOT}/orbit.tar.gz"
CHECKSUM="${TEMP_ROOT}/orbit.tar.gz.sha256"

printf 'Downloading Orbit from %s...\n' "$REPOSITORY"
curl --fail --silent --show-error --location "${DOWNLOAD_ROOT}/orbit.tar.gz" --output "$ARCHIVE"
curl --fail --silent --show-error --location "${DOWNLOAD_ROOT}/orbit.tar.gz.sha256" --output "$CHECKSUM"

expected_checksum=$(awk '{ print $1 }' "$CHECKSUM")
if command -v shasum >/dev/null 2>&1; then
    actual_checksum=$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')
elif command -v sha256sum >/dev/null 2>&1; then
    actual_checksum=$(sha256sum "$ARCHIVE" | awk '{ print $1 }')
else
    printf 'ERROR: shasum or sha256sum is required to verify the download.\n' >&2
    exit 1
fi

[ "$expected_checksum" = "$actual_checksum" ] || {
    printf 'ERROR: checksum verification failed.\n' >&2
    exit 1
}

tar -xzf "$ARCHIVE" -C "$TEMP_ROOT"
PACKAGE_ROOT=$(find "$TEMP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'orbit-*' -print -quit)
[ -n "$PACKAGE_ROOT" ] || {
    printf 'ERROR: release archive did not contain an Orbit package.\n' >&2
    exit 1
}

VERSION=$(cat "${PACKAGE_ROOT}/VERSION")
INSTALL_ROOT="${INSTALL_PREFIX}/share/orbit/${VERSION}"
INSTALL_BIN="${INSTALL_PREFIX}/bin/orbit"

mkdir -p "$INSTALL_ROOT" "${INSTALL_PREFIX}/bin"
cp -R "${PACKAGE_ROOT}/bin" "${PACKAGE_ROOT}/templates" "$INSTALL_ROOT/"
cp "${PACKAGE_ROOT}/VERSION" "${PACKAGE_ROOT}/README.md" "${PACKAGE_ROOT}/Makefile" "$INSTALL_ROOT/"
chmod 755 "${INSTALL_ROOT}/bin/orbit"
printf '#!/bin/sh\nexec "%s" "$@"\n' "${INSTALL_ROOT}/bin/orbit" > "$INSTALL_BIN"
chmod 755 "$INSTALL_BIN"

printf 'Installed Orbit %s at %s\n' "$VERSION" "$INSTALL_BIN"
case ":${PATH}:" in
    *":${INSTALL_PREFIX}/bin:"*) ;;
    *) printf 'Add %s/bin to PATH to use orbit from any shell.\n' "$INSTALL_PREFIX" ;;
esac
