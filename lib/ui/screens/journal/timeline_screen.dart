import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/journal_provider.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);
    final timelineItems = journalProvider.getUnifiedTimeline();

    return Scaffold(
      body: timelineItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timeline_rounded, size: 48, color: Color(0xFF8E929E)),
                  SizedBox(height: 12),
                  Text('Timeline is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Add diary entries or milestone memories to see your life feed', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: timelineItems.length,
              itemBuilder: (context, index) {
                final item = timelineItems[index];
                final isLast = index == timelineItems.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline vertical spine & icon
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: item.color, width: 1.5),
                            ),
                            child: Icon(item.icon, size: 16, color: item.color),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: const Color(0xFF2C2F3A),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Content Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.color.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.typeTag,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: item.color),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(item.date),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF8E929E)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB), height: 1.4),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

