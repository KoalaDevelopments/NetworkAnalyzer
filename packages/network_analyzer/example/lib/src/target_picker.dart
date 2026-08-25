import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

/// Chooses what to monitor and how.
///
/// Covers both monitor kinds, all three protocols, every bundled preset and a
/// custom target, so the example exercises the whole configuration surface.
class TargetPicker extends StatelessWidget {
  /// Creates the picker.
  const TargetPicker({
    required this.kind,
    required this.protocol,
    required this.host,
    required this.onKindChanged,
    required this.onProtocolChanged,
    required this.onHostChanged,
    super.key,
  });

  /// The selected monitor kind.
  final MonitorKind kind;

  /// The selected probe protocol.
  final MonitorProtocol protocol;

  /// The selected target.
  final MonitorHost host;

  /// Called when the monitor kind changes.
  final ValueChanged<MonitorKind> onKindChanged;

  /// Called when the probe protocol changes.
  final ValueChanged<MonitorProtocol> onProtocolChanged;

  /// Called when the target changes.
  final ValueChanged<MonitorHost> onHostChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<MonitorKind>(
          key: const Key('kind-picker'),
          segments: const <ButtonSegment<MonitorKind>>[
            ButtonSegment<MonitorKind>(
              value: MonitorKind.internet,
              label: Text('Internet'),
              icon: Icon(Icons.public),
            ),
            ButtonSegment<MonitorKind>(
              value: MonitorKind.gateway,
              label: Text('Gateway'),
              icon: Icon(Icons.router),
            ),
          ],
          selected: <MonitorKind>{kind},
          onSelectionChanged: (Set<MonitorKind> selection) =>
              onKindChanged(selection.first),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MonitorProtocol>(
          key: const Key('protocol-picker'),
          segments: <ButtonSegment<MonitorProtocol>>[
            for (final MonitorProtocol value in MonitorProtocol.values)
              ButtonSegment<MonitorProtocol>(
                value: value,
                label: Text(value.name.toUpperCase()),
                // A gateway monitor rejects UDP by construction.
                enabled:
                    kind == MonitorKind.internet ||
                    value != MonitorProtocol.udp,
              ),
          ],
          selected: <MonitorProtocol>{protocol},
          onSelectionChanged: (Set<MonitorProtocol> selection) =>
              onProtocolChanged(selection.first),
        ),
        if (kind == MonitorKind.internet) ...<Widget>[
          const SizedBox(height: 8),
          _HostPicker(host: host, onHostChanged: onHostChanged),
        ],
      ],
    ),
  );
}

class _HostPicker extends StatelessWidget {
  const _HostPicker({required this.host, required this.onHostChanged});

  static final MonitorHost _custom = CustomHost(
    hostName: 'Custom (Quad9)',
    primaryIPv4: '9.9.9.9',
  );

  final MonitorHost host;
  final ValueChanged<MonitorHost> onHostChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<MonitorHost>(
    key: const Key('host-picker'),
    initialValue: host,
    decoration: const InputDecoration(
      labelText: 'Target',
      border: OutlineInputBorder(),
    ),
    items: <DropdownMenuItem<MonitorHost>>[
      for (final PresetHost preset in PresetHost.values)
        DropdownMenuItem<MonitorHost>(
          value: preset,
          child: Text('${preset.hostName} (${preset.primaryIPv4})'),
        ),
      DropdownMenuItem<MonitorHost>(
        value: _custom,
        child: Text('${_custom.hostName} (${_custom.primaryIPv4})'),
      ),
    ],
    onChanged: (MonitorHost? value) {
      if (value != null) {
        onHostChanged(value);
      }
    },
  );
}
