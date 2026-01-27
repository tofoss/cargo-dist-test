#!/usr/bin/zsh
set -euo pipefail

command -v cargo >/dev/null
command -v jq >/dev/null
command -v git >/dev/null
command -v sed >/dev/null

git diff --quiet || {
  echo "working tree dirty, commit or stash your changes first"
  exit 1
}

previous_version=$(
  cargo metadata --no-deps --format-version 1 \
    | jq -r '.packages[0].version'
)

version_type=$1

if [[ "$version_type" != "patch" && "$version_type" != "minor" && "$version_type" != "major" ]]; then
    echo "usage: $0 {patch|minor|major}" >&2
    exit 2  
fi

IFS='.' read -r major minor patch <<< "$previous_version"

if [[ -z "$major" || -z "$minor" || -z "$patch" ]]; then
  echo "invalid version $previous_version"
  exit 2
fi

if [[ "$version_type" == "patch" ]]; then
    patch=$((patch + 1))
fi

if [[ "$version_type" == "minor" ]]; then
    minor=$((minor + 1))
    patch=0
fi

if [[ "$version_type" == "major" ]]; then
    major=$((major + 1))
    minor=0
    patch=0
fi

next_version="$major.$minor.$patch"

if git rev-parse "v$next_version" >/dev/null 2>&1; then
  echo "tag v$next_version already exists" >&2
  exit 3
fi

printf "Create and push release v%s? [y/N] " "$next_version"
read -r reply
case "$reply" in
  [yY]|[yY][eE][sS]) ;;
  *) echo "Aborted"; exit 1 ;;
esac

sed -i.bak -E "0,/^(version[[:space:]]*=[[:space:]]*\")([^\"]+)(\")/s//\1${next_version}\3/" Cargo.toml
sed -i.bak "s/${previous_version//./\\.}/${next_version}/" README.md

rm Cargo.toml.bak README.md.bak

git add README.md Cargo.toml
git commit -m "chore: create release $next_version"
git tag "v$next_version"
git push
git push --tags
