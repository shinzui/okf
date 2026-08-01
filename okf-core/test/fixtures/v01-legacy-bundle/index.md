# OKF v0.1 legacy fixture bundle

A deliberately unmigrated bundle. It uses the OKF v0.1 `timestamp` key that
v0.2 supersedes with `generated.at`, and declares no `okf_version`, so it is
exactly the shape every bundle written before v0.2 existed still has.

It exists to keep the legacy fallback of
`docs/adr/7-okf-v0-1-legacy-fallback-policy.md` under test. Do not migrate it.

- [tables/](tables/index.md)
