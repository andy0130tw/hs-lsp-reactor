#!/bin/bash -ex

cd network
autoreconf -i
cd ..

wasm32-wasi-cabal build
cp "$(wasm32-wasi-cabal list-bin hs-lsp-reactor)" .
~/.ghc-wasm/wasm32-wasi-ghc/lib/post-link.mjs -i hs-lsp-reactor.wasm -o jsffi.js
