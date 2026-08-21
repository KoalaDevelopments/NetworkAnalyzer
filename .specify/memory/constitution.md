<!--
Sync Impact Report
==================
Version change: [template] → 1.0.0 (initial ratification)
Modified principles: n/a — all template placeholders replaced with concrete content
Added sections:
  - Core Principles (I–VI)
  - Security, Identity & Permissions
  - Data Management
  - Infrastructure & External Integrations
  - Development Workflow & Quality Gates
  - Governance
Removed sections: none
Templates:
  - ✅ .specify/templates/tasks-template.md — updated: test tasks are now MANDATORY per
       Principle IV (previously "OPTIONAL - only if requested")
  - ✅ .specify/templates/plan-template.md — no changes required; the Constitution Check
       gate is populated at plan time from this file
  - ✅ .specify/templates/spec-template.md — no changes required
  - ✅ .specify/templates/checklist-template.md — no changes required
  - ➖ .claude/skills/speckit-* — stock Spec Kit 0.12.16 skills, not modified
Follow-up TODOs: none. guidelines.md (normative reference) added at repository root.
-->

# NetworkAnalyzer Constitution

NetworkAnalyzer is a federated Flutter/Dart plugin that monitors and analyzes network
connectivity on mobile devices. It exposes an API-facing surface for four capabilities:
real-time monitoring, scanner (download/upload throughput in Mbps), scanner history, and
diagnostic tools (MTR, Ping, TCPing). This constitution defines the non-negotiable rules
that govern its design, implementation, and evolution.

## Core Principles

### I. Federated, API-First Architecture

The plugin follows the federated plugin architecture, composed of four packages in a single
repository:

- `network_analyzer` — the app-facing package. The ONLY package host applications depend on.
- `network_analyzer_platform_interface` — the single source of truth for the platform
  contract.
- `network_analyzer_android` — Android implementation (Kotlin).
- `network_analyzer_ios` — iOS implementation (Swift).

Rules:

- Every capability MUST be declared in the platform interface before any platform
  implements it. No feature exists only in an implementation package.
- Host applications MUST integrate exclusively through `network_analyzer`. Platform
  implementations are endorsed via `default_package` in the pubspec and MUST NOT be
  imported directly by consumers.
- The public Dart API is designed from the caller's perspective: intuitive, hard to misuse,
  and documented with `dartdoc` and runnable examples before release.
- Plugin packages ship no UI. Presentation concerns exist only in the example app.

Rationale: federation keeps platform code independently testable and replaceable, and
permits future targets (desktop, web) without breaking the public API.

### II. Typed, Versioned Platform Contracts

- Dart↔native communication MUST use typed, code-generated messages (pigeon). Hand-written
  `MethodChannel` calls passing dynamic maps are prohibited in new code; any exception
  requires written justification in the plan's Complexity Tracking table.
- The platform interface MUST extend `PlatformInterface` with token verification and MUST
  evolve add-only. Removing or redefining a contract member is a breaking change: it
  requires a MAJOR version bump and a written migration path.
- Android and iOS MUST implement identical semantics for every contract member. A platform
  that cannot honor a semantic MUST return a typed failure — never a silently degraded or
  fabricated result.
- All packages follow Semantic Versioning. The platform interface version dictates the
  compatibility floor for every dependent package.

### III. Result-Based Error Handling — No Silent Failures

- Every fallible public operation returns `Result<T, Failure>` as specified in
  guidelines.md. The canonical implementation lives in `lib/core/result/` and MUST NOT be
  replaced by third-party alternatives such as `dartz` or `fpdart`.
- Exceptions MUST NOT escape the public API boundary. Native errors are caught and mapped
  to typed, domain-specific `Failure` subtypes (e.g. `PermissionFailure`, `SocketFailure`,
  `TimeoutFailure`, `UnsupportedPlatformFailure`) carrying `message` and optional
  `details`. A raw `PlatformException` reaching a caller is a defect.
- Failures are logged with `dart:developer` `log` — `print` is prohibited — and always
  surfaced to the caller. Empty or swallowing catch blocks are prohibited.

### IV. Test-First (NON-NEGOTIABLE)

- TDD is mandatory: tests are written first, observed to fail, then implementation follows.
  Red-Green-Refactor is strictly enforced.
- Dart unit tests use `package:test` / `flutter_test` with `package:checks` assertions.
  Platform interface consumers are tested against fakes; mocks are a last resort and never
  code-generated.
- Native logic is unit-tested with XCTest (Swift) and JUnit (Kotlin). End-to-end flows run
  with `package:integration_test` on both Android and iOS.
- Measurement logic — throughput computation, aggregation, MTR/Ping/TCPing parsing — MUST
  be covered by deterministic unit tests over fixed fixtures. No test may depend on live
  network conditions to pass.
- Tests follow Arrange-Act-Assert. A red pipeline blocks merge without exception.

### V. Streams for Continuous Data, Futures for Discrete Operations

- Continuous data — real-time monitoring, in-progress scan and tool updates — is exposed as
  `Stream`s. Discrete operations — a single ping run, a history query — return `Future`s.
- Every stream documents its emission cadence and cancellation behavior. When the last
  listener cancels, the native producer MUST stop within a bounded, documented time.
  Orphaned native work is a defect.
- Long-running operations (scanner, MTR) MUST be cancelable from Dart, and cancellation
  MUST propagate to the native side.
- Operations are single-flight per category; re-entrant execution is rejected with a typed
  failure (see Data Management).

