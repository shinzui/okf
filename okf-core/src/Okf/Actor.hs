-- | The OKF v0.2 actor convention (specification §7).
--
-- Fields that record an identity — @generated.by@, @verified[].by@, and
-- @sources[].author@ — all carry an /actor/: a short string naming who or what
-- acted. The specification defines exactly three shapes, and consumers that
-- classify trust (§5.3) key off the @human:@ prefix, so the prefix test lives
-- here once rather than being re-derived by each reader.
module Okf.Actor
  ( Actor (..),
    parseActor,
    renderActor,
    isHumanActor,
  )
where

import Data.Text qualified as Text
import Okf.Prelude

-- | An actor as defined by OKF v0.2 specification §7.
--
-- 'parseActor' is total: text matching none of the three shapes becomes
-- 'UnclassifiedActor' rather than a parse failure, because §11 forbids
-- rejecting a document for a malformed optional field. Reporting an
-- unclassified actor is a validation decision, not a parsing one.
data Actor
  = -- | @human:\<id\>@ per specification §7, carrying the id.
    HumanActor !Text
  | -- | @process:\<id\>@ per specification §7, carrying the id.
    ProcessActor !Text
  | -- | @\<producer\>/\<version\>@ per specification §7, carrying producer then version.
    ProducerActor !Text !Text
  | -- | Text matching none of the three shapes, preserved verbatim.
    UnclassifiedActor !Text
  deriving stock (Generic, Eq, Ord, Show)

-- | Classify an actor string. Never fails.
--
-- The @human:@ and @process:@ prefixes are matched before the @\/@ split and
-- matching is case-sensitive, because §7 writes them in lower case and §5.3
-- makes the @human:@ test the sole discriminator between trust tiers. A value
-- such as @Human:ahormati@ is therefore 'UnclassifiedActor'.
--
-- @'renderActor' . 'parseActor'@ is the identity on every input.
parseActor :: Text -> Actor
parseActor raw
  | Just actorId <- Text.stripPrefix "human:" raw, not (Text.null actorId) = HumanActor actorId
  | Just actorId <- Text.stripPrefix "process:" raw, not (Text.null actorId) = ProcessActor actorId
  | (producer, versionWithSlash) <- Text.breakOn "/" raw,
    Just version <- Text.stripPrefix "/" versionWithSlash,
    not (Text.null producer),
    not (Text.null version) =
      ProducerActor producer version
  | otherwise = UnclassifiedActor raw

-- | Render an actor back to the text a producer wrote. Inverse of 'parseActor'.
renderActor :: Actor -> Text
renderActor = \case
  HumanActor actorId -> "human:" <> actorId
  ProcessActor actorId -> "process:" <> actorId
  ProducerActor producer version -> producer <> "/" <> version
  UnclassifiedActor raw -> raw

-- | Whether the actor is a person. Specification §5.3 makes this the sole
-- discriminator between the machine-confirmed and human-reviewed trust tiers.
isHumanActor :: Actor -> Bool
isHumanActor = \case
  HumanActor _ -> True
  _ -> False
