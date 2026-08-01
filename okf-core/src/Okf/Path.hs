-- | The OKF v0.2 path-valued field grammar (specification §6.2).
--
-- Several frontmatter fields name a path or URI: @resource@,
-- @sources[].resource@, and the attested-computation fields @computation@,
-- @executor.resource@, and @attester.resource@. Each accepts an absolute URL, a
-- bundle-relative path beginning with @\/@, or an ordinary relative path.
--
-- Classification is total and offline: it never touches the filesystem and never
-- decides whether a target exists. Deciding that is the caller's job, because
-- what counts as existing depends on what the caller can see. 'Okf.Profile'
-- resolves only @.md@ targets, because it is handed a list of concepts and
-- nothing else.
--
-- Deliberately distinct from 'Okf.Graph.extractConceptLinks', which reads
-- Markdown links out of a concept /body/ and is free to drop anything it does
-- not recognize. A path-valued /field/ is something the author wrote on purpose,
-- so every shape it can take is named here rather than silently ignored.
module Okf.Path
  ( PathReference (..),
    classifyPathReference,
    collapseBundlePath,
    PathResolution (..),
    resolvePathReference,
  )
where

import Control.Monad (foldM)
import Data.Text qualified as Text
import Network.URI (parseURI, uriScheme)
import Okf.ConceptId (ConceptId, conceptIdToFilePath)
import Okf.Prelude
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

-- | What one raw path-valued frontmatter value turned out to be.
data PathReference
  = -- | An absolute URL, carrying its case-folded scheme.
    ExternalUrl !Text
  | -- | A path inside the bundle, collapsed and expressed relative to the
    -- bundle root, with any fragment or query suffix removed.
    BundlePath !FilePath
  | -- | A relative path that climbs above the bundle root.
    EscapesBundle
  | -- | Text that is neither: empty, whitespace, or otherwise unusable.
    MalformedPath
  deriving stock (Generic, Eq, Ord, Show)

-- | Classify one raw value written on the given concept. A relative path is
-- resolved against the concept's own directory, matching how a Markdown link in
-- that concept's body resolves; a value beginning with @\/@ resolves from the
-- bundle root regardless of where the concept lives.
--
-- An absolute URL is recognized by having a URI scheme, so this accepts every
-- scheme rather than the three 'Okf.Graph' treats as external. Whether a given
-- scheme is /permitted/ is a profile question and is decided by the caller.
classifyPathReference :: ConceptId -> Text -> PathReference
classifyPathReference sourceConcept rawValue
  | Text.null trimmed = MalformedPath
  | Just scheme <- absoluteUrlScheme trimmed = ExternalUrl scheme
  | Text.null cleanText = MalformedPath
  | otherwise =
      case collapseBundlePath candidatePath of
        Nothing -> EscapesBundle
        Just [] -> MalformedPath
        Just collapsed -> BundlePath collapsed
  where
    trimmed = Text.strip rawValue
    cleanText = stripUrlSuffix trimmed
    cleanPath = Text.unpack cleanText
    sourceDirectory = FilePath.takeDirectory (conceptIdToFilePath sourceConcept)
    candidatePath
      | "/" `Text.isPrefixOf` cleanText = dropWhile (== '/') cleanPath
      | otherwise = sourceDirectory </> cleanPath

-- | The outcome of resolving a path-valued frontmatter field against a bundle:
-- 'classifyPathReference' plus the one question it deliberately does not answer.
data PathResolution
  = -- | An absolute URL, carrying its case-folded scheme. okf never fetches it,
    -- so this is as resolved as an external target gets.
    ResolvedExternal !Text
  | -- | Names a file the bundle contains, at the given bundle-relative path.
    ResolvedInBundle !FilePath
  | -- | Looks exactly like a bundle path, and the bundle holds no such file.
    DanglingInBundle !FilePath
  | -- | Climbs above the bundle root, so there is nothing in the bundle it
    -- could name.
    UnresolvableEscape
  | -- | Empty, whitespace, or otherwise unusable as either a URL or a path.
    UnresolvableMalformed
  deriving stock (Generic, Eq, Ord, Show)

-- | Resolve one raw path-valued value written on the given concept, asking the
-- supplied predicate whether a bundle-relative path names a file that exists.
--
-- The predicate is a plain function rather than a bundle type so that this
-- module stays below 'Okf.Bundle' in the import graph; a caller holding a
-- 'Okf.Bundle.BundleInventory' passes
-- @flip Okf.Bundle.bundleInventoryMember inventory@.
--
-- Deliberately a thin composition over 'classifyPathReference'. Its value is
-- that the five outcomes are named once, so every caller agrees on what they
-- mean — in particular that an external URL is /resolved/ rather than skipped,
-- and that a path which escapes the bundle is a different finding from one that
-- simply is not there.
resolvePathReference :: (FilePath -> Bool) -> ConceptId -> Text -> PathResolution
resolvePathReference exists sourceConcept rawValue =
  case classifyPathReference sourceConcept rawValue of
    ExternalUrl scheme -> ResolvedExternal scheme
    BundlePath target
      | exists target -> ResolvedInBundle target
      | otherwise -> DanglingInBundle target
    EscapesBundle -> UnresolvableEscape
    MalformedPath -> UnresolvableMalformed

-- | The case-folded scheme of an absolute URL, or 'Nothing' for anything that
-- is not one. A bundle-absolute path such as @\/references\/policy.md@ has no
-- scheme and so is never mistaken for a URL.
absoluteUrlScheme :: Text -> Maybe Text
absoluteUrlScheme rawValue = do
  parsed <- parseURI (Text.unpack rawValue)
  let scheme = Text.toCaseFold (Text.dropWhileEnd (== ':') (Text.pack (uriScheme parsed)))
  if Text.null scheme then Nothing else Just scheme

-- | Fold @.@ and @..@ segments, returning 'Nothing' for a path that climbs above
-- the bundle root. Exported because resolving a bundle-relative path is the same
-- operation wherever it is done, and a second copy would be free to drift.
collapseBundlePath :: FilePath -> Maybe FilePath
collapseBundlePath =
  fmap FilePath.joinPath . foldM step [] . FilePath.splitDirectories
  where
    step [] "." = Just []
    step acc "." = Just acc
    step [] ".." = Nothing
    step acc ".." = Just (init acc)
    step acc segment = Just (acc <> [segment])

-- | Drop a URL fragment or query suffix, so @policy.md#section@ resolves to the
-- same target as @policy.md@.
stripUrlSuffix :: Text -> Text
stripUrlSuffix =
  Text.takeWhile (\character -> character /= '#' && character /= '?')
