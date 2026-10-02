//! aiux-capi — narrow C ABI over the frozen `AiuxSession` facade (plan §5,
//! ADR 0005). This is the stable boundary the Dart FFI wrapper (and any
//! future bridge tooling) binds to: no internal type crosses it.
//!
//! Contract (see `aiux_capi.h`):
//! - Sessions are opaque handles owned by the caller; `aiux_session_free`
//!   releases them. Handles are not thread-safe — callers serialize access
//!   per handle (the Dart wrapper is single-isolate by construction).
//! - Functions returning `char*` return heap-allocated, NUL-terminated UTF-8
//!   strings the caller must release with `aiux_string_free`. A `NULL`
//!   return means the call failed; the failure detail is then available via
//!   `aiux_take_last_error`.
//! - `aiux_take_last_error` returns the calling thread's last error as a
//!   heap string (caller frees), or `NULL` when no error is pending. Every
//!   fallible entry point clears it on entry, so a stale error never
//!   survives a subsequent successful call.
//! - Panics never unwind across the boundary: every entry point catches and
//!   reports `internal error: panic` instead of invoking UB.

use std::cell::RefCell;
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use aiux_session::AiuxSession;

/// Opaque session handle — owns the Rust facade.
pub struct AiuxSessionHandle {
    inner: AiuxSession,
}

thread_local! {
    /// Last error reported on this thread, owned until taken.
    static LAST_ERROR: RefCell<Option<CString>> = const { RefCell::new(None) };
}

fn set_last_error(detail: impl std::fmt::Display) {
    let message = detail.to_string();
    LAST_ERROR.with(|slot| {
        *slot.borrow_mut() = Some(
            CString::new(message)
                .unwrap_or_else(|_| CString::new("error detail contained NUL").unwrap()),
        );
    });
}

fn clear_last_error() {
    LAST_ERROR.with(|slot| {
        *slot.borrow_mut() = None;
    });
}

/// Convert an owned Rust string into a heap C string for the caller.
/// `serde_json` output never contains interior NUL; on the impossible
/// collision the string is truncated at the first NUL rather than failing.
fn into_c_string(value: String) -> *mut c_char {
    match CString::new(value) {
        Ok(s) => s.into_raw(),
        Err(e) => {
            let mut bytes = e.into_vec();
            bytes.truncate(bytes.iter().position(|b| *b == 0).unwrap_or(bytes.len()));
            CString::new(bytes)
                .map(|s| s.into_raw())
                .unwrap_or(ptr::null_mut())
        }
    }
}

/// Read a borrowed C string argument. `NULL` maps to `fallback` (config
/// tolerates `NULL` → `"{}"`; everything else errors).
unsafe fn read_arg(
    arg: *const c_char,
    name: &str,
    fallback: Option<&str>,
) -> Result<String, String> {
    if arg.is_null() {
        return match fallback {
            Some(f) => Ok(f.to_string()),
            None => Err(format!("{name} must not be NULL")),
        };
    }
    let bytes = unsafe { CStr::from_ptr(arg) }.to_bytes();
    String::from_utf8(bytes.to_vec()).map_err(|e| format!("{name} is not valid UTF-8: {e}"))
}

/// Borrow the session handle; `NULL` → error.
unsafe fn session_ref<'a>(handle: *mut AiuxSessionHandle) -> Result<&'a mut AiuxSession, String> {
    unsafe { handle.as_mut() }
        .map(|h| &mut h.inner)
        .ok_or_else(|| "session handle must not be NULL".to_string())
}

/// Run `body` with panic isolation and error capture. On success returns
/// `into_c_string(json)`; on failure records the error and returns `NULL`.
fn call_json<F>(body: F) -> *mut c_char
where
    F: FnOnce() -> Result<String, String>,
{
    clear_last_error();
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(Ok(json)) => into_c_string(json),
        Ok(Err(e)) => {
            set_last_error(e);
            ptr::null_mut()
        }
        Err(_) => {
            set_last_error("internal error: panic");
            ptr::null_mut()
        }
    }
}

/// Run `body` (void result) with panic isolation and error capture.
fn call_void<F>(body: F)
where
    F: FnOnce() -> Result<(), String>,
{
    clear_last_error();
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(Ok(())) => {}
        Ok(Err(e)) => set_last_error(e),
        Err(_) => set_last_error("internal error: panic"),
    }
}

