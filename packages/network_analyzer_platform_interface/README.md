# network_analyzer_platform_interface

A common platform interface for the
[`network_analyzer`](https://pub.dev/packages/network_analyzer) plugin.

This package defines the contract (`NetworkAnalyzerPlatform`) that platform
implementations must extend, the shared domain types, and the
`Result`/`Failure` core mandated by the project guidelines.

## Usage

To implement a new platform-specific implementation of `network_analyzer`,
extend `NetworkAnalyzerPlatform` with an implementation that performs the
platform-specific behavior, and register it with the static
`NetworkAnalyzerPlatform.instance` setter from the package's
`dartPluginClass` entry point.

## Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the
interface) over breaking changes for this package. Extending this class
(instead of implementing it) is what makes add-only evolution possible
(constitution, Principle II).
