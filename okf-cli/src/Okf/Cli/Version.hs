{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}

-- | Version reporting for the @okf@ CLI.
--
-- The short git commit hash is resolved at build time from one of two sources:
--
--   * @cabal build@: the @.git/@ directory is present, so the Template Haskell
--     splice 'tGitInfoCwdTry' reads it directly.
--   * @nix build@: @.git/@ is stripped, so the hash is injected by the Nix
--     expression as the CPP macro @GIT_HASH@ (see @nix/haskell.nix@).
--
-- If neither source is available (e.g. a source tarball), the hash is omitted.
module Okf.Cli.Version
  ( appVersion,
    appVersionWithGit,
    gitCommitShort,
  )
where

import Data.Text (Text, pack)
import Data.Version (showVersion)
import GitHash (GitInfo, giHash, tGitInfoCwdTry)
import Paths_okf_cli (version)

-- | Base package version from @okf-cli.cabal@, e.g. @"0.1.0.0"@.
appVersion :: Text
appVersion = pack (showVersion version)

-- | Git info read at compile time from @.git/@ in the current working directory.
-- 'Right' when building inside a git checkout, 'Left' with a message otherwise.
gitInfo :: Either String GitInfo
gitInfo = $$tGitInfoCwdTry

-- | Fallback hash injected by Nix via @-DGIT_HASH="..."@ when @.git/@ is absent.
nixGitHash :: Maybe Text
#ifdef GIT_HASH
nixGitHash = Just GIT_HASH
#else
nixGitHash = Nothing
#endif

-- | Short git commit hash (first 7 characters). Prefers the compile-time @.git/@
-- read, then the Nix-injected macro, then 'Nothing'.
gitCommitShort :: Maybe Text
gitCommitShort = case gitInfo of
  Right gi -> Just (pack (take 7 (giHash gi)))
  Left _ -> nixGitHash

-- | Full version string, e.g. @"okf v0.1.0.0 (a1b2c3d)"@, or @"okf v0.1.0.0"@ when
-- no commit hash is available.
appVersionWithGit :: Text
appVersionWithGit = "okf v" <> appVersion <> commitSuffix
  where
    commitSuffix = maybe "" (\c -> " (" <> c <> ")") gitCommitShort
