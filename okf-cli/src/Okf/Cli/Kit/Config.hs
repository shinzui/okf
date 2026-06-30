-- | Bridge okf configuration to the baikai-kit engine's KitConfig.
module Okf.Cli.Kit.Config
  ( kitConfig,
  )
where

import Baikai.Interactive (InteractiveProvider (..))
import Baikai.Kit.Config (KitConfig (..))
import Okf.Cli.Config (KitSettings (..), OkfConfig (..), OkfProvider (..))

-- | Build the baikai-kit configuration from okf's loaded configuration. The
-- tool name "okf" fixes the on-disk layout for caches, installed assets, and
-- sidecar files.
kitConfig :: OkfConfig -> KitConfig
kitConfig OkfConfig {kit = KitSettings {repoUrl = url, providers = providerList}} =
  KitConfig
    { toolName = "okf",
      repoUrl = url,
      providers = map toInteractive providerList
    }

toInteractive :: OkfProvider -> InteractiveProvider
toInteractive = \case
  ProviderClaude -> InteractiveClaude
  ProviderCodex -> InteractiveCodex
