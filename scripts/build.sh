#!/usr/bin/env bash
# Build one patched upstream dependency.
#
#   scripts/build.sh <component> [out-dir]
#
# Checks the component's submodule out at the commit recorded in this repo,
# applies patches/<component>/*.patch, sets the release version from
# components/<component>.env and builds it with Maven. The result lands in
# out-dir (default: dist/) as <artifactId>-<version>.jar plus a .sha256 file,
# after the shaded-dependency versions listed in the .env file are checked in it.
# No pom is published: consumers resolve the jar alone (both components shade
# or mark optional everything they depend on).
set -euo pipefail

component=${1:?usage: scripts/build.sh <component> [out-dir]}
root=$(cd "$(dirname "$0")/.." && pwd)
out=${2:-$root/dist}
env_file=$root/components/$component.env
[[ -f $env_file ]] || { echo "unknown component: $component" >&2; exit 1; }
# shellcheck source=/dev/null
source "$env_file"   # SUBMODULE, VERSION, ARTIFACT, MODULE, MVN_ARGS, EXPECT_SHADED

src=$root/$SUBMODULE
git -C "$root" submodule update --init --depth 1 "$SUBMODULE"
git -C "$src" reset -q --hard
git -C "$src" clean -qfdx

shopt -s nullglob
patches=("$root"/patches/"$component"/*.patch)
[[ ${#patches[@]} -gt 0 ]] || { echo "no patches for $component" >&2; exit 1; }
for p in "${patches[@]}"; do
  echo "applying $(basename "$p")"
  git -C "$src" apply --whitespace=nowarn "$p"
done

mvn=(mvn -B -ntp -f "$src/pom.xml")
"${mvn[@]}" -q versions:set -DnewVersion="$VERSION" -DgenerateBackupPoms=false -DprocessAllModules=true
# shellcheck disable=SC2086
"${mvn[@]}" ${MODULE:+-pl "$MODULE" -am} $MVN_ARGS package

module_dir=$src${MODULE:+/$MODULE}
jar=$module_dir/target/$ARTIFACT-$VERSION.jar
[[ -f $jar ]] || { echo "expected jar not found: $jar" >&2; exit 1; }

# Shaded dependency check: every "<pom.properties path>=<version>" in
# EXPECT_SHADED must be present in the jar with that exact version.
for entry in $EXPECT_SHADED; do
  path=${entry%=*} want=${entry##*=}
  got=$(unzip -p "$jar" "$path" | sed -n 's/^version=//p')
  [[ $got == "$want" ]] || { echo "shaded check failed: $path is '$got', want '$want'" >&2; exit 1; }
  echo "shaded ok: $path=$got"
done

mkdir -p "$out"
cp "$jar" "$out/$ARTIFACT-$VERSION.jar"
sha256=(sha256sum); command -v sha256sum >/dev/null || sha256=(shasum -a 256)
(cd "$out" && "${sha256[@]}" "$ARTIFACT-$VERSION.jar" > "$ARTIFACT-$VERSION.sha256")
echo "built $out/$ARTIFACT-$VERSION.jar"
