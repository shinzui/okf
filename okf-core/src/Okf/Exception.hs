-- | Catch synchronous failures while preserving asynchronous cancellation.
module Okf.Exception (catchSynchronous) where

import Control.Exception (SomeAsyncException, SomeException, catch, fromException, throwIO)

catchSynchronous :: IO a -> (SomeException -> IO a) -> IO a
catchSynchronous action handler =
  action `catch` \exception ->
    case fromException exception :: Maybe SomeAsyncException of
      Just _ -> throwIO exception
      Nothing -> handler exception
