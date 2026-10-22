# sonarqube-patched-deps

Patched builds of upstream libraries that SonarQube Community Build ships, for
fixes that upstream has merged but not released yet. Upstream code is not
forked: each library is a git submodule pinned to its release tag, and every
change lives in `patches/<component>/`.

| Component | Upstream tag | Patch | Release |
|---|---|---|---|
| `org.mybatis:mybatis` | `mybatis-3.5.19` | shaded ognl 3.4.4 → 3.4.16 (upstream master already uses it) | `mybatis/3.5.19-alauda-1` |
| `com.hazelcast:hazelcast` | `v5.7.0` | shaded Jackson 2.21.2 → 2.22.4 and 3.1.2 → 3.2.3 (upstream master already uses them) | `hazelcast/5.7.0-alauda-1` |

Drop a component (and its consumer override) as soon as upstream releases a
version that contains the fix.

## Build

```
scripts/build.sh mybatis       # -> dist/mybatis-3.5.19-alauda-1.jar
scripts/build.sh hazelcast     # -> dist/hazelcast-5.7.0-alauda-1.jar
```

Requires JDK 21 and Maven. The script applies the patches, sets the version
from `components/<component>.env`, builds, and fails if the shaded versions in
the jar differ from `EXPECT_SHADED`.

## Release

Push a tag `<artifactId>/<version>` (the component name is the artifactId); `.github/workflows/release.yml` builds it
and attaches the jar and its sha256 to a GitHub release:

```
https://github.com/AlaudaDevops/sonarqube-patched-deps/releases/download/<component>/<version>/<artifact>-<version>.jar
```

## Updating

1. Move the submodule to the new upstream tag.
2. Rebase or delete the patches (`git -C <submodule> am ../patches/<component>/*.patch`, then `git format-patch`).

Versions use `-alauda-N` (not `-alauda.N`): hazelcast parses its own version at runtime and rejects a dot in the suffix.
3. Bump `VERSION` in `components/<component>.env`, tag, push.

## License

The components keep their upstream license (Apache-2.0 for both), NOTICE and
copyright headers. The patches here are the complete set of modifications.
