/*
 * aiux_capi.h — AIUX C ABI (plan §5, ADR 0005)
 *
 * The stable boundary between the Rust core and the Dart FFI wrapper in
 * bindings/dart. Mirrors the frozen `AiuxSession` facade
 * (core/rust/session): create / restore / dispatch / dispatch_batch /
 * snapshot / serialize / reset. JSON strings cross both ways; no internal
 * type is ever exposed.
 *
 * Contract:
 * - `AiuxSessionHandle` is opaque; create it with aiux_session_create or
 *   aiux_session_restore, release it with aiux_session_free.
 * - Every `char*` return is a heap-allocated, NUL-terminated UTF-8 string
 *   the caller MUST release with aiux_string_free. A NULL return means the
 *   call failed — the detail is available via aiux_take_last_error.
 * - aiux_take_last_error returns the calling thread's last error as a heap
 *   string (caller frees), or NULL when none is pending. Each fallible call
 *   clears it on entry.
 * - Handles are NOT thread-safe; serialize calls per handle.
 * - Panics never unwind across the boundary; they surface as
 *   "internal error: panic" via aiux_take_last_error.
 */

#ifndef AIUX_CAPI_H
#define AIUX_CAPI_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AiuxSessionHandle AiuxSessionHandle;

/* Library version string. Caller frees. */
char *aiux_capi_version(void);

/* Create a session. `config_json` is the facade's JSON config (NULL →
 * `"{}"`). Returns NULL on error. */
AiuxSessionHandle *aiux_session_create(const char *config_json);

/* Restore a session from an aiux_session_serialize() payload.
 * Returns NULL on error. */
AiuxSessionHandle *aiux_session_restore(const char *serialized_json);

/* Release a session handle. NULL-safe. */
void aiux_session_free(AiuxSessionHandle *handle);

/* Reduce one event (JSON envelope). Returns dispatch report JSON
 * `{applied, duplicatesIgnored, buffered}`, or NULL on error. */
char *aiux_session_dispatch(AiuxSessionHandle *handle, const char *event_json);

/* Reduce an ordered JSON array of events in one call. Returns dispatch
 * report JSON, or NULL on error. */
char *aiux_session_dispatch_batch(AiuxSessionHandle *handle,
                                  const char *events_json);

/* Canonical-JSON render snapshot for the current state, or NULL on error. */
char *aiux_session_snapshot(AiuxSessionHandle *handle);

/* Canonical-JSON serialized session state, or NULL on error. */
char *aiux_session_serialize(AiuxSessionHandle *handle);

/* Clear all session state. */
void aiux_session_reset(AiuxSessionHandle *handle);

/* Release a string returned by this library. NULL-safe. */
void aiux_string_free(char *s);

/* Take the calling thread's last error (caller frees), or NULL when none
 * is pending. */
char *aiux_take_last_error(void);

#ifdef __cplusplus
}
#endif

#endif /* AIUX_CAPI_H */
