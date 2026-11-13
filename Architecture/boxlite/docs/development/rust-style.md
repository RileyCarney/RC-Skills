# Rust style guide
Source: https://docs.boxlite.ai/development/rust-style

Coding conventions for contributors to the BoxLite core (the Rust crates). The goal is for submitted PRs to pass the CI cargo fmt / cargo clippy gates on the first try and to stay consistent with the existing codebase.

BoxLite follows the [Microsoft Rust Guidelines](https://microsoft.github.io/rust-guidelines) and layers its own conventions on top. Examples target the `boxlite` crate (source under `src/boxlite/src/`) and the shared crate `boxlite-shared` (source under `src/shared/src/`).

## External references

* **Microsoft Rust Guidelines**: [https://microsoft.github.io/rust-guidelines](https://microsoft.github.io/rust-guidelines)
* **Rust API Guidelines**: [https://rust-lang.github.io/api-guidelines/](https://rust-lang.github.io/api-guidelines/)

## General guidelines (required)

The following guidelines from the Microsoft Rust Guidelines are especially important for BoxLite:

| Guideline | Summary |
| - | - |
| **M-PANIC-IS-STOP** | A panic terminates the process — it is not an exception and must not be used for recoverable errors. |
| **M-PANIC-ON-BUG** | Panic only on programming errors (bugs), never for expected failures. |
| **M-CONCISE-NAMES** | Avoid meaningless qualifiers: "Service", "Manager", "Factory", "Handler". |
| **M-LOG-STRUCTURED** | Use structured logging with meaningful fields. |
| **M-DOCUMENTED-MAGIC** | Document every magic number and constant. |
| **M-PUBLIC-DEBUG** | All public types must implement `Debug`. |
| **M-PUBLIC-DISPLAY** | User-facing types should implement `Display`. |
| **M-LINT-OVERRIDE-EXPECT** | Prefer `#[expect]` over `#[allow]` for lint overrides. |
| **M-REGULAR-FN** | When `self` is not needed, prefer a plain function over a method. |
| **M-SMALLER-CRATES** | Keep each crate focused on a single responsibility. |

## Unsafe guidelines

| Guideline | Summary |
| - | - |
| **M-UNSAFE** | Minimize unsafe code; isolate it in small, well-documented functions. |
| **M-UNSAFE-IMPLIES-UB** | Document every precondition whose violation could trigger undefined behavior (UB) in unsafe code. |
| **M-UNSOUND** | Never expose an unsound API; soundness must be guaranteed. |

## BoxLite-specific patterns

### Async-first architecture

All I/O operations use `async/await` and run on the Tokio runtime:

```rust theme={"theme":{"light":"github-light","dark":"github-dark"}}
use std::path::Path;
use boxlite_shared::{BoxliteError, BoxliteResult};

// ✅ Correct: async I/O
async fn read_config(path: &Path) -> BoxliteResult<String> {
    let contents = tokio::fs::read_to_string(path)
        .await
        .map_err(|e| BoxliteError::Storage(format!(
            "failed to read config {}: {}", path.display(), e
        )))?;
    Ok(contents)
}

// ❌ Wrong: blocking I/O in an async context
async fn read_config_blocking(path: &Path) -> BoxliteResult<String> {
    // std::fs::read_to_string blocks the entire executor thread!
    let contents = std::fs::read_to_string(path)
        .map_err(|e| BoxliteError::Storage(e.to_string()))?;
    Ok(contents)
}
```

> `BoxliteResult<T>` and `BoxliteError` are both defined in `boxlite-shared` and re-exported at the top level of the `boxlite` crate (`src/boxlite/src/lib.rs`).

### Centralized error handling

All errors flow through the `BoxliteError` enum (defined in `src/shared/src/errors.rs`). Always attach context when reporting an error:

```rust theme={"theme":{"light":"github-light","dark":"github-dark"}}
use std::path::Path;
use boxlite_shared::{BoxliteError, BoxliteResult};

// ✅ Correct: use BoxliteError with context
fn ensure_socket_dir(socket_dir: &Path) -> BoxliteResult<()> {
    std::fs::create_dir_all(socket_dir).map_err(|e| {
        BoxliteError::Storage(format!(
            "failed to create socket directory {}: {}", socket_dir.display(), e
        ))
    })?;
    Ok(())
}

// ❌ Wrong: a bare `?` discards context; the caller cannot locate the failure
fn ensure_socket_dir_bad(dir: &Path) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)?; // on error only "Permission denied" remains, with no directory
    Ok(())
}
```

Common `BoxliteError` variants (a selection from `src/shared/src/errors.rs`): `Storage`, `Config`, `Image`, `Network`, `Execution`, `NotFound`, `AlreadyExists`, `InvalidState`, `InvalidArgument`, `Stopped`, `Internal`, and others — all in the form `BoxliteError::Variant(String)`. Choose the variant closest to the semantics; do not default everything to `Internal`.

> Note: there is no `BoxliteError::Run` variant — use `BoxliteError::Execution(...)` for execution-related errors.

### Public types must be `Send + Sync`

Every public type exposed through the API must be thread-safe. Use `Arc` to share ownership across threads; do not use `Rc`:

```rust theme={"theme":{"light":"github-light","dark":"github-dark"}}
use std::sync::Arc;

// ✅ Correct: use Arc to share ownership across threads (see LiteBox in src/boxlite/src/litebox/mod.rs)
pub struct LiteBox {
    box_backend: Arc<dyn BoxBackend>,
    snapshot_backend: Arc<dyn SnapshotBackend>,
}

// ❌ Wrong: Rc is not Send and cannot cross threads
pub struct LiteBoxBad {
    backend: std::rc::Rc<dyn BoxBackend>, // not thread-safe!
}

// The two traits below exist only so the example above compiles standalone
pub trait BoxBackend: Send + Sync {}
pub trait SnapshotBackend: Send + Sync {}
```

> The real `LiteBox` (`src/boxlite/src/litebox/mod.rs`) holds `Arc<dyn BoxBackend>` / `Arc<dyn SnapshotBackend>` to provide a cloneable, thread-safe handle. Methods such as `exec` (the command-execution method; see `src/boxlite/src/litebox/mod.rs`) take `&self` so the handle can be shared.

## Formatting and linting

* **Formatting**: `cargo fmt` (enforced in CI; the repository root carries the `rustfmt.toml` configuration).
* **Linting**: `cargo clippy` (warnings are treated as errors in CI).

Before submitting, run the following from the repository root:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# 1) Format all code
cargo fmt

# 2) Run clippy over all targets / features, treating warnings as errors
cargo clippy --all-targets --all-features -- -D warnings
```

> `cargo fmt --check` does not modify files; it only reports whether formatting is needed, which makes it suitable as a gate in scripts.

## Quick self-check

When writing Rust for BoxLite, ask yourself before submitting:

1. **Is this panic necessary?** (M-PANIC-ON-BUG) — panic only on bugs; use `Result` for expected errors.
2. **Is this name clear enough?** (M-CONCISE-NAMES) — avoid "Manager", "Service", "Factory".
3. **Is the unsafe code minimized?** (M-UNSAFE) — isolate and document unsafe code.
4. **Does it implement `Debug`?** (M-PUBLIC-DEBUG) — required for all public types.
5. **Is it async?** — all I/O should be Tokio-based and asynchronous.
6. **Does the error carry context?** — use `BoxliteError` with a clear description.

## Troubleshooting

| Symptom / error | Cause | Fix |
| - | - | - |
| CI `cargo clippy` fails but it passes locally | Locally you did not pass `-D warnings`, so warnings were ignored; or not all targets/features were covered | Reproduce the gate locally: `cargo clippy --all-targets --all-features -- -D warnings` |
| `cargo fmt` reformats a large block of unrelated lines | Your local rustfmt version differs from CI | Use the same toolchain as CI (the `rustup` default stable); the repository-root `rustfmt.toml` is the single source of formatting truth — do not override it in your editor |
| `error[E0277]: Rc<...> cannot be sent between threads safely` | You used `Rc`/`RefCell` in a public type that must be `Send + Sync` | Switch to `Arc`; when interior mutability is needed, use `Arc<Mutex<...>>` or `Arc<RwLock<...>>` |
| Throughput collapses / tasks stall after calling a blocking API inside an async function | A blocking call such as `std::fs` / `std::thread::sleep` was used in an async context, occupying an executor thread | Switch to `tokio::fs` / `tokio::time::sleep`; for genuinely blocking computation use `tokio::task::spawn_blocking` |
| `cannot find type BoxliteError in this scope` | The error type was not imported from the correct path | `use boxlite_shared::{BoxliteError, BoxliteResult};` (defined in `src/shared/src/errors.rs` and re-exported at the top level of `boxlite`) |
| Using `BoxliteError::Run(...)` fails to compile with "no variant named Run" | That variant does not exist | Use `BoxliteError::Execution(...)` for execution errors; pick an existing variant from `src/shared/src/errors.rs` by semantics |
