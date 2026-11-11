import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/wishlist_item.dart';
import '../../../data/models/alarm_category.dart';
import '../../../data/models/task_item.dart';
import '../../../providers/collection_provider.dart';
import '../../widgets/category_badge.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  void _showAddWishlistDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    AlarmCategory category = AlarmCategory.fromType(AlarmCategoryType.personal);

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
                        const Text('Add to Wishlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Item Name', prefixIcon: Icon(Icons.card_giftcard_rounded))),
                    const SizedBox(height: 10),
                    TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description / Notes')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Estimated Price (\$)', prefixIcon: Icon(Icons.attach_money_rounded)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8E929E))),
                    const SizedBox(height: 6),
                    Row(
                      children: TaskPriority.values.map((p) {
                        final isSelected = priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: isSelected,
                            label: Text(p.name.toUpperCase()),
                            selectedColor: AppColors.primary,
                            onSelected: (val) {
                              if (val) setState(() => priority = p);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final t = titleController.text.trim();
                        final price = double.tryParse(priceController.text.trim());
                        if (t.isNotEmpty) {
                          Provider.of<CollectionProvider>(context, listen: false).addWishlistItem(
                            WishlistItem(
                              id: const Uuid().v4(),
                              title: t,
                              description: descController.text.trim(),
                              targetPrice: price,
                              priority: priority,
                              category: category,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Navigator.of(ctx).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.catHealth,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Add to Wishlist', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
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
    final provider = Provider.of<CollectionProvider>(context);
    final items = provider.wishlist;

    return Scaffold(
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_rounded, size: 48, color: Color(0xFF8E929E)),
                  SizedBox(height: 12),
                  Text('Wishlist is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Save things you would love to acquire or explore', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isPurchased,
                          activeColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (_) => provider.toggleWishlistPurchased(item.id),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CategoryBadge(category: item.category, compact: true),
                                  if (item.targetPrice != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      item.formattedPrice(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                                  color: item.isPurchased ? const Color(0xFF8E929E) : Colors.white,
                                ),
                              ),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.description, style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF8E929E)),
                          onPressed: () => provider.deleteWishlistItem(item.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWishlistDialog(context),
        backgroundColor: AppColors.catHealth,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
      ),
    );
  }
}

