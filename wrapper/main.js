#!/usr/bin/env -S node --disable-warning=ExperimentalWarning --max-old-space-size=65536 --wasm-lazy-validation

import { Readable, Writable } from "node:stream";
import { ReadableStream, WritableStream } from 'node:stream/web';
import { initReactor } from "./reactor.js";

/** @param {string[]} args */
function parseArgv(args) {
  const i = args.indexOf("-0");
  return i === -1 ? args : args.slice(i + 2);
}

const argv = parseArgv(process.argv.slice(2));

const lib = await initReactor(argv);

const serverHandle = await lib.new_language_server();

/** @implements {UnderlyingDefaultSource<string>} */
class ReadableStreamSource {
  /**
   * @param {import('./reactor.js').FFI} lib
   * @param {import('./reactor.js').ServerHandle} handle
   */
  constructor(lib, handle) {
    this.lib = lib;
    this.handle = handle;
  }

  /** @param {ReadableStreamDefaultController<string>} controller */
  async pull(controller) {
    const data = await this.lib.recv_message(this.handle);
    controller.enqueue(data);
  }
}

/** @implements {UnderlyingSink} */
class WritableStreamSink {
  /**
   * @param {import('./reactor.js').FFI} lib
   * @param {import('./reactor.js').ServerHandle} handle
   */
  constructor(lib, handle) {
    this.lib = lib;
    this.handle = handle;
  }

  /** @param {Uint8Array} msg */
  async write(msg) {
    await this.lib.send_message(this.handle, new TextDecoder().decode(msg));
  }
}

const msgReader = new ReadableStream(new ReadableStreamSource(lib, serverHandle));
const msgWriter = new WritableStream(new WritableStreamSink(lib, serverHandle));

const stdinReadableStream = Readable.toWeb(process.stdin);
const stdoutWritableStream = Writable.toWeb(process.stdout);

stdinReadableStream.pipeTo(msgWriter);
msgReader.pipeTo(stdoutWritableStream);

lib.run_language_server(serverHandle).then(async code => {
  await lib.free_language_server(serverHandle);
  process.exit(code);
});
