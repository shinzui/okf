{-# LANGUAGE PackageImports #-}

-- | Project-wide prelude for okf-core. Re-exports the common project
--   vocabulary while keeping generic-lens label instances local to modules
--   that explicitly opt into them.
module Okf.Prelude
  ( module X,
    module Control.Lens,

    -- * Generic-lens vocabulary
    module Data.Generics.Product,
    module Data.Generics.Sum,
  )
where

import "aeson" Data.Aeson as X (FromJSON, ToJSON, Value (..))
import "base" Control.Applicative as X ((<|>))
import "base" Control.Monad as X (unless, void, when)
import "base" Data.Bifunctor as X (first)
import "base" Data.List.NonEmpty as X (NonEmpty (..))
import "base" Data.Maybe as X (fromMaybe, isJust, isNothing)
import "base" Data.Traversable as X (for)
import "base" GHC.Generics as X (Generic)
import "generic-lens" Data.Generics.Product
import "generic-lens" Data.Generics.Sum
import "lens" Control.Lens
import "text" Data.Text as X (Text)
