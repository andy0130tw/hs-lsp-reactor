// modified from:
// https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/blob/ef7acd4edfec5dd4b80b2228b625990aaf3cd4b7/wasm-run/wasm-run.mjs
// to support using as a reactor module

import fs from "node:fs";
import stream from "node:stream";
import { WASI } from "node:wasi";
import path from "node:path";

import jsffi from "../jsffi.js";

const __dirname = import.meta.dirname;

/** @param {string[]} argv */
export async function initReactor(argv) {
  const wasi = new WASI({
    version: "preview1",
    args: argv,
    env: { PATH: "", PWD: process.cwd() },
    preopens: { "/": "/" },
  });

  const rstream = /** @type {ReadableStream<Uint8Array>} */(
    stream.Readable.toWeb(fs.createReadStream(path.resolve(__dirname, "../hs-lsp-reactor.wasm"))));

  const mod = await WebAssembly.compileStreaming(
    new Response(rstream, {
      headers: { "Content-Type": "application/wasm" },
    })
  );

  /** @type {{ hs_init: (argc: 0, argv: 0) => Promise<void>, [k: string]: (...args: any[]) => any }} */
  const lib = /** @type {any} */({});

  const import_obj = {
    wasi_snapshot_preview1: wasi.wasiImport,
    ghc_wasm_jsffi: jsffi(lib),
  };

  const instance = await WebAssembly.instantiate(mod, import_obj);
  Object.assign(lib, instance.exports);

  wasi.initialize(instance);
  await lib.hs_init(0, 0);

  return lib;
}
