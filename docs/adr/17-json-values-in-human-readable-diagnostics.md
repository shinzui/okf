# ADR 17: JSON values in human-readable diagnostics

Status: Accepted

Date: 2026-08-16


## Context

A frontmatter value, once parsed, is a `Data.Aeson.Value`. Several diagnostics
have to quote one back to the author, because a message that says a value is
wrong without saying which value it found is not a diagnostic at all. Six
`Okf.Profile.ProfileViolation` constructors carry a raw `Value` for exactly that
purpose — `ValueNotInVocabulary`, `CardinalityMismatch`, `ValueFormatMismatch`,
`MalformedDocumentReference`, `MalformedPathReference`, and
`NestedElementNotRecord` — and `Okf.Cli.renderProfileViolation` prints it. The
remaining twelve carry only `Text` and are not affected by any of this.

Turning a `Value` into `Text` means encoding it and then decoding the encoded
bytes, and the decode step is where the hazard sits. `Data.Aeson.encode` produces
UTF-8 bytes. `Data.ByteString.Lazy.Char8.unpack` produces a `String` by
truncating each byte to a `Char`, which is a Latin-1 decode. Composing the two
expands every multi-byte character into one character per byte, and re-encoding
that as UTF-8 on output doubles or triples it. `東京` — three bytes each — comes
back as `æ±äº¬`.

All six sites did exactly that, from before v0.3.0.0 until this record.
[BUG-1](../bug-reports/1-non-ascii-values-mangled-in-profile-diagnostics.md)
records the defect, its byte-level proof, and its origin: a Japanese place corpus
(`mori://shinzui/jangso-db`) in which essentially every frontmatter value is
non-ASCII, so essentially every vocabulary violation printed an unreadable value.
The bug survived that long because the allowed-values list on the very same
output line is already `[Text]` joined with `Text.intercalate` and always rendered
correctly, so the line looked half-right rather than obviously broken to a reader
working in ASCII.

The `Char8` module is imported in `okf-cli/src/Okf/Cli.hs` as `LazyByteString`
for four legitimate uses — `LazyByteString.putStrLn` on `Aeson.encode` output in
the `--json` paths — and it stays imported for them. That is the standing hazard
this record exists to name: the wrong function is in scope, under a plausible
alias, one autocomplete away from the next diagnostic anyone writes.


## Decision

**Encoded JSON becomes `Text` only by decoding it as UTF-8, never by unpacking it
through a `Char8` module.** In `okf-cli` that is `Okf.Cli.renderJsonValue`:

```haskell
renderJsonValue :: Aeson.Value -> Text
renderJsonValue = Text.Encoding.decodeUtf8Lenient . LazyBytes.toStrict . Aeson.encode
```

All six diagnostics call it. `okf-core` reached the same composition
independently, in the `jsonText` helper inside `Okf.Query.scalarText`, so the two
packages now share an idiom rather than diverging.

**The decoder is the lenient one.** `decodeUtf8` would be total on
`Aeson.encode` output, which is UTF-8 by construction, and BUG-1 suggested it on
that reasoning. The reasoning is correct and the choice is still wrong: this code
is the renderer that reports what went wrong with a document, and `decodeUtf8`
throws an imprecise exception on invalid input. If the premise about
`Aeson.encode` were ever falsified, strict decoding would turn a cosmetic defect
into a crash in the one code path whose job is to explain other failures.
`decodeUtf8Lenient` substitutes U+FFFD and cannot fail.

**The helper is module-private to `okf-cli` and is not promoted into `okf-core`.**
Every affected site is in one module, and `okf-core`'s equivalent is a
`where`-bound helper that was already correct. Sharing it would mean touching and
re-versioning `okf-core` for a defect confined to the CLI. A third caller makes
promotion worth doing; two do not.

**The `Data.ByteString.Lazy.Char8` alias stays, for byte-level writes only.**
Writing `Aeson.encode` output to a handle with `LazyByteString.putStrLn` involves
no decode step and has always been correct — which is why `okf ... --json` was
never affected by this defect. Removing the import would mean rewriting four
working call sites for no behavioural gain. It stays, and this record is what
warns the next reader what `unpack` on it would do.


## Consequences

A new diagnostic that quotes a frontmatter value must call `renderJsonValue`.
Reaching for `LazyByteString.unpack` because it is already imported reintroduces
BUG-1 exactly.

`testNonAsciiValuesSurviveDiagnostics` in `okf-cli/test/Main.hs` pins all six
existing sites by rendering each with a Japanese value and asserting the value
survives. It asserts the whole `ValueNotInVocabulary` line as well as the
substring, and the second assertion is not redundant: the mangled vocabulary line
still *contains* 東京, in its correctly-rendered allowed-values half, so a
substring check alone passes on the broken output for the headline case. Any
similar test must assert on the `found:` half specifically or on the whole line.
The test needs `aeson` in the test suite's `build-depends`, and it reaches
`renderProfileViolation` because that function is exported from `Okf.Cli` for it —
for the same reason `computationReport` and `renderProfileDetail` are.

Validation behaviour is unchanged and no exit code moves: the same documents are
accepted and rejected, only the wording of the message differs. `--json` output
is byte-identical to before.

This record says nothing about how `okf` writes to a handle, only about how it
turns bytes into `Text`. Nothing here constrains the `--json` paths, and nothing
here is a claim about terminal encoding: the defect was diagnosed and its fix
verified with `xxd` on the emitted bytes, precisely because a terminal, a font,
or a locale can each mangle correct output on their own.
