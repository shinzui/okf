-- | Trust and freshness derivations for OKF v0.2 concepts.
--
-- Everything here is __derived on read and never stored__. Specification §5.3
-- says "Consumers /derive/ a trust tier", and §5.1 says credibility "is
-- /inferred/ from the signals, the same way trust tiers are (§5.3), not
-- stored". Accordingly this module exports plain functions over frontmatter
-- values rather than fields on 'Okf.Bundle.Concept': a stored derivation can go
-- stale relative to the frontmatter it summarises, which the projection
-- contract on @Okf.Bundle.conceptAt@ already forbids. See
-- @docs\/adr\/8-derived-not-stored-trust-and-credibility.md@.
--
-- This module also never reads the clock. 'staleness' takes the current day as
-- an argument so it stays pure and testable against a fixed date, and so that
-- two calls in one run cannot disagree about what "today" is. The command-line
-- tool reads the clock once and passes the day down.
module Okf.Trust
  ( TrustTier (..),
    trustTier,
    renderTrustTier,
    latestVerification,
    Staleness (..),
    staleness,
    renderStaleness,
  )
where

import Data.Text qualified as Text
import Data.Time (Day, defaultTimeLocale, parseTimeM)
import Okf.Actor (isHumanActor)
import Okf.Document (Verification (..))
import Okf.Prelude

-- | A concept's trust tier, lowest to highest, per specification §5.3.
--
-- Tiers are advisory signals, not access control: §5.3 states that "A concept
-- with no trust frontmatter is still consumable; consumers MUST NOT reject it".
-- The 'Ord' instance orders them lowest to highest so callers can compare.
data TrustTier
  = -- | No usable @verified@ entry.
    Unverified
  | -- | Verified by non-@human:@ actors only.
    MachineConfirmed
  | -- | Verified by at least one @human:\<id\>@ actor.
    HumanReviewed
  deriving stock (Generic, Eq, Ord, Show)

-- | Derive a trust tier from a concept's @verified@ entries, per §5.3.
--
-- The @human:@ test comes from 'Okf.Actor.isHumanActor' rather than being
-- re-derived here: §5.3 makes that single test the sole discriminator between
-- the two verified tiers, and two copies of it would eventually disagree.
trustTier :: [Verification] -> TrustTier
trustTier verifications
  | null verifications = Unverified
  | any (isHumanActor . verificationBy) verifications = HumanReviewed
  | otherwise = MachineConfirmed

-- | Render a tier in the specification's own words, so CLI output and
-- documentation match §5.3 for a reader with the specification open.
renderTrustTier :: TrustTier -> Text
renderTrustTier = \case
  Unverified -> "unverified"
  MachineConfirmed -> "machine-confirmed"
  HumanReviewed -> "human-reviewed"

-- | The most recent verification time, implementing §5.2's "'How recently' is
-- the latest @at@". Entries without an @at@ are skipped.
--
-- Compares the raw strings. ISO 8601 datetimes in a fixed-width UTC form sort
-- lexicographically in chronological order, the same shortcut
-- @Okf.Validation@ already takes for log dates. This breaks if a producer
-- writes a non-UTC offset such as @2026-06-25T09:00:00+01:00@, which sorts by
-- its local wall-clock reading rather than its instant. Profiles can require
-- the UTC form with the existing @Rfc3339Utc@ field format.
latestVerification :: [Verification] -> Maybe Text
latestVerification verifications =
  case [occurredAt | Verification {verificationAt = Just occurredAt} <- verifications] of
    [] -> Nothing
    times -> Just (maximum times)

-- | Whether a concept has passed its @stale_after@ date (specification §5.5).
data Staleness
  = -- | @stale_after@ is present and today is before it.
    Fresh
  | -- | Today is on or after @stale_after@, which is carried here.
    Stale !Day
  | -- | @stale_after@ is present but is not a @YYYY-MM-DD@ date. The original
    -- text is preserved so a caller can report it.
    StaleAfterUnparseable !Text
  | -- | No @stale_after@ key, so freshness is unknown rather than assured.
    NoStaleAfter
  deriving stock (Generic, Eq, Show)

-- | Decide staleness against a caller-supplied day.
--
-- Implements §5.5 literally: "A concept is stale when @today >= stale_after@".
-- The comparison is inclusive, so a concept whose @stale_after@ is exactly
-- today is stale.
--
-- A value that does not parse yields 'StaleAfterUnparseable' rather than being
-- treated as fresh. Silently ignoring a malformed freshness deadline is the
-- worst available behaviour: it reports a concept as trustworthy on the
-- strength of a field nobody could read.
staleness :: Day -> Maybe Text -> Staleness
staleness today = \case
  Nothing -> NoStaleAfter
  Just raw ->
    case parseTimeM True defaultTimeLocale "%Y-%m-%d" (Text.unpack raw) of
      Nothing -> StaleAfterUnparseable raw
      Just deadline
        | today >= deadline -> Stale deadline
        | otherwise -> Fresh

-- | Render staleness as a short phrase for command-line output.
renderStaleness :: Staleness -> Text
renderStaleness = \case
  Fresh -> "ok"
  NoStaleAfter -> "ok"
  Stale deadline -> "stale since " <> Text.pack (show deadline)
  StaleAfterUnparseable raw -> "unparseable stale_after " <> raw
