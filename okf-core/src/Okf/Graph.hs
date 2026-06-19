-- | Markdown link extraction and concept graph construction.
module Okf.Graph
  ( Edge (..),
    Graph (..),
    Node (..),
    buildGraph,
    extractConceptLinks,
    danglingReferences,
    duplicateConceptIds,
  )
where

import CMarkGFM qualified
import Control.Monad (foldM)
import Data.Aeson (ToJSON (..), object, (.=))
import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Okf.Bundle
import Okf.ConceptId
import Okf.Document (body)
import Okf.Prelude hiding ((.=))
import System.FilePath ((</>))
import System.FilePath qualified as FilePath

-- | A graph node for one concept.
data Node = Node
  { id :: !ConceptId,
    label :: !Text,
    type_ :: !Text,
    description :: !(Maybe Text),
    resource :: !(Maybe Text),
    tags :: ![Text]
  }
  deriving stock (Generic, Eq, Show)

-- | A directed concept-to-concept link.
data Edge = Edge
  { source :: !ConceptId,
    target :: !ConceptId
  }
  deriving stock (Generic, Eq, Ord, Show)

-- | Bundle graph data with presentation-free nodes and edges.
data Graph = Graph
  { nodes :: ![Node],
    edges :: ![Edge]
  }
  deriving stock (Generic, Eq, Show)

instance ToJSON Node where
  toJSON Node {id = nodeId, label = nodeLabel, type_ = nodeType, description = nodeDescription, resource = nodeResource, tags = nodeTags} =
    object
      [ "id" .= nodeId,
        "label" .= nodeLabel,
        "type" .= nodeType,
        "description" .= nodeDescription,
        "resource" .= nodeResource,
        "tags" .= nodeTags
      ]

instance ToJSON Edge where
  toJSON Edge {source, target} =
    object
      [ "source" .= source,
        "target" .= target
      ]

instance ToJSON Graph where
  toJSON Graph {nodes, edges} =
    object
      [ "nodes" .= nodes,
        "edges" .= edges
      ]

-- | Build a graph, excluding links whose targets are not known concepts.
buildGraph :: [Concept] -> Graph
buildGraph concepts =
  Graph
    { nodes = conceptNode <$> sortedConcepts,
      edges = Set.toAscList knownEdges
    }
  where
    sortedConcepts = List.sortOn (renderConceptId . conceptIdOf) concepts
    knownIds = Set.fromList (conceptIdOf <$> concepts)
    knownEdges =
      Set.fromList
        [ Edge {source = conceptIdOf concept, target}
        | concept <- concepts,
          target <- extractConceptLinks concept,
          target `Set.member` knownIds
        ]

-- | Extract OKF concept links from a concept body.
extractConceptLinks :: Concept -> [ConceptId]
extractConceptLinks concept =
  foldMap (resolveLink concept) (extractMarkdownLinks (body (conceptDocument concept)))

-- | Every @(source, target)@ pair where a document links to a @.md@ concept ID
-- that is not present in the bundle. These are the edges 'buildGraph' silently
-- drops. An empty list means every internal link resolves to a real concept.
danglingReferences :: [Concept] -> [(ConceptId, ConceptId)]
danglingReferences concepts =
  [ (conceptIdOf concept, target)
  | concept <- concepts,
    target <- extractConceptLinks concept,
    not (target `Set.member` knownIds)
  ]
  where
    knownIds = Set.fromList (conceptIdOf <$> concepts)

-- | Concept IDs that appear more than once in a concept list. Always empty for
-- a bundle read from disk (paths are unique) but possible for an in-memory
-- producer assembling concepts before writing.
duplicateConceptIds :: [Concept] -> [ConceptId]
duplicateConceptIds concepts =
  [ conceptId
  | (conceptId, count) <- Map.toList counts,
    count > (1 :: Int)
  ]
  where
    counts = Map.fromListWith (+) [(conceptIdOf concept, 1) | concept <- concepts]

conceptNode :: Concept -> Node
conceptNode concept =
  Node
    { id = conceptIdOf concept,
      label = fromMaybe (renderConceptId (conceptIdOf concept)) (conceptTitle concept),
      type_ = conceptType concept,
      description = conceptDescription concept,
      resource = conceptResource concept,
      tags = conceptTags concept
    }

extractMarkdownLinks :: Text -> [Text]
extractMarkdownLinks markdown =
  walk (CMarkGFM.commonmarkToNode [] [] markdown)
  where
    walk (CMarkGFM.Node _ nodeType childNodes) =
      case nodeType of
        CMarkGFM.LINK url _title -> [url]
        _ -> foldMap walk childNodes

resolveLink :: Concept -> Text -> [ConceptId]
resolveLink concept rawUrl
  | isExternalUrl rawUrl = []
  | FilePath.takeExtension cleanPath /= ".md" = []
  | otherwise = maybe [] (either (const []) pure . conceptIdFromFilePath) bundleRelativePath
  where
    cleanPath = Text.unpack (stripUrlSuffix rawUrl)
    sourceDirectory = FilePath.takeDirectory (conceptIdToFilePath (conceptIdOf concept))
    bundleRelativePath
      | "/" `Text.isPrefixOf` rawUrl = collapseBundlePath (dropWhile (== '/') cleanPath)
      | otherwise = collapseBundlePath (sourceDirectory </> cleanPath)

stripUrlSuffix :: Text -> Text
stripUrlSuffix =
  Text.takeWhile (\char -> char /= '#' && char /= '?')

isExternalUrl :: Text -> Bool
isExternalUrl rawUrl =
  let lower = Text.toLower rawUrl
   in "http://" `Text.isPrefixOf` lower
        || "https://" `Text.isPrefixOf` lower
        || "mailto:" `Text.isPrefixOf` lower

collapseBundlePath :: FilePath -> Maybe FilePath
collapseBundlePath =
  fmap FilePath.joinPath . foldM step [] . FilePath.splitDirectories
  where
    step [] "." = Just []
    step acc "." = Just acc
    step [] ".." = Nothing
    step acc ".." = Just (init acc)
    step acc segment = Just (acc <> [segment])
