#!/bin/sh
# Assemble the thin Linux launcher bundle for a release.
#
#   scripts/build-linux-bundle.sh <tag>
#
# Produces (relative to repo root):
#   dist/Telemachus-linux-<tag>.tar.gz   — the repo source at <tag> plus the
#                                          self-contained start-linux.sh launcher
#                                          (host provides Python; no venv bundled)
#   dist/SHA256SUMS                       — checksum for the tarball
#
# "Thin" = we ship the app source + launcher, NOT a bundled Python/venv. The
# launcher creates the venv on first run (mirrors start-macos.sh). The archive
# is just `git archive` of the tagged tree, so it is byte-reproducible and there
# is nothing per-release to maintain by hand.
set -eu

TAG="${1:?usage: build-linux-bundle.sh <tag>}"
PREFIX="telemachus-${TAG}"
OUT="Telemachus-linux-${TAG}.tar.gz"

mkdir -p dist
# Archive the current checkout (HEAD = the tagged commit in CI). The launcher
# scripts are tracked, so they are included automatically with their +x bits.
git archive --format=tar --prefix="${PREFIX}/" HEAD | gzip -9 >"dist/${OUT}"

# Checksum (run from dist/ so the file paths in SHA256SUMS are bare names).
cd dist
sha256sum "${OUT}" >SHA256SUMS

echo "Built dist/${OUT}"
cat SHA256SUMS
