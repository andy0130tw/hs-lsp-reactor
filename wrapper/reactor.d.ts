// an opaque reference (might not even be an object)
interface ServerHandle { _serverHandle?: void }

interface FFI {
  hs_init(argc: 0, argv: 0): Promise<void>
  new_language_server(): Promise<ServerHandle>
  free_language_server(hdl: ServerHandle): Promise<void>
  run_language_server(hdl: ServerHandle): Promise<number>
  send_message(hdl: ServerHandle, msg: string): Promise<void>
  recv_message(hdl: ServerHandle): Promise<string>
}

export const initReactor: (argv: string[]) => Promise<FFI>
