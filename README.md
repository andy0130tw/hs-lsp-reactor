# hs-lsp-reactor

A quick PoC of Haskell's `lsp` package compiled into a WASI reactor module.

## Building

0. You have setup the ghc-wasm environment in your home directory.
1. Patch `lsp` to remove WebSocket support:
   - `lsp/lsp/lsp.cabal`: Comment out the line `, websockets            ^>=0.13`.
   - `lsp/lsp/src/Language/LSP/Server/Control.hs`: Comment out all definitions of `WebsocketConfig`, `withWebsocket`, and `withWebsocketRunServer`.
2. Run `build.sh`. The resulting WASM binary will be copied to project root.
