#!/usr/bin/env bash

BASENAME=$(dirname $0)

"$BASENAME/main.js" "$BASENAME/../hs-lsp-reactor.wasm" "$@"
