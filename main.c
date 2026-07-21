// Including this since we need access to GHC's RTS API. And it
// transitively includes pretty much all of libc headers that we need.
#include <Rts.h>

// When GHC compiles the Test module with foreign export, it'll
// generate Test_stub.h that declares the prototypes for C functions
// that wrap the corresponding Haskell functions.
#include "Reactor_stub.h"

#include <string.h>

// The prototype of hs_init_with_rtsopts is "void
// hs_init_with_rtsopts(int *argc, char **argv[])" which is a bit
// cumbersome to work with, hence this convenience wrapper.
STATIC_INLINE void hs_init_with_rtsopts_(char *argv[]) {
  int argc;
  for (argc = 0; argv[argc] != NULL; ++argc) {
  }
  hs_init_with_rtsopts(&argc, &argv);
}

void malloc_inspect_all(void (*handler)(void *start, void *end,
                                        size_t used_bytes, void *callback_arg),
                        void *arg);

static void malloc_inspect_all_handler(void *start, void *end,
                                       size_t used_bytes, void *callback_arg) {
  if (used_bytes == 0) {
    memset(start, 0, (size_t)end - (size_t)start);
  }
}

extern char __stack_low;
extern char __stack_high;

// Export this function as "wizer.initialize". wizer also accepts
// "--init-func <init-func>" if you dislike this export name, or
// prefer to pass -Wl,--export=my_init at link-time.
//
// By the time this function is called, the WASI reactor _initialize
// has already been called by wizer. The export entries of this
// function and _initialize will both be stripped by wizer.
__attribute__((export_name("wizer.initialize"))) void __wizer_initialize(void) {
  // The first argument is what you get in getProgName.
  //
  // -H64m sets the "suggested heap size" to 64MB and reserves so much
  // memory when doing GC for the first time. It's not a hard limit,
  // the RTS is perfectly capable of growing the heap beyond it, but
  // it's still recommended to reserve a reasonably sized heap in the
  // beginning. And it doesn't add 64MB to the wizer output, most of
  // the grown memory will be zero anyway!
  char *argv[] = {"hs-lsp-reactor.wasm", "+RTS", "-H64m", "-RTS", NULL};

  // The WASI reactor _initialize function only takes care of
  // initializing the libc state. The GHC RTS needs to be initialized
  // using one of hs_init* functions before doing any Haskell
  // computation.
  hs_init_with_rtsopts_(argv);

  // Not interesting, I know. The point is you can perform any Haskell
  // computation here! Or C/C++, whatever.
  // fib(10);

  // Perform major GC to clean up the heap. The second run will invoke
  // the C finalizers found during the first run.
  hs_perform_gc();
  hs_perform_gc();

  // Zero out the unused RTS memory, to prevent the garbage bytes from
  // being snapshotted into the final wasm module. Otherwise it
  // wouldn't affect correctness, but the wasm module size would bloat
  // significantly. It's only safe to call this after hs_perform_gc()
  // has returned.
  rts_clearMemory();

  // Zero out the unused heap space. `malloc_inspect_all` is a
  // dlmalloc internal function which traverses the heap space and can
  // be used to zero out some space that's previously allocated and
  // then freed. Upstream `wasi-libc` doesn't expose this function
  // yet, we do since it's useful for this specific purpose.
  malloc_inspect_all(malloc_inspect_all_handler, NULL);

  // Zero out the entire stack region in the linear memory. This is
  // only suitable to do after all other cleanup has been done and
  // we're about to exit `__wizer_initialize`. `__stack_low` and
  // `__stack_high` are linker generated symbols which resolve to the
  // two ends of the stack region.
  memset(&__stack_low, 0, &__stack_high - &__stack_low);
}

