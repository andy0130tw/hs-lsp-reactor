# hs-lsp-reactor

A quick PoC of Haskell's `lsp` package compiled into a WASI reactor module.

## Building

0. You have setup the ghc-wasm environment in your home directory.
1. (Already done for you) ~~Patch `lsp` to remove WebSocket support:~~
   - `lsp/lsp/lsp.cabal`: Comment out the line `, websockets            ^>=0.13`.
   - `lsp/lsp/src/Language/LSP/Server/Control.hs`: Comment out all definitions of `WebsocketConfig`, `withWebsocket`, and `withWebsocketRunServer`.
2. Run `build.sh`. The resulting WASM binary will be copied to project root.

## Post-processing

The `hs-lsp-reactor.wizer.wasm` is built according to [this section of ghc-wasm-meta](https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta#using-wizer-to-pre-initialize-a-wasi-reactor-module).

The `*.oz.wasm` are The original and wizer-processed files optmizied via `wasm-opt -Oz in.wasm -o out.wasm`.