/// The library's version string (caller frees).
#[no_mangle]
pub extern "C" fn aiux_capi_version() -> *mut c_char {
    into_c_string(env!("CARGO_PKG_VERSION").to_string())
}

/// Create a session. `config_json` is the facade's JSON config (`NULL` →
/// `"{}"`). Returns `NULL` on error.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string or `NULL`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_create(config_json: *const c_char) -> *mut AiuxSessionHandle {
    clear_last_error();
    let config = match unsafe { read_arg(config_json, "config_json", Some("{}")) } {
        Ok(c) => c,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };
    match catch_unwind(AssertUnwindSafe(|| AiuxSession::create(&config))) {
        Ok(Ok(inner)) => Box::into_raw(Box::new(AiuxSessionHandle { inner })),
        Ok(Err(e)) => {
            set_last_error(e);
            ptr::null_mut()
        }
        Err(_) => {
            set_last_error("internal error: panic");
            ptr::null_mut()
        }
    }
}

/// Restore a session from a `serialize()` payload.
///
/// # Safety
/// `serialized_json` must be a valid NUL-terminated UTF-8 string or `NULL`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_restore(
    serialized_json: *const c_char,
) -> *mut AiuxSessionHandle {
    clear_last_error();
    let serialized = match unsafe { read_arg(serialized_json, "serialized_json", None) } {
        Ok(s) => s,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };
    match catch_unwind(AssertUnwindSafe(|| AiuxSession::restore(&serialized))) {
        Ok(Ok(inner)) => Box::into_raw(Box::new(AiuxSessionHandle { inner })),
        Ok(Err(e)) => {
            set_last_error(e);
            ptr::null_mut()
        }
        Err(_) => {
            set_last_error("internal error: panic");
            ptr::null_mut()
        }
    }
}

/// Release a session handle. Safe to call with `NULL`.
///
/// # Safety
/// `handle` must come from `aiux_session_create`/`aiux_session_restore` and
/// must not be used after this call.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_free(handle: *mut AiuxSessionHandle) {
    if handle.is_null() {
        return;
    }
    // Dropping the Box releases the session.
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(Box::from_raw(handle));
    }));
}

/// Reduce one event (JSON envelope). Returns the dispatch report JSON, or
/// `NULL` on error.
///
/// # Safety
/// `handle` must be a live session; `event_json` a NUL-terminated UTF-8
/// string. The returned string must be freed with `aiux_string_free`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_dispatch(
    handle: *mut AiuxSessionHandle,
    event_json: *const c_char,
) -> *mut c_char {
    call_json(|| {
        let session = unsafe { session_ref(handle)? };
        let event = unsafe { read_arg(event_json, "event_json", None)? };
        let report = session.dispatch(&event).map_err(|e| e.to_string())?;
        serde_json::to_string(&report).map_err(|e| format!("dispatch report serialization: {e}"))
    })
}

/// Reduce an ordered JSON array of events in one call (plan §22 — streaming
/// deltas batch here). Returns the dispatch report JSON, or `NULL` on error.
///
/// # Safety
/// `handle` must be a live session; `events_json` a NUL-terminated UTF-8
/// string containing a JSON array. The returned string must be freed with
/// `aiux_string_free`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_dispatch_batch(
    handle: *mut AiuxSessionHandle,
    events_json: *const c_char,
) -> *mut c_char {
    call_json(|| {
        let session = unsafe { session_ref(handle)? };
        let events = unsafe { read_arg(events_json, "events_json", None)? };
        let report = session.dispatch_batch(&events).map_err(|e| e.to_string())?;
        serde_json::to_string(&report).map_err(|e| format!("dispatch report serialization: {e}"))
    })
}

/// Canonical-JSON render snapshot for the current state, or `NULL` on error.
///
/// # Safety
/// `handle` must be a live session. The returned string must be freed with
/// `aiux_string_free`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_snapshot(handle: *mut AiuxSessionHandle) -> *mut c_char {
    call_json(|| {
        unsafe { session_ref(handle)? }
            .snapshot()
            .map_err(|e| e.to_string())
    })
}

/// Canonical-JSON serialized session state, or `NULL` on error.
///
/// # Safety
/// `handle` must be a live session. The returned string must be freed with
/// `aiux_string_free`.
#[no_mangle]
pub unsafe extern "C" fn aiux_session_serialize(handle: *mut AiuxSessionHandle) -> *mut c_char {
    call_json(|| {
        unsafe { session_ref(handle)? }
            .serialize()
            .map_err(|e| e.to_string())
    })
}

