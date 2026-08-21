#!/usr/bin/env bash
# Bootstraps the workspace on a machine with the Flutter SDK installed.
#
# 1. Resolves dependencies for every workspace package.
# 2. Adds pigeon as a dev dependency of the platform packages (first run
#    only) so the constraint is written by pub against the live registry.
# 3. Runs pigeon codegen for Android (Kotlin) and iOS (Swift).
# 4. Applies the formatting/lint gates required by the constitution.
#
# Run from anywhere: ./tool/bootstrap.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo '==> flutter pub get (workspace)'
flutter pub get

for pkg in packages/network_analyzer_android packages/network_analyzer_ios; do
  (
    cd "$pkg"
    if ! grep -q '^  pigeon:' pubspec.yaml; then
      echo "==> adding pigeon dev dependency to $pkg"
      flutter pub add dev:pigeon
    fi
    echo "==> pigeon codegen for $pkg"
    dart run pigeon --input pigeons/messages.dart
  )
done

echo '==> dart format'
dart format .

echo '==> flutter analyze'
flutter analyze

echo '==> dart tests (per package)'
for pkg in \
  packages/network_analyzer_platform_interface \
  packages/network_analyzer \
  packages/network_analyzer_android \
  packages/network_analyzer_ios; do
  (cd "$pkg" && flutter test)
done

cat <<'EOF'

Bootstrap complete.

Manual follow-ups (need a device/emulator):
  cd packages/network_analyzer/example
  flutter run                                   # exercise the bootstrap API
  flutter test integration_test                 # end-to-end round-trip

After the first successful codegen, commit the generated files
(lib/src/messages.g.dart, Messages.g.kt, Messages.g.swift) and the pigeon
constraint pub wrote into the platform packages' pubspecs.
EOF
