import 'package:flutter/material.dart';

import '../models/attention_state.dart';
import '../theme/app_theme.dart';

/// A minimal, deliberately plain visualization of recent readings — a row of
/// colored bars, one per reading, newest on the right. This is the Monitor
/// tab's short-term "last few minutes" glance; the full searchable history
/// lives on the Dashboard tab.
class AttentionTimeline extends StatelessWidget {
  final List<AttentionReading> readings;

  const AttentionTimeline({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return Center(
        child: Text(
          'No readings yet.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last few minutes', style: AppTheme.sectionLabel(context)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: readings.length,
              itemBuilder: (context, index) {
                final reading = readings[index];
                return Tooltip(
                  message: '${reading.state.label} @ ${reading.timestamp.toIso8601String()}',
                  child: Container(
                    width: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: reading.state.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
