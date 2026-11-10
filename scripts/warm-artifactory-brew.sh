#!/usr/bin/env bash
# Warm Artifactory's ghcr.io proxy (docker-ghcr-remote) for Homebrew bottles.
#
# Artifactory only serves a bottle blob after the platform manifest that
# references it has been pulled through the proxy, but Homebrew skips that
# manifest and requests the blob directly. Pulling every platform manifest of
# each bottle once makes the blobs available to all Artifactory users.
#
# Targets the formulae in packages/Brewfile plus their Linux (x86_64/arm64)
# and host dependencies, or the formulae given as arguments. Re-run after
# `brew update` brings new versions or bottle rebuilds.
#
# Usage: scripts/warm-artifactory-brew.sh [formula ...]
# Requires ARTIFACTORY_URL / ARTIFACTORY_USER / ARTIFACTORY_TOKEN, brew, curl
# and jq. ARTIFACTORY_URL may be "host", "https://host" or
# "https://host/artifactory".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/../packages/Brewfile"

: "${ARTIFACTORY_URL:?ARTIFACTORY_URL is not set}"
: "${ARTIFACTORY_USER:?ARTIFACTORY_USER is not set}"
: "${ARTIFACTORY_TOKEN:?ARTIFACTORY_TOKEN is not set}"
for cmd in brew curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required." >&2; exit 1; }
done
export HOMEBREW_NO_ENV_HINTS=1

artifactory_url="${ARTIFACTORY_URL%/}"
[[ "$artifactory_url" == *://* ]] || artifactory_url="https://$artifactory_url"
[[ "$artifactory_url" == */artifactory ]] || artifactory_url="$artifactory_url/artifactory"
ARTIFACTORY_HOST="${artifactory_url#*://}"
ARTIFACTORY_HOST="${ARTIFACTORY_HOST%%/*}"
REGISTRY="$artifactory_url/api/docker/docker-ghcr-remote/v2/homebrew/core"

# Credentials go through a netrc file descriptor so they never show up in argv.
af_curl() {
  curl -fsS --max-time 300 \
    --netrc-file <(printf 'machine %s login %s password %s\n' \
      "$ARTIFACTORY_HOST" "$ARTIFACTORY_USER" "$ARTIFACTORY_TOKEN") \
    "$@"
}

if (($#)); then
  roots=("$@")
else
  roots=()
  while IFS= read -r f; do roots+=("$f"); done \
    < <(sed -nE 's/^brew "([^"]+)".*/\1/p' "$BREWFILE")
fi

formulae=()
while IFS= read -r f; do formulae+=("$f"); done < <(
  {
    printf '%s\n' "${roots[@]}"
    brew deps --union "${roots[@]}" 2>/dev/null
    brew deps --union --os=linux --arch=intel "${roots[@]}" 2>/dev/null
    brew deps --union --os=linux --arch=arm "${roots[@]}" 2>/dev/null
  } | sort -u
)

# name, image path, tag. The OCI tag is pkg_version plus "-<rebuild>"; the
# image path replaces "@" with "/" and "+" with "x" (see github_packages.rb).
targets="$(brew info --json=v2 "${formulae[@]}" | jq -r '
  .formulae[] | select(.bottle.stable) |
  [ .name,
    (.name | gsub("@"; "/") | gsub("\\+"; "x")),
    ( .versions.stable
      + (if .revision > 0 then "_\(.revision)" else "" end)
      + (if (.bottle.stable.rebuild // 0) > 0 then "-\(.bottle.stable.rebuild)" else "" end) )
  ] | @tsv')"

failed=0
while IFS=$'\t' read -r name image tag; do
  if ! index="$(af_curl -H 'Accept: application/vnd.oci.image.index.v1+json' \
    "$REGISTRY/$image/manifests/$tag")"; then
    printf '✘ %s %s: index not found\n' "$name" "$tag"
    failed=$((failed + 1))
    continue
  fi

  ok=()
  ng=()
  while IFS=$'\t' read -r manifest platform blob; do
    if af_curl -o /dev/null -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
        "$REGISTRY/$image/manifests/$manifest" \
      && af_curl -o /dev/null -I "$REGISTRY/$image/blobs/sha256:$blob"; then
      ok+=("$platform")
    else
      ng+=("$platform")
    fi
  done < <(jq -r '.manifests[] | [
      .digest,
      # e.g. "1.8.2.arm64_tahoe.1": the bottle tag is the part starting with a letter.
      (.annotations["org.opencontainers.image.ref.name"] | split(".") | map(select(test("^[a-z]"))) | last),
      .annotations["sh.brew.bottle.digest"]
    ] | @tsv' <<<"$index")

  if ((${#ng[@]})); then
    printf '✘ %s %s: failed %s\n' "$name" "$tag" "${ng[*]}"
    failed=$((failed + 1))
  else
    printf '✔ %s %s: %s\n' "$name" "$tag" "${ok[*]}"
  fi
done <<<"$targets"

if ((failed)); then
  echo "$failed formula(e) could not be fully warmed." >&2
  exit 1
fi
