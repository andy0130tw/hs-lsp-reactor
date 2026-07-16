{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DisambiguateRecordFields #-}

module Reactor where

#if defined(wasm32_HOST_ARCH)
import GHC.Wasm.Prim
#endif

import Colog.Core (LogAction (..), WithSeverity (..))
import qualified Colog.Core as L

import qualified Data.Aeson as Aeson
import qualified Data.Text as T
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as C
import Prettyprinter
import GHC.Generics (Generic)
import Control.Monad.Reader
import Control.Monad.IO.Unlift ()
import Language.LSP.Server
import Language.LSP.Protocol.Types as LSP
import Language.LSP.Protocol.Message
import Language.LSP.Logging (defaultClientLogger)

import Control.Concurrent (MVar, newEmptyMVar, takeMVar, putMVar)
import Foreign.StablePtr (StablePtr, newStablePtr, freeStablePtr, deRefStablePtr)

data Env = Env
  { incomingMessage :: MVar B.StrictByteString
  , outgoingMessage :: MVar String
  }

type ServerHandle = StablePtr Env

#if defined(wasm32_HOST_ARCH)
foreign export javascript "new_language_server"
  newLanguageServer :: IO ServerHandle

foreign export javascript "run_language_server"
  runLanguageServer :: ServerHandle -> IO Int

foreign export javascript "free_language_server"
  freeLanguageServer :: ServerHandle -> IO ()

foreign export javascript "send_message"
  sendMessage :: ServerHandle -> JSString -> IO ()

foreign export javascript "recv_message"
  recvMessage :: ServerHandle -> IO JSString
#else
data JSString = JSString {}

fromJSString :: JSString -> String
fromJSString = undefined
toJSString :: String -> JSString
toJSString = undefined
#endif

defaultIOLogger :: LogAction IO (WithSeverity LspServerLog)
defaultIOLogger = L.cmap (show . prettyMsg) L.logStringStderr
  where prettyMsg l = "[" <> viaShow (L.getSeverity l) <> "] " <> pretty (L.getMsg l)

defaultLspLogger :: LogAction (LspM config) (WithSeverity LspServerLog)
defaultLspLogger =
  let clientLogger = L.cmap (fmap (T.pack . show . pretty)) defaultClientLogger
   in clientLogger <> L.hoistLogAction liftIO defaultIOLogger

data Config = Config {}
  deriving (Eq, Show, Generic)

instance Aeson.FromJSON Config
instance Aeson.ToJSON   Config

type ServerT config = LspT config (ReaderT Env IO)

initialEnv :: IO Env
initialEnv = Env <$> newEmptyMVar <*> newEmptyMVar

newLanguageServer :: IO ServerHandle
newLanguageServer = initialEnv >>= newStablePtr

freeLanguageServer :: ServerHandle -> IO ()
freeLanguageServer = freeStablePtr

runLanguageServer :: ServerHandle -> IO Int
runLanguageServer hdl = do
  lsEnv <- deRefStablePtr hdl

  let
    serverDefinition :: ServerDefinition Config
    serverDefinition = ServerDefinition
      { defaultConfig = Config
      , configSection = "dummy"
      , parseConfig = const $ const $ Right Config
      , onConfigChange = const $ pure ()
      , doInitialize = myDoInitialize
      , staticHandlers = const $ lspStaticHandlers
      , interpretHandler = \env -> Iso (flip runReaderT lsEnv . runLspT env) liftIO
      , options = lspOptions
      }

    serverConfig :: ServerConfig Config
    serverConfig = ServerConfig
      { ioLogger = defaultIOLogger
      , lspLogger = defaultLspLogger
      , inwards = serverInwards
      , outwards = serverOutwards
      , prepareOutwards = prependHeader
      , parseInwards = parseHeaders
      }

    serverInwards :: IO B.StrictByteString
    serverInwards = takeMVar (incomingMessage lsEnv)

    serverOutwards :: BL.LazyByteString -> IO ()
    serverOutwards s = (return . C.unpack . BL.toStrict) s >>= putMVar (outgoingMessage lsEnv)

  runServerWithConfig serverConfig serverDefinition

  where
    myDoInitialize env _ = pure (Right env)
    lspOptions = defaultOptions { optTextDocumentSync = Just syncOptions }
    syncOptions = TextDocumentSyncOptions
      { _openClose = Just True
      , _change = Just TextDocumentSyncKind_Incremental
      , _willSave = Just False
      , _willSaveWaitUntil = Just False
      , _save = Just $ InR (SaveOptions (Just True))
      }

    lspStaticHandlers :: Handlers (ServerT Config)
    lspStaticHandlers =
      mconcat [
        notificationHandler SMethod_Initialized $ \_notif -> pure ()
        -- dummy handlers that lsp spec mandates
      , notificationHandler SMethod_TextDocumentDidOpen $ \_notif -> pure ()
      , notificationHandler SMethod_TextDocumentDidChange $ \_notif -> pure ()
      , notificationHandler SMethod_TextDocumentDidClose $ \_notif -> pure ()
      ]

sendMessage :: ServerHandle -> JSString -> IO ()
sendMessage hdl s = do
  env <- deRefStablePtr hdl
  let input = fromJSString s
  putMVar (incomingMessage env) (C.pack input)
  return ()

recvMessage :: ServerHandle -> IO JSString
recvMessage hdl = do
  env <- deRefStablePtr hdl
  str <- takeMVar (outgoingMessage env)
  return $ toJSString str
