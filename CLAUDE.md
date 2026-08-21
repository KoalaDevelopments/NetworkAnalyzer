# CLAUDE.md — NetworkAnalyzer AI Guardrails

NetworkAnalyzer is a **federated Flutter plugin** (Dart + Kotlin + Swift),
not an application. The repo is a Dart pub workspace under `packages/`:
`network_analyzer` (app-facing, endorses the implementations),
`network_analyzer_platform_interface` (contract + `Result` core),
`network_analyzer_android` (Kotlin), `network_analyzer_ios` (Swift), and
the example app at `packages/network_analyzer/example`.

Order of precedence when rules conflict:

1. `.specify/memory/constitution.md` (v1.0.0 — supreme)
2. `guidelines.md` (Dart/Flutter style and patterns)
3. `.github/COMMIT_CONVENTION.md` (commit messages)
4. This file (operational guardrails)

Every feature goes through the Spec Kit flow: `/speckit-specify` →
`/speckit-plan` → `/speckit-tasks` → `/speckit-implement`. No feature code
lands outside that flow.

## Guidelines

Follow the Flutter and Dart guidelines in full. They override default
behavior.

@guidelines.md

## Anti-Patterns — hard rejections

Stack-specific mistakes the AI must never make:

1. Hand-written `MethodChannel`/`EventChannel` code. All Dart↔native
   messaging is pigeon-generated, per platform package, one input file per
   feature (`pigeons/<feature>.dart`).
2. Editing generated files by hand (`*.g.dart`, `*.g.kt`, `*.g.swift`).
   Change the pigeon input and regenerate.
3. Adding a capability to a platform package before declaring it in
   `network_analyzer_platform_interface`.
4. Importing `network_analyzer_android`/`network_analyzer_ios` from the
   app-facing package, the example, or any host app. Implementations are
   wired by endorsement (`default_package`) only.
5. Letting an exception cross a public API. Fallible operations return
   `Result<T, Failure>`; native errors map to typed `Failure` subtypes. A
   raw `PlatformException` reaching a caller is a defect.
6. Silent catch blocks, `print()` (use `dart:developer` `log`), or `!`
   assertions without a proven non-null guarantee.
7. Leaking pigeon message classes into public API. Generated types are
   transport DTOs; the public types are the immutable domain models in the
   platform interface, mapped inside the implementation.
8. Adding state-management, DI, or routing packages to plugin packages.
   Manual constructor injection only; the example app follows
   guidelines.md.
9. Adding any pub.dev dependency without a one-line justification in the
   commit body.
10. Blocking the UI isolate: heavy parsing without `compute()`/isolates,
    or native work outside the prescribed serial queue (iOS) /
    dispatcher (Android).
11. Measuring with wall-clock time. Throughput/latency math uses
    monotonic clocks.
12. Writing implementation before a failing test. TDD is Principle IV and
    non-negotiable.
13. Streams whose native producers keep running after the last listener
    cancels.
14. Replacing or bypassing `lib/src/core/result/` (no `dartz`, `fpdart`,
    or rewrites).
15. Committing `pubspec.lock` for packages, or touching anything under
    `_to_delete/`.

## File Limits

- Max **300 lines** per source file (Dart, Kotlin, Swift).
- Max **500 lines** per test file.
- Exempt: generated files and tool-owned files (`project.pbxproj`, etc.).
- Functions stay under 20 lines and lines under 80 chars (guidelines.md).
- A change that would cross a limit splits the file **in the same change**
  (parts / private libraries per guidelines.md) — never "refactor later".

## Internal Roles — mandatory pipeline

Run every non-trivial request through four roles, in order. Surface the
outputs of roles 1–3 briefly before writing code; run role 4 before
declaring anything done. For trivial changes a single line
(`pipeline: trivial — <reason>`) suffices.

1. **Request Parser** — restate the ask: goal, affected packages, change
   class (feature / fix / refactor / chore), and which Spec Kit stage it
   belongs to. Ambiguous requests are clarified before any file is
   touched.
2. **Scope Validator** — validate against the constitution and the active
   spec: is the capability declared in the platform interface? Is it
   inside the current feature's scope? Does it violate a principle
   (requiring Complexity Tracking justification)? Output a verdict:
   in-scope / out-of-scope, plus the constraints that apply.
3. **Planner** — ordered plan before code: contract change first, pigeon
   inputs per platform, failing tests, then implementation
   (Dart → Kotlin/Swift), listing files to touch with size-vs-limit
   awareness.
4. **Reviewer** — completion gate: `dart format`, `dart fix`,
   `dart analyze` (zero diagnostics) and all tests green; dartdoc on every
   new public API; Result pattern respected; no forbidden imports;
   generated files untouched by hand; file limits respected; commit
   message per `.github/COMMIT_CONVENTION.md`; **Map Protocol executed**.

## Git Policy

`.github/COMMIT_CONVENTION.md` is the authoritative spec — Conventional
Commits × Gitmoji with in-house tweaks. Follow its "Process for AI
Assistants" (8 steps) for every commit message. Hard rules:

- Header `[TYPE][TASK_ID?]: <gitmoji> <subject>` — TYPE uppercase, full
  word (`FEATURE`, never `feat`), `!` appended for breaking changes,
  subject in sentence case, ≤ 72 chars, no trailing period.
- Body explains **why**; bullets list the concrete files/areas, grouped by
  layer when more than ~5.
- Footers only per the convention: `Task #<id>`, `BREAKING CHANGE`
  (mandatory with `!`), `Refs: <hash>`.
- **`Co-authored-by` tags are forbidden in this repository. Never add
  them, under any circumstances.**
- One concern per commit — split rather than stretch a type.
- Commits happen when the human asks or a Spec Kit git skill runs them;
  never push with red gates.

## The Map Protocol — mandatory

Two-level recursive JSON index for fast context retrieval. Before working
on a domain, read the root map, then the domain's local map — open source
files only after that.

- **Root map — `domains_map.json`** (repo root): high-level domain index.
  Schema v2: `$schema_version`, `updated_at` (`YYYY-MM-DD`);
  `domains[]`: `id`, `map` (path to the local map), `name`,
  `status` (`planned | scaffolded | in_progress | implemented | deprecated`),
  `spec` (path or null), `public_api[]`,
  `packages{}` (coarse per-package file lists), `pigeons[]`, `notes`.
- **Local maps — `maps/<domain_id>/map.json`**: deep index of one
  domain's components across the federated packages. Schema v1:
  `$schema_version`, `domain`, `updated_at`, `status`;
  `layers{}` — `domain_models`, `failures`, `contract`, `facade`,
  `platform_dart`, `platform_native`, `transport`, `tests` — each a list
  of `{symbol, kind, file, package, summary}` entries
  (`"generated": true` marks codegen outputs);
  `dependencies{}` — `domains`, `pub`, `native`; `retrieval_hints[]`.

Mapping from generic MVC vocabulary: models → `domain_models` +
`transport`; controllers → `facade` + `contract`; services →
`platform_dart` + `platform_native`.

**Rule: after every implementation** — public API added or changed, files
created, moved, or removed, feature status advanced — update the touched
domain's **local map AND the root map in the same change/commit**. A new
domain gets `maps/<id>/map.json` plus its root entry at creation. The
Reviewer role blocks completion until both are current. Do not invent
schema keys; bump `$schema_version` deliberately.

## Quality Gates

First checkout: `./tool/bootstrap.sh` (workspace pub get → pigeon
add + codegen → format → analyze → test). Definition of done for any task
is the constitution's Development Workflow section, all gates green
locally.
