import 'package:flutter/material.dart';
import 'package:network_analyzer/network_analyzer.dart';

/// Shows the event stream as a log, newest first.
class EventsTab extends StatefulWidget {
  /// Creates the tab.
  const EventsTab({required this.events, super.key});

  /// The stream to render.
  final Stream<MonitorEvent> events;

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final List<MonitorEvent> _log = <MonitorEvent>[];

  @override
  void initState() {
    super.initState();
    widget.events.listen((MonitorEvent event) {
      if (mounted) {
        setState(() => _log.insert(0, event));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_log.isEmpty) {
      return const Center(child: Text('Start monitoring to see events.'));
    }
    return ListView.builder(
      key: const Key('events-list'),
      itemCount: _log.length,
      itemBuilder: (BuildContext context, int index) =>
          _EventTile(event: _log[index]),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final MonitorEvent event;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(event.kind.name),
    subtitle: Text(event.message),
    // Timestamps arrive in UTC precisely so a host can localise them here.
    trailing: Text(
      event.timestamp.toLocal().toIso8601String().substring(11, 19),
    ),
  );
}
