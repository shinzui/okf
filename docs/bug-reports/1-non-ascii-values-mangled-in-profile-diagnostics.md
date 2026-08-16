---
type: Bug Report
title: Profile diagnostics render non-ASCII frontmatter values as mojibake
description: Six profile diagnostics print the offending value by unpacking Aeson's UTF-8 output with Data.ByteString.Lazy.Char8, so every non-ASCII value is displayed as Latin-1 mojibake.
bugId: BUG-1
status: fixed
severity: cosmetic
fixedVersion: unreleased
resolution: >-
  The six diagnostics now decode Aeson's encoded bytes as UTF-8 through a shared
  renderJsonValue helper instead of unpacking them as Latin-1, and a regression
  test in okf-cli/test/Main.hs pins all six.
origin: mori://shinzui/jangso-db
affects: mori://shinzui/okf
affectedVersion: 0.6.0.0
observed: >-
  A rejected value of 東京 is printed as æ±äº¬, while the allowed-values list on the
  same output line renders correctly. The mangling is in the emitted bytes, not in
  the terminal.
expected: >-
  The value renders as the author wrote it — 東京 — as the allowed-values list in
  the same message already does.
reproduction:
  - Create a bundle directory containing an index.md declaring okf_version "0.2".
  - Add a concept document whose frontmatter sets a field to a non-ASCII value outside its vocabulary, for example `prefecture: 東京`.
  - Write a profile declaring that field with `allowedValues = [ "東京都", "京都府" ]` and `cardinality = Scalar`.
  - Run `okf validate <bundle> --profile <profile>.dhall --profile-enforce`.
  - Read the ValueNotInVocabulary line, comparing the bracketed allowed list against the value after `found:`.
generated:
  by: human:shinzui
  at: 2026-08-16T00:00:00Z
reviews:
  - kind: model
    reviewer: claude-opus-5
    reviewed_at: "2026-08-16T00:00:00Z"
    document_timestamp: "2026-08-16T00:00:00Z"
    scope: technical-accuracy
    outcome: approved
    provider: anthropic
    model: claude-opus-5
    effort: high
    context: >-
      Reproduced against okf v0.6.0.0 with a self-contained three-file bundle,
      confirmed at byte level with xxd rather than by reading terminal output,
      and traced to the six call sites in okf-cli/src/Okf/Cli.hs and to the
      Data.ByteString.Lazy.Char8 import at line 38. Origin of the observation is
      a Japanese place corpus in which almost every frontmatter value is
      non-ASCII.
verified:
  by: human:shinzui
  at: 2026-08-16T00:00:00Z
---

# Profile diagnostics render non-ASCII frontmatter values as mojibake

## What happens

Six profile diagnostics print the offending frontmatter value. All six render any non-ASCII value as
Latin-1 mojibake. The bug is visible in a single line of output, because the *allowed values* on that
same line render correctly while the *found* value does not:

```text
profile: bad: frontmatter value at prefecture must be one of [東京都, 京都府], found: "æ±äº¬"
```

That asymmetry is the whole diagnosis. A terminal, locale, or font problem would corrupt both halves
of the line; only one half is corrupt, so the corruption is in the bytes okf emits.

## Proof that it is the emitted bytes

Piping the same line through `xxd` settles it without relying on how anything renders:

```text
00000030: 7374 2062 6520 6f6e 6520 6f66 205b e69d  st be one of [..
00000040: b1e4 baac e983 bd2c 20e4 baac e983 bde5  ......., .......
00000050: ba9c 5d2c 2066 6f75 6e64 3a20 22c3 a6c2  ..], found: "...
00000060: 9dc2 b1c3 a4c2 bac2 ac22 0a              .........".
```

The allowed list contains `e69d b1  e4ba ac  e983 bd`, which is 東京都 correctly encoded as UTF-8.
The found value contains `c3a6 c29d c2b1 c3a4 c2ba c2ac`, which is the UTF-8 encoding of the six code
points U+00E6 U+009D U+00B1 U+00E4 U+00BA U+00AC — that is, the six bytes `e6 9d b1 e4 ba ac` of 東京
each promoted to a code point of its own. The value has been read as Latin-1 and re-encoded as UTF-8.

