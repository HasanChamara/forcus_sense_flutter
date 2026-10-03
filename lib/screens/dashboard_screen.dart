import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attention_state.dart';
import '../services/attention_controller.dart';
import '../theme/app_theme.dart';

/// Dashboard tab: the full attention/fatigue detection history, as a list.
/// This is the "visible output" / session log the break-alert engine feeds —
/// see AttentionController._recordReading for what gets logged and why.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<AttentionController>(
            builder: (context, controller, _) => IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: controller.historyEvents.isEmpty
                  ? null
                  : () => _confirmClear(context, controller),
            ),
          ),
        ],
      ),
      body: Consumer<AttentionController>(
        builder: (context, controller, _) {
          final events = controller.historyEvents;
          if (events.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildGroupedList(context, events);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No history yet', style: AppTheme.headline(context)),
            const SizedBox(height: 8),
            Text(
              'Keep the Monitor tab running during a work session — changes '
              'in your attention and fatigue will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, List<HistoryEvent> events) {
    final groups = _groupByDay(events);
    final dayKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dayKeys.length,
      itemBuilder: (context, groupIndex) {
        final dayKey = dayKeys[groupIndex];
        final dayEvents = groups[dayKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(_dayLabel(dayKey), style: AppTheme.sectionLabel(context)),
            ),
            ...dayEvents.map((e) => _HistoryTile(event: e)),
          ],
        );
      },
    );
  }

  Map<DateTime, List<HistoryEvent>> _groupByDay(List<HistoryEvent> events) {
    final map = <DateTime, List<HistoryEvent>>{};
    for (final event in events) {
      final day = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
      map.putIfAbsent(day, () => []).add(event);
    }
    return map;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'TODAY';
    if (day == yesterday) return 'YESTERDAY';
    return DateFormat('EEEE, MMM d').format(day).toUpperCase();
  }

  void _confirmClear(BuildContext context, AttentionController controller) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all logged attention/fatigue entries. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.clearHistory();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEvent event;
  const _HistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final state = event.state;
    final time = DateFormat('h:mm a').format(event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: state.color.withValues(alpha: 0.15),
            child: Icon(state.icon, color: state.color, size: 20),
          ),
          title: Text(
            event.isSustainedAlert ? 'Break suggested — ${state.label.toLowerCase()}' : state.label,
            style: TextStyle(
              fontWeight: event.isSustainedAlert ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            event.eyeAspectRatio != null
                ? '$time  ·  EAR ${event.eyeAspectRatio!.toStringAsFixed(2)}'
                : time,
          ),
          trailing: event.isSustainedAlert
              ? Icon(Icons.notifications_active_rounded, color: AppTheme.alertColor, size: 20)
              : null,
        ),
      ),
    );
  }
}
