import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/collection_item.dart';
import '../../../providers/collection_provider.dart';

class CollectionsListScreen extends StatelessWidget {
  const CollectionsListScreen({super.key});

  void _showAddCollectionDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Custom List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'List Title (e.g. Packing, Books, Gift Ideas)')),
              const SizedBox(height: 10),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description (Optional)')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = titleController.text.trim();
                  if (t.isNotEmpty) {
                    Provider.of<CollectionProvider>(context, listen: false).addCollection(
                      CollectionItem(
                        id: const Uuid().v4(),
                        title: t,
                        description: descController.text.trim(),
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
                child: const Text('Create List', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddEntryDialog(BuildContext context, String collectionId) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Entry'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Item name...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Provider.of<CollectionProvider>(context, listen: false).addEntryToCollection(collectionId, text);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CollectionProvider>(context);
    final collections = provider.collections;

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final col = collections[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(col.colorValue).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(col.displayIcon, color: Color(col.colorValue), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(col.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            if (col.description.isNotEmpty)
                              Text(col.description, style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                        tooltip: 'Add Entry',
                        onPressed: () => _showAddEntryDialog(context, col.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E929E)),
                        onPressed: () => provider.deleteCollection(col.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  if (col.totalCount > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: col.progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFF282A32),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Entries
                  if (col.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No items yet. Tap + to add items.', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                    )
                  else
                    ...col.entries.map((entry) => InkWell(
                          onTap: () => provider.toggleEntryCheck(col.id, entry.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  entry.isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: entry.isChecked ? AppColors.success : const Color(0xFF8E929E),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: entry.isChecked ? TextDecoration.lineThrough : null,
                                      color: entry.isChecked ? const Color(0xFF8E929E) : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCollectionDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New List', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
