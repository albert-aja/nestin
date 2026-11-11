import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'notes_list_screen.dart';
import 'collections_list_screen.dart';
import 'wishlist_screen.dart';

class OrganizeHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const OrganizeHubScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organize'),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: Color(0xFF8E929E),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.notes_rounded, size: 18), text: 'Notes'),
              Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Collections'),
              Tab(icon: Icon(Icons.card_giftcard_rounded, size: 18), text: 'Wishlist'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NotesListScreen(),
            CollectionsListScreen(),
            WishlistScreen(),
          ],
        ),
      ),
    );
  }
}

