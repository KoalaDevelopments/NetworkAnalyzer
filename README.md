# NetworkAnalyzer

A federated Flutter plugin to monitor and analyze network connectivity on
mobile devices. Planned API surface: real-time monitoring, scanner
(download/upload throughput in Mbps), scanner history, and diagnostic tools
(MTR, Ping, TCPing).

Governance lives in `.specify/memory/constitution.md`. Implementation style
is bound by `guidelines.md`. Features follow the Spec Kit flow
(`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
`/speckit-implement`).

## Repository layout

| Package | Role |
| --- | --- |
| `packages/network_analyzer` | App-facing package. The only dependency host apps declare. Endorses the platform implementations. |
| `packages/network_analyzer_platform_interface` | The platform contract (`NetworkAnalyzerPlatform`), shared domain types, and the `Result`/`Failure` core. |
| `packages/network_analyzer_android` | Android implementation — Kotlin, pigeon-typed messages. |
| `packages/network_analyzer_ios` | iOS implementation — Swift (SPM layout + CocoaPods podspec), pigeon-typed messages. |
| `packages/network_analyzer/example` | Example app and integration-test host. |

The repository is a Dart pub workspace: run `flutter pub get` once at the
root and every package resolves together.

## Bootstrap (first checkout)

```shell
./tool/bootstrap.sh
```

The script resolves the workspace, adds `pigeon` to the platform packages
(first run only), generates the typed message layer for both platforms
(`lib/src/messages.g.dart`, `Messages.g.kt`, `Messages.g.swift`), then runs
the format/analyze/test gates. Generated files are committed after the
first run; the platform packages do not compile before codegen, by design —
the wire layer only exists as generated code, never hand-written.

## Platform communication

Dart↔native messaging uses pigeon exclusively (constitution, Principle II).
Each platform package owns its pigeon definition in `pigeons/messages.dart`
and its generated output; the wire format is a private implementation
detail of the platform package, not part of the platform interface
contract. The current surface is a deliberately minimal bootstrap probe
(`getBridgeInfo`) proving the round-trip; the real feature APIs are added
per feature through the Spec Kit flow, starting with real-time monitoring.
