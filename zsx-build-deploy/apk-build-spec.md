# APK Build Specification

> Version 1.0 | 2026-05-26

## 1. Purpose

Define the naming convention and build process for Android APK artifacts produced by this project. The specification ensures every APK is uniquely identifiable, traceable to source code, and sortable by version and build recency.

## 2. Naming Convention

### 2.1 Format

```
<project>-v<semver>-build<N>-<date>.apk
```

Four segments joined by hyphens (`-`). No segment may contain a hyphen internally.

### 2.2 Segments

| # | Segment | Pattern | Example | Rule |
|---|---------|---------|---------|------|
| 1 | **Project** | `[a-z][a-z0-9-]*` | `frances-allen` | Lowercase kebab-case project identifier. Immutable across builds. |
| 2 | **Semantic Version** | `v<major>.<minor>.<patch>` | `v1.1.0` | Follows [Semantic Versioning 2.0.0](https://semver.org). Prefix `v` is mandatory. |
| 3 | **Build Number** | `build<N>` | `build20` | Monotonically increasing integer. Prefix `build` is mandatory. Increments by 1 on each `flutter build apk --release`. |
| 4 | **Build Date** | `<YYYYMMDD>` | `20260526` | UTC+8 calendar date of build execution. Eight digits, zero-padded. |

### 2.3 Example

```
frances-allen-v1.1.0-build20-20260526.apk
```

## 3. Semantic Versioning Policy

### 3.1 Version Bump Rules

| Change Type | Bump | Example |
|-------------|------|---------|
| Breaking API change, major architecture rewrite | MAJOR (`X.0.0`) | `v1.0.0` → `v2.0.0` |
| New feature, new page, new interaction mode | MINOR (`x.Y.0`) | `v1.1.0` → `v1.2.0` |
| Bug fix, patch, hotfix | PATCH (`x.y.Z`) | `v1.1.0` → `v1.1.1` |

### 3.2 Reset Rule

When MAJOR or MINOR is bumped, lower segments reset to zero.

```
v1.1.0 → v2.0.0  (major bump, minor=0, patch=0)
v1.1.0 → v1.2.0  (minor bump, patch=0)
```

Build number is **never reset** — it is globally monotonic.

## 4. Build Number Policy

- Initial value: `build1`
- Increment: +1 per successful `flutter build apk --release`
- If a build fails (compile error, gradle failure), the number is **not** consumed
- The build number is independent of semver — it grows monotonically across all versions
- Purpose: traceability. Given a build number, the exact source commit and artifact can be identified

## 5. Build Date Policy

- Format: `YYYYMMDD` (ISO 8601 basic calendar date)
- Timezone: UTC+8 (CST, local build time)
- Generated via `date +%Y%m%d` at build time
- Zero-padded: January 3 = `20260103`, not `202613`

## 6. Artifact Placement

All APK artifacts are placed in:

```
zsx-build-deploy/
```

The latest build may also be symlinked or copied as:

```
zsx-build-deploy/frances-allen-latest.apk
```

for convenience, but the canonical artifact is always the versioned file.

## 7. Full Build Command

```bash
V="v$(cat version)-build$(<build_number)-$(date +%Y%m%d)"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk \
   zsx-build-deploy/${PROJECT}-${V}.apk
echo $(( $(cat build_number) + 1 )) > build_number
```

Where `version` and `build_number` are project-tracked files.

## 8. Compliance

Every APK delivered to users, testers, or distribution channels MUST follow this specification. Artifacts that do not conform are not considered release candidates.