### VI. Measurement Integrity & Performance Discipline

- The plugin MUST NOT distort what it measures. Timing uses monotonic clocks; measurement
  I/O and computation run off the UI thread — native queues/dispatchers on the platform
  side, isolates or `compute()` for heavy parsing on the Dart side.
- The host application's UI isolate is never blocked. Idle overhead of real-time monitoring
  MUST be negligible and its budget documented.
- Reported units are standardized: Mbps for throughput, milliseconds for latency, and
  percentage for packet loss, each with documented precision and rounding rules.
- Bandwidth-consuming operations (scanner) run only on explicit caller request. The plugin
  MUST NOT schedule them autonomously.

## Security, Identity & Permissions

- NetworkAnalyzer is device-local. It defines no user accounts and performs no
  authentication: identity is the host application's domain, and the plugin API remains
  auth-agnostic by design. Plugin packages MUST NOT collect, store, or transmit PII or
  persistent device identifiers.
- Least privilege: each feature documents the exact Android permissions and iOS
  entitlements / Info.plist keys it requires, in both `dartdoc` and the package README.
  Nothing beyond the documented set is declared.
- A missing or denied OS permission produces a typed `PermissionFailure` with remediation
  guidance. It MUST never crash the host app and MUST never yield fabricated data.
- Platform capability limits — e.g. iOS restrictions on raw sockets affecting ICMP-based
  tools — MUST be documented in the platform interface and surfaced as typed failures or
  documented alternative strategies, never silently emulated with misleading results.
- Transport security: scanner endpoints default to HTTPS, and certificate validation MUST
  never be disabled. Raw TCP/ICMP usage is confined to the diagnostic tools that require it
  and is documented per tool.

## Data Management

- All persisted state is device-local. Scanner History is the only durable store and is
  owned exclusively by the plugin.
- The history schema is versioned from v1. Migrations are forward-only, ship in the same
  release as the schema change, and are covered by tests.
- Indexing: history queries filter by time range and network identifier and MUST be
  index-backed. Full-store scans on hot paths are prohibited. Reads are paginated;
  unbounded result sets are prohibited.
- Concurrency:
  - Single-flight per operation category: at most one scanner run, one MTR session, one
    ping sequence at a time. Re-entrant execution is rejected with a typed failure,
    following the Command pattern defined in guidelines.md.
  - Native mutable state is confined to a single serial queue (iOS) or dispatcher
    (Android). Results are marshaled onto the thread the Flutter engine requires.
  - History writes are single-writer. Reads MUST NOT block the emission of live
    monitoring events.
- Retention is caller-configurable (maximum entries and/or maximum age) with documented
  defaults, and a `clearHistory` operation MUST always be available.

## Infrastructure & External Integrations

- The plugin's only permitted external touchpoints are measurement targets: speed-test
  endpoints and Ping/MTR/TCPing hosts. Analytics, telemetry, and crash-reporting SDKs are
  prohibited inside plugin packages.
- Every measurement target is injected configuration with documented, overridable defaults.
  Host applications MUST be able to point every tool at their own infrastructure.
- Every external touchpoint sits behind a repository/service abstraction so fakes can be
  injected in tests. API-facing classes make no direct network calls.
- Every network operation defines an explicit timeout with a documented default. Unbounded
  waits are prohibited.
- Dependency policy: minimal by default. Each new pub.dev dependency MUST be justified in
  its pull request. State-management, DI, and routing packages are prohibited in plugin
  packages; the example app follows guidelines.md (built-in solutions first, BLoC/Cubit
  when state complexity warrants it).

## Development Workflow & Quality Gates

- `guidelines.md` (Flutter & Dart Guidelines, repository root) is the binding
  implementation reference for all Dart code: Effective Dart style, 80-character lines,
  the `analysis_options.yaml` baseline, `dartdoc` on every public API, structured logging,
  and `build_runner` for all code generation. Its UI-specific sections — routing, theming,
  layout, visual design, state management — bind the example app only.
- Swift code follows the Swift API Design Guidelines; Kotlin code follows the official
  Kotlin coding conventions. Platform linting runs in CI.
- Definition of done, enforced in CI on every PR: `dart format` clean, `dart fix --apply`
  applied, `dart analyze` with zero diagnostics, all Dart, native, and integration tests
  green, and public API documentation updated.
- The example app MUST exercise every public API feature and serves as the manual
  verification surface on both platforms.
- Every feature follows the Spec Kit flow: `/speckit-specify` → `/speckit-plan`
  (Constitution Check gate) → `/speckit-tasks` → `/speckit-implement`.

## Governance

- This constitution supersedes all other practices in this repository. Order of
  precedence: this constitution → guidelines.md → official platform style guides.
  Conflicts resolve upward.
- Amendments require a pull request that edits this file with a rationale, applies a
  semantic version bump, updates the Sync Impact Report, and propagates changes to the
  dependent Spec Kit templates.
- Versioning policy: MAJOR for removed or redefined principles and other
  backward-incompatible governance changes; MINOR for new principles or sections and
  materially expanded guidance; PATCH for clarifications, wording, and typo fixes.
- Compliance review: the `/speckit-plan` Constitution Check gates every feature before
  design begins, and every PR review verifies adherence to these principles. Violations
  are either fixed or explicitly justified in the plan's Complexity Tracking table;
  undocumented deviations are rejected.

**Version**: 1.0.0 | **Ratified**: 2026-08-20 | **Last Amended**: 2026-08-20
