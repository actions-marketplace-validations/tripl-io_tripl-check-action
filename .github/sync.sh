#!/usr/bin/env bash
# Mirrors each tripl CLI release's GitHub action into this repository.
#
# For every cli-vX.Y.Z tag of the source repository newer than this
# repository's newest vX.Y.Z tag, and holding ci/github/action.yml, it commits
# that file as action.yml (with its usage comment pointing here), tags the
# commit vX.Y.Z, and moves vX.Y onto it. Releases are taken oldest first, so
# action.yml on main is always the newest one's.
#
#   .github/sync.sh [SOURCE]     SOURCE: a git URL or path (default: tripl on GitHub)
#
# Pushes nothing with DRY_RUN=1.
set -euo pipefail

source_repo="${1:-https://github.com/tripl-io/tripl.git}"
version_re='^[0-9]+\.[0-9]+\.[0-9]+$'

newest="$(git tag --list 'v*' | sed 's/^v//' | grep -E "$version_re" | sort -V | tail -1 || true)"
echo "Newest mirrored release: ${newest:-none}"

releases="$(git ls-remote --tags --refs "$source_repo" 'refs/tags/cli-v*' \
  | sed 's#.*refs/tags/cli-v##' | grep -E "$version_re" | sort -V || true)"

refspecs=()
for version in $releases; do
  if [[ -n "$newest" ]] && [[ "$(printf '%s\n%s\n' "$newest" "$version" | sort -V | tail -1)" == "$newest" ]]; then
    continue # not newer than what is here
  fi
  git fetch --quiet --no-tags --depth=1 "$source_repo" "refs/tags/cli-v$version"
  if ! git cat-file -e "FETCH_HEAD:ci/github/action.yml" 2>/dev/null; then
    echo "cli-v$version has no ci/github/action.yml: skipped"
    continue
  fi
  git show "FETCH_HEAD:ci/github/action.yml" \
    | sed -E 's#tripl-io/tripl/ci/github@cli-v[0-9A-Za-z.]+#tripl-io/tripl-check-action@v'"$version"'#g' \
    > action.yml
  grep -qF "\"$version\" # tripl version" action.yml || {
    echo "cli-v$version: action.yml does not default to $version; refusing to tag it" >&2
    exit 1
  }
  git add action.yml
  git commit --quiet -m "tripl check $version" -m "action.yml from tripl-io/tripl at cli-v$version."
  git tag -a "v$version" -m "tripl check $version"
  git tag -f -a "v${version%.*}" -m "tripl check ${version%.*} (now $version)" >/dev/null
  echo "Mirrored cli-v$version as v$version"
  newest="$version"
  refspecs+=("refs/tags/v$version" "+refs/tags/v${version%.*}")
done

if [[ "${#refspecs[@]}" -eq 0 ]]; then
  echo "Nothing new."
  exit 0
fi
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  echo "DRY_RUN: not pushing."
  exit 0
fi
# Each new vX.Y.Z, and each vX.Y it moved (a later one in the list wins).
git push --atomic origin HEAD:refs/heads/main $(printf '%s\n' "${refspecs[@]}" | awk '!seen[$0]++')