## Cause

`okf-cli/src/Okf/Cli.hs` imports the `Char8` variant of lazy `ByteString` at line 38:

```haskell
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
```

`Data.ByteString.Lazy.Char8.unpack` produces a `String` by truncating each byte to a `Char`, which is
a Latin-1 decode. `Aeson.encode` produces UTF-8 bytes. Composing them and re-packing into `Text`
therefore reinterprets every multi-byte UTF-8 sequence as a run of Latin-1 characters:

```haskell
Text.pack (LazyByteString.unpack (Aeson.encode actual))
```

That expression appears six times, at lines 2172, 2182, 2190, 2211, 2242, and 2256, in the renderers
for `ValueNotInVocabulary`, `CardinalityMismatch`, `ValueFormatMismatch`, `MalformedDocumentReference`,
`MalformedPathReference`, and `NestedElementNotRecord`.

The allowed-values list escapes the bug because it is already `[Text]` and is joined with
`Text.intercalate` rather than round-tripped through `String`.

The JSON output paths are **not** affected. Lines 915 and 977 use `LazyByteString.putStrLn` directly
on `Aeson.encode`, which writes the raw bytes to the handle without a decode step, so `--json` output
is correct UTF-8. The defect is confined to the human-readable renderer.

## Suggested fix

Decode the encoded bytes as UTF-8 rather than unpacking them as `Char8`. One import and a helper
covers all six sites:

```haskell
import Data.ByteString.Lazy qualified as LazyBytes
import Data.Text.Encoding qualified as Text.Encoding

renderJsonValue :: Aeson.Value -> Text
renderJsonValue = Text.Encoding.decodeUtf8 . LazyBytes.toStrict . Aeson.encode
```

`decodeUtf8` is total on `Aeson.encode` output, which is UTF-8 by construction, so no lenient variant
is needed. `Data.ByteString.Lazy.Char8` remains correct for the two `putStrLn` call sites and can stay
imported for them.

A regression test belongs beside the existing profile-diagnostic tests: assert that rendering a
`ValueNotInVocabulary` whose value is a non-ASCII string yields that string unchanged.

## Why this is graded cosmetic rather than degraded

Validation itself is entirely correct. The right documents are accepted and rejected, the exit code is
right, `--json` output is right, and no data is altered. Only the human-readable message is wrong,
which is the profile's definition of `cosmetic` — "the output reads wrong; the behavior underneath is
right".

That grading understates how much it costs a corpus that is mostly non-ASCII, though, and the grading
scale is deliberately about consequence rather than about priority. In the corpus that found this —
a Japanese place model where prefectures, municipalities, colloquial areas, cuisine genres, and
Michelin grades are all Japanese — essentially *every* vocabulary violation prints an unreadable
value, so the diagnostic that exists to say what was wrong cannot say it. The workaround, until this
is fixed, is to read the `must be one of […]` list, which renders correctly, and compare it against
the document by eye rather than trusting the `found:` half.

## Fixed

Fixed by [ExecPlan 57](../plans/57-render-non-ascii-frontmatter-values-correctly-in-profile-diagnostics.md),
which took the suggested fix with one change: the decoder is
`Text.Encoding.decodeUtf8Lenient` rather than the strict `decodeUtf8` suggested
above. The reasoning above — that `decodeUtf8` is total on `Aeson.encode` output —
is correct, but this is the renderer that reports what went wrong with a
document, and a partial function there would turn a cosmetic defect into a crash
in the diagnostic path if the premise were ever falsified. `okf-core` had already
made the same choice for the same operation in `Okf.Query.scalarText`. The
standing constraint is recorded as
[ADR 17](../adr/17-json-values-in-human-readable-diagnostics.md).

## Not a regression

The expression has been present since before v0.3.0.0 — `git log -S` puts its earliest introduction at
`v0.3.0.0~9`, in the commit that first enforced field and value vocabularies. There is no release in
which this rendered correctly, so `lastWorkingVersion` is deliberately omitted rather than recorded as
`unknown`.
