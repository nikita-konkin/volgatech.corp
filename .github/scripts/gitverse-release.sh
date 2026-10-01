#!/usr/bin/env bash
# Copies the GitHub Release $TAG of this repository (the latest when $TAG is
# empty) to the releases of the GitVerse repository $REPO: same tag and name,
# that version's «Что нового» from README.ru.md as the description, and its
# APKs. Whatever is already there stays: running it again adds only what's
# missing. Used by .github/workflows/gitverse-release.yml.
set -euo pipefail

: "${TOKEN:?Secret GITVERSE_TOKEN is not set.}"
: "${REPO:?Variable GITVERSE_REPO is not set.}"
: "${GITHUB_REPOSITORY:?}"
GITHUB_API=${GITHUB_API_URL:-https://api.github.com}
GITVERSE_API=${GITVERSE_API:-https://api.gitverse.ru}
TAG=${TAG:-}
work=$(mktemp -d)

# GitHub: this repository's release, as JSON.
github() {
  curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} \
    -H 'Accept: application/vnd.github+json' \
    "$GITHUB_API/repos/$GITHUB_REPOSITORY/$1"
}

# GitVerse: METHOD PATH [curl options]; sets CODE and BODY.
gitverse() {
  local out
  out=$(curl -sS -X "$1" -H "Authorization: Bearer $TOKEN" \
    -H 'Accept: application/vnd.gitverse.object+json;version=1' \
    -w '\n%{http_code}' "$GITVERSE_API/repos/$REPO${2:+/$2}" "${@:3}")
  CODE=${out##*$'\n'}
  BODY=${out%$'\n'*}
}

fail() {
  echo "::error::$1 (HTTP $CODE): $BODY"
  exit 1
}

if [ -n "$TAG" ]; then which="tags/$TAG"; else which=latest; fi
github "releases/$which" > "$work/release.json" ||
  { echo "::error::No release ${TAG:-at all} on GitHub."; exit 1; }
TAG=$(jq -r .tag_name "$work/release.json")
echo "Release $TAG"

# The version's section of README.ru.md, without its pictures (their paths
# lead nowhere from a release page).
notes=$(awk -v head="## Что нового — $TAG" '
  $0 == head { on = 1; next }
  on && /^## / { exit }
  on && !/^<img / && !/^<br clear/ { print }
' README.ru.md | sed -e '/./,$!d')
if [ -z "$notes" ]; then
  notes="Что нового — в README."
fi
body=$(printf '%s\n\n%s\n\n%s\n' "$notes" \
  'Для 64-битного телефона (почти все современные) — `arm64-v8a`; `app-mail-*` — со встроенным почтовым клиентом.' \
  "Тот же релиз на GitHub: $(jq -r .html_url "$work/release.json")")

gitverse GET "releases/tags/$TAG"
if [ "$CODE" = 200 ]; then
  echo "Already on GitVerse; adding what's missing."
elif [ "$CODE" = 404 ]; then
  # The tag goes on the repository's default branch.
  branch=master
  gitverse GET ""
  if [ "$CODE" = 200 ]; then
    branch=$(jq -r '.default_branch // "master"' <<< "$BODY")
  fi
  # Compact and without a final newline: GitVerse takes a body that ends in
  # a newline for an empty one ("Request body must not be empty").
  jq -ncj --arg tag "$TAG" --arg name "$(jq -r '.name // .tag_name' "$work/release.json")" \
    --arg branch "$branch" --arg body "$body" \
    --argjson pre "$(jq .prerelease "$work/release.json")" \
    '{tag_name: $tag, name: $name, target_commitish: $branch, body: $body,
      draft: false, prerelease: $pre}' > "$work/new.json"
  gitverse POST releases -H 'Content-Type: application/json' \
    --data-binary "@$work/new.json"
  [ "$CODE" = 201 ] || fail "Could not create the release"
  echo "Created on GitVerse."
else
  fail "Could not look up the release"
fi
id=$(jq -r .id <<< "$BODY")
have=$(jq -r '.assets[]?.name' <<< "$BODY")

jq -r '.assets[] | select(.name | endswith(".apk")) | "\(.name)\t\(.browser_download_url)"' \
  "$work/release.json" |
while IFS=$'\t' read -r name url; do
  if grep -qxF "$name" <<< "$have"; then
    echo "  $name: already there"
    continue
  fi
  curl -fsSL -o "$work/$name" "$url"
  gitverse POST "releases/$id/assets?name=$name" -F "attachment=@$work/$name"
  [ "$CODE" = 201 ] || fail "Could not upload $name"
  echo "  $name: uploaded"
  rm "$work/$name"
done

echo "https://gitverse.ru/$REPO/releases/tag/$TAG"
