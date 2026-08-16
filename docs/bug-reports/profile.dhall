--| Descriptor for this repository's bug-report bundle.
--
-- Selects the shared `coordination.bugReports` profile out of the okf-profiles
-- catalog, pinned by content hash. That profile requires one defect per Markdown
-- file at the bundle root and the frontmatter keys `type`, `title`,
-- `description`, `generated`, `bugId`, `status`, `severity`, `origin`,
-- `affects`, `affectedVersion`, `observed`, `expected`, and `reproduction`, with
-- `bugId` a unique unpadded `BUG-N` handle.
--
-- A bug report here is a *broken provision claim*: behavior okf already says it
-- has, which observably does not hold. Behavior okf never provided belongs in
-- ../improvement-requests/ instead.
--
-- Validate with:
--
--     okf validate docs/bug-reports \
--       --strict --profile docs/bug-reports/profile.dhall \
--       --profile-enforce --log-enforce
let Profiles =
      https://raw.githubusercontent.com/shinzui/okf-profiles/v0.10.0/package.dhall
        sha256:c6882a5cb6ece28027f5f9d219d323cff64f131b97ecbf536ed54d77263f5edf

in  Profiles.coordination.bugReports