/// Clear all session state.
///
/// # Safety
/// `handle` must be a live session or `NULL` (no-op with error recorded).
#[no_mangle]
pub unsafe extern "C" fn aiux_session_reset(handle: *mut AiuxSessionHandle) {
    call_void(|| {
        unsafe { session_ref(handle)? }.reset();
        Ok(())
    })
}

/// Release a string returned by this library. Safe to call with `NULL`.
///
/// # Safety
/// `s` must be a pointer returned by an `aiux_*` function and must not be
/// used after this call.
#[no_mangle]
pub unsafe extern "C" fn aiux_string_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(CString::from_raw(s));
    }));
}

/// Take the calling thread's last error. Returns a heap string the caller
/// frees with `aiux_string_free`, or `NULL` when no error is pending.
///
/// # Safety
/// No requirements beyond the general contract.
#[no_mangle]
pub unsafe extern "C" fn aiux_take_last_error() -> *mut c_char {
    LAST_ERROR.with(|slot| match slot.borrow_mut().take() {
        Some(s) => s.into_raw(),
        None => ptr::null_mut(),
    })
}

#[cfg(test)]
mod smoke {
    use super::*;
    use std::ffi::CString;

    const EVENT: &str = r#"{"eventId":"e0","sessionId":"s1","sequence":0,"timestamp":"2026-01-01T00:00:00Z","type":"session.created","payload":{"protocolVersion":"0.1","session":{"id":"s1"}}}"#;

    unsafe fn to_string_and_free(s: *mut c_char) -> String {
        assert!(!s.is_null());
        let out = unsafe { CStr::from_ptr(s) }.to_str().unwrap().to_string();
        unsafe { aiux_string_free(s) };
        out
    }

    #[test]
    fn c_abi_roundtrip() {
        unsafe {
            let config = CString::new(r#"{"sessionId":"s1"}"#).unwrap();
            let s = aiux_session_create(config.as_ptr());
            assert!(!s.is_null(), "create failed");

            let event = CString::new(EVENT).unwrap();
            let report = to_string_and_free(aiux_session_dispatch(s, event.as_ptr()));
            assert_eq!(
                report,
                r#"{"applied":1,"duplicatesIgnored":0,"buffered":0}"#
            );
            assert!(aiux_take_last_error().is_null());

            let snap = to_string_and_free(aiux_session_snapshot(s));
            assert!(snap.contains("s1"));

            let serialized = to_string_and_free(aiux_session_serialize(s));
            let ser_c = CString::new(serialized).unwrap();
            let restored = aiux_session_restore(ser_c.as_ptr());
            assert!(!restored.is_null(), "restore failed");
            assert_eq!(
                to_string_and_free(aiux_session_snapshot(restored)),
                to_string_and_free(aiux_session_snapshot(s)),
            );

            aiux_session_reset(s);
            let snap = to_string_and_free(aiux_session_snapshot(s));
            assert!(snap.contains("\"messages\": []"));

            aiux_session_free(s);
            aiux_session_free(restored);
            aiux_session_free(ptr::null_mut());
        }
    }

    #[test]
    fn c_abi_errors() {
        unsafe {
            // NULL handle → error + NULL return.
            assert!(aiux_session_snapshot(ptr::null_mut()).is_null());
            let err = to_string_and_free(aiux_take_last_error());
            assert!(err.contains("handle"));
            assert!(aiux_take_last_error().is_null());

            // Bad JSON → error + NULL return.
            let bad = CString::new("not json").unwrap();
            assert!(aiux_session_restore(bad.as_ptr()).is_null());
            let err = to_string_and_free(aiux_take_last_error());
            assert!(err.contains("corrupt state") || err.contains("parse"));

            // NULL event arg → error + NULL return.
            let s = aiux_session_create(ptr::null());
            assert!(!s.is_null());
            assert!(aiux_session_dispatch(s, ptr::null()).is_null());
            let err = to_string_and_free(aiux_take_last_error());
            assert!(err.contains("event_json"));

            // A successful call clears stale errors.
            let snap = to_string_and_free(aiux_session_snapshot(s));
            assert!(snap.contains("messages"));
            assert!(aiux_take_last_error().is_null());
            aiux_session_free(s);
        }
    }
}
