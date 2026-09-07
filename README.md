# hs-lsp-reactor

A quick PoC of Haskell's `lsp` package compiled into a WASI reactor module.

## Building

0. You have setup the ghc-wasm environment in your home directory. Also, clone the `lsp` submodule pointing to the unreleased lsp package containing [these](https://github.com/haskell/lsp/pull/643) [patches](https://github.com/haskell/lsp/pull/644).
1. Run `build.sh`. The resulting WASM binary will be copied to project root.

## Post-processing

The `hs-lsp-reactor.wizer.wasm` is built according to [this section of ghc-wasm-meta](https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta#using-wizer-to-pre-initialize-a-wasi-reactor-module).

The `*.oz.wasm` are The original and wizer-processed files optmizied via `wasm-opt -Oz in.wasm -o out.wasm`.
