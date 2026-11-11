import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memory_item.dart';
import '../../../providers/journal_provider.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  void _showAddMemoryDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isMilestone = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF16171D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Preserve Memory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Memory / Milestone Title', prefixIcon: Icon(Icons.star_rounded))),
                    const SizedBox(height: 10),
                    TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(labelText: 'What made this moment special?')),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      title: const Text('Mark as Key Milestone'),
                      value: isMilestone,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => isMilestone = val),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        if (t.isNotEmpty) {
                          Provider.of<JournalProvider>(context, listen: false).addMemory(
                            MemoryItem(
                              id: const Uuid().v4(),
                              title: t,
                              description: descController.text.trim(),
                              date: DateTime.now(),
                              isMilestone: isMilestone,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.of(ctx).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Preserve Memory', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);
    final memories = journalProvider.memories;

    return Scaffold(
      body: memories.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 48, color: Color(0xFF8E929E)),
                  SizedBox(height: 12),
                  Text('No preserved memories yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Highlight significant personal milestones and achievements', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final mem = memories[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM d, yyyy').format(mem.date),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8E929E)),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E929E)),
                              onPressed: () => journalProvider.deleteMemory(mem.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(mem.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        if (mem.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(mem.description, style: const TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemoryDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.star_rounded, color: Colors.white),
        label: const Text('New Memory', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

