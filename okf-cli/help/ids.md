DOCUMENT IDS

A concept's canonical identity is its path -- tables/orders.md is the concept
tables/orders. A document ID is a second, shorter handle such as ADR-7 that a
house profile can require, for corpora where people cite decisions and requests
by number.

Document IDs are entirely a profile convention. Core OKF has no such notion, so
a bundle validated without a profile never gains or needs one.

DECLARING THEM IN A PROFILE

  A profile names the frontmatter key that holds the handle, and gives selected
  type rules the prefix their concepts must use:

    idField  = Some "docId"        -- profile-wide: which key holds the handle
    idPrefix = Some "ADR"          -- on a TypeRule: which prefix its concepts use

  Concepts of that type must then carry a canonical handle -- PREFIX-N, with
  the prefix compared case-sensitively. Duplicate handles are reported as a
  profile deviation.

  A profile with no idField, or a type rule with no idPrefix, simply performs
  no document-ID checks.

ALLOCATING AND LISTING

  okf id list [BUNDLE] --profile PROFILE.dhall
  okf id next [BUNDLE] PREFIX --profile PROFILE.dhall

  Both subcommands require a profile, because the profile is what declares the
  ID field and the allowed prefixes. Neither writes to the bundle. With one
  positional after id next, it is PREFIX and BUNDLE is selected interactively;
  with two, they keep the explicit BUNDLE PREFIX meaning.

    okf id list decisions --profile profiles/decisions.dhall
    ADR-1  decisions/use-markdown
    ADR-2  decisions/use-postgres
    ADR-3  decisions/adopt-okf

    okf id next decisions ADR --profile profiles/decisions.dhall
    ADR-4

  id list prints "<handle>  <concept-id>" in prefix-and-number order and omits
  malformed values. id next returns one more than the highest number for the
  requested prefix; it does not fill gaps, so a deleted ADR-2 is never reissued.

  An undeclared prefix, or a profile with no idField, is a hard error.

RESOLVING ONE

  okf show BUNDLE ADR-7
  okf show BUNDLE ADR-7 --profile PROFILE.dhall

  Path lookup runs first, because the path is the canonical OKF identity. If no
  path matches and the argument has document-ID form, show searches frontmatter
  for that exact handle and prints both identities:

    id: decisions/use-postgres
    docId: ADR-2
    type: Decision Record

  --profile narrows the search to the profile's idField. Without it, every
  string-valued frontmatter key is considered, which is why resolution works
  without a profile but is less precise. Duplicate handles are rejected as
  ambiguous and every matching concept ID is listed.

REFERENCING ONE FROM ANOTHER CONCEPT

  A profile field rule may declare that a frontmatter value holds a handle
  rather than free text, so a stale reference is caught:

    field.localReference "supersedes" "ADR"

  okf then checks that the handle exists in this bundle and belongs to a
  profile-governed concept. See "okf help profiles" for external URI schemes,
  self-reference, and the DocumentHandle field format.

SEE ALSO

  okf help profiles     idField, idPrefix, and reference rules in full.
  okf help format       Concept IDs, the canonical identity.
  okf help concepts     `okf concepts BUNDLE --show docId` shows each handle
                        beside its type and title, where `okf id list` gives
                        the handle and concept ID alone.
