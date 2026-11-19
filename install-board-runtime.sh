#!/usr/bin/env bash
# Pull board-runtime from https://github.com/lumi-jlding/test.git, extract, install.
#
# One-shot on the RK board:
#   bash install-board-runtime-from-github.sh
#   bash install-board-runtime-from-github.sh --apps lumi-locomotion
#
# Env overrides:
#   LUMI_BOARD_RUNTIME_REPO   default https://github.com/lumi-jlding/test.git
#   LUMI_BOARD_RUNTIME_REF    default main (branch/tag for the helper repo)
#   LUMI_BOARD_RUNTIME_TAG    default v1.0.0 (GitHub Release that holds the .tar.xz)
#   LUMI_BOARD_RUNTIME_VERSION default 1.0.0 (tarball / extract dir name)
#   LUMI_BOARD_RUNTIME_WORKDIR default $HOME
set -euo pipefail

REPO_URL="${LUMI_BOARD_RUNTIME_REPO:-https://github.com/lumi-jlding/test.git}"
REPO_REF="${LUMI_BOARD_RUNTIME_REF:-main}"
RELEASE_TAG="${LUMI_BOARD_RUNTIME_TAG:-v1.0.0}"
VERSION="${LUMI_BOARD_RUNTIME_VERSION:-1.0.0}"
WORKDIR="${LUMI_BOARD_RUNTIME_WORKDIR:-${HOME}}"
TAR_NAME="lumisition-board-runtime-${VERSION}.tar.xz"
DIR_NAME="lumisition-board-runtime-${VERSION}"
REPO_DIR="${WORKDIR}/lumi-jlding-test"
INSTALL_ARGS=("--now")

usage() {
	cat <<'EOF'
Usage: install-board-runtime-from-github.sh [install.sh args...]

Clones/updates github.com/lumi-jlding/test, downloads the board-runtime
release asset if needed, then:

  tar -xJf lumisition-board-runtime-<ver>.tar.xz
  cd lumisition-board-runtime-<ver>
  sudo bash install.sh --now [extra args]

Extra args after the script name are forwarded to install.sh
(e.g. --apps lumi-locomotion). --now is always passed.
EOF
}

die() {
	echo "install-board-runtime-from-github: $*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h|--help) usage; exit 0 ;;
	*) INSTALL_ARGS+=("$1"); shift ;;
	esac
done

command -v git >/dev/null || die "git is required"
command -v curl >/dev/null || die "curl is required"
command -v tar >/dev/null || die "tar is required"
command -v sudo >/dev/null || die "sudo is required"

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

if [[ -d "${REPO_DIR}/.git" ]]; then
	echo "Updating ${REPO_DIR} (${REPO_REF})"
	git -C "${REPO_DIR}" fetch --tags origin
	git -C "${REPO_DIR}" checkout "${REPO_REF}"
	git -C "${REPO_DIR}" pull --ff-only origin "${REPO_REF}" || \
		git -C "${REPO_DIR}" reset --hard "origin/${REPO_REF}"
else
	echo "Cloning ${REPO_URL} -> ${REPO_DIR}"
	git clone --branch "${REPO_REF}" --single-branch "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

if [[ ! -f "${TAR_NAME}" ]]; then
	# Prefer a Release asset so the 90MB package is not forced through git LFS.
	ASSET_URL="https://github.com/lumi-jlding/test/releases/download/${RELEASE_TAG}/${TAR_NAME}"
	echo "Downloading ${ASSET_URL}"
	curl -fL --retry 3 --retry-delay 2 -o "${TAR_NAME}.partial" "${ASSET_URL}" \
		|| die "download failed: ${ASSET_URL}"
	mv -f "${TAR_NAME}.partial" "${TAR_NAME}"
fi

[[ -f "${TAR_NAME}" ]] || die "missing ${TAR_NAME} in ${REPO_DIR}"

echo "Extracting ${TAR_NAME}"
rm -rf "${DIR_NAME}"
tar -xJf "${TAR_NAME}"
[[ -d "${DIR_NAME}" ]] || die "extract did not create ${DIR_NAME}"
[[ -f "${DIR_NAME}/install.sh" ]] || die "missing ${DIR_NAME}/install.sh"

echo "Installing: sudo bash install.sh ${INSTALL_ARGS[*]}"
(
	cd "${DIR_NAME}"
	sudo bash install.sh "${INSTALL_ARGS[@]}"
)

echo "Done. Work dir: ${REPO_DIR}/${DIR_NAME}"
