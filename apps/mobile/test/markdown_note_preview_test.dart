import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nestin/data/models/alarm_category.dart';
import 'package:nestin/data/models/note_item.dart';
import 'package:nestin/data/services/storage_service.dart';
import 'package:nestin/domain/notes/markdown_checklist_helper.dart';
import 'package:nestin/providers/note_provider.dart';
import 'package:nestin/ui/widgets/markdown_content_view.dart';
import 'package:nestin/ui/screens/organize/notes_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkdownContentView Unit Tests', () {
    test('parseInlineMarkdown accurately detects bold, italic, code, and strike', () {
      const input = 'Check out **bold**, *italic*, `inline code`, and ~~strike~~.';
      final spans = MarkdownContentView.parseInlineMarkdown(
        input,
        const TextStyle(fontSize: 14, color: Colors.white),
      );

      // Verify that parsed spans contain the formatted tokens
      expect(spans, isNotEmpty);

      // Find bold span
      final boldSpan = spans.whereType<TextSpan>().firstWhere(
            (s) => s.text == 'bold',
          );
      expect(boldSpan.style?.fontWeight, equals(FontWeight.w700));

      // Find italic span
      final italicSpan = spans.whereType<TextSpan>().firstWhere(
            (s) => s.text == 'italic',
          );
      expect(italicSpan.style?.fontStyle, equals(FontStyle.italic));

      // Find inline code span (WidgetSpan containing code text)
      final codeWidgetSpan = spans.whereType<WidgetSpan>().first;
      expect(codeWidgetSpan, isNotNull);

      // Find strikethrough span
      final strikeSpan = spans.whereType<TextSpan>().firstWhere(
            (s) => s.text == 'strike',
          );
      expect(strikeSpan.style?.decoration, equals(TextDecoration.lineThrough));
    });

    testWidgets('Renders Compact Mode in note cards with maxLines',
        (tester) async {
      const markdownSample = '''
# Weekend Checklist
- [x] Tent packed
- [ ] Buy campfire snacks
Review the `trail_map.pdf` before leaving!
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownContentView(
              content: markdownSample,
              isCompact: true,
              maxLines: 4,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MarkdownContentView), findsOneWidget);
      expect(find.textContaining('Weekend Checklist'), findsOneWidget);
      expect(find.textContaining('trail_map.pdf'), findsOneWidget);
    });

    testWidgets('Renders Full Mode with headers, bullets, and code blocks',
        (tester) async {
      const markdownSample = '''
# Main Header
## Sub Header
### Topic Notes
- First bullet item
- Second bullet item with **bold**
> Remember to breathe
```dart
void main() => print('Hello Nestin');
```
- [x] Completed task
- [ ] Incomplete task
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownContentView(
                content: markdownSample,
                isCompact: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Main Header'), findsOneWidget);
      expect(find.textContaining('Sub Header'), findsOneWidget);
      expect(find.textContaining('Topic Notes'), findsOneWidget);
      expect(find.textContaining('First bullet item'), findsOneWidget);
      expect(find.textContaining('Hello Nestin'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    });
  });

  group('NotesListScreen Markdown Live Preview Tests', () {
    late StorageService storageService;
    late NoteProvider noteProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      noteProvider = NoteProvider(storageService);
    });

    testWidgets('Renders note card with rich markdown and M↓ badge',
        (tester) async {
      final now = DateTime.now();
      await noteProvider.addNote(
        NoteItem(
          id: 'test_note_md',
          title: 'Markdown Recipe',
          content: '### Ingredients\n- 2 cups `flour`\n- **1 tsp** salt\n- [x] Sugar ready',
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NoteProvider>.value(
            value: noteProvider,
            child: const NotesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Markdown Recipe'), findsOneWidget);
      expect(find.text('M↓'), findsOneWidget); // Markdown indicator badge
      expect(find.byType(MarkdownContentView), findsWidgets);
    });

    testWidgets('Opens Note Editor and switches to Live Preview mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NoteProvider>.value(
            value: noteProvider,
            child: const NotesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap New Note FAB
      await tester.tap(find.text('New Note'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Markdown'), findsOneWidget);
      expect(find.text('Live Preview'), findsOneWidget);

      // Enter Title and Markdown Content
      await tester.enterText(find.byType(TextField).first, 'Meeting Summary');
      await tester.enterText(
        find.byType(TextField).at(1),
        '# Agenda\n- Discuss **Q4 Goals**\n- Review `api_specs`\n> All aligned.',
      );
      await tester.pumpAndSettle();

      // Switch to Live Preview tab
      await tester.tap(find.text('Live Preview'));
      await tester.pumpAndSettle();

      // Check rendered markdown in Live Preview
      expect(find.textContaining('Agenda'), findsOneWidget);
      expect(find.textContaining('Q4 Goals'), findsOneWidget);
      expect(find.textContaining('api_specs'), findsOneWidget);

      // Tap Save Note
      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      // Note saved and displayed in list!
      expect(find.text('Meeting Summary'), findsOneWidget);
    });
  });

  group('MarkdownChecklistHelper Unit Tests', () {
    test('Parses and toggles -, *, +, uppercase [X], and indented items losslessly', () {
      const source =
          '# Plan\n'
          '- [ ] Milk\n'
          '  * [x] Warm Jacket\n'
          '+ [X] Boots\r\n'
          '- [x](https://example.com)\n'
          '- [ ] Milk';

      final summary = MarkdownChecklistHelper.summarize(source);
      expect(summary.total, equals(4));
      expect(summary.completed, equals(2));

      // Toggle second occurrence of identical "- [ ] Milk" at line 5 only
      final step1 = MarkdownChecklistHelper.toggleChecklistAtLine(source, 5);
      expect(step1, isNotNull);
      final lines1 = step1!.split('\n');
      expect(lines1[1], equals('- [ ] Milk'));
      expect(lines1[5], equals('- [x] Milk'));

      // Toggle indented "* [x] Warm Jacket" back to unchecked
      final step2 = MarkdownChecklistHelper.toggleChecklistAtLine(step1, 2);
      expect(step2, isNotNull);
      expect(step2!.split('\n')[2], equals('  * [ ] Warm Jacket'));

      // Toggle uppercase "+ [X] Boots" preserves CRLF & + marker
      final step3 = MarkdownChecklistHelper.toggleChecklistAtLine(step2, 3);
      expect(step3, isNotNull);
      expect(step3!.split('\n')[3], equals('+ [ ] Boots\r'));

      // Markdown link line "- [x](https://example.com)" must NOT toggle
      expect(MarkdownChecklistHelper.toggleChecklistAtLine(step3, 4), isNull);
    });

    test('Ignores checklist syntax inside fenced code blocks and invalid indices', () {
      const source =
          '```markdown\n'
          '- [ ] Code sample item\n'
          '```\n'
          '- [ ] Real checklist item';

      final summary = MarkdownChecklistHelper.summarize(source);
      expect(summary.total, equals(1));
      expect(summary.completed, equals(0));

      expect(MarkdownChecklistHelper.toggleChecklistAtLine(source, 1), isNull);
      expect(MarkdownChecklistHelper.toggleChecklistAtLine(source, -1), isNull);
      expect(MarkdownChecklistHelper.toggleChecklistAtLine(source, 99), isNull);

      final updated = MarkdownChecklistHelper.toggleChecklistAtLine(source, 3);
      expect(updated, contains('- [x] Real checklist item'));
      expect(updated, contains('- [ ] Code sample item'));
    });
  });

  group('Direct Note Checklist Toggle Integration & Widget Tests', () {
    late StorageService storageService;
    late NoteProvider noteProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      noteProvider = NoteProvider(storageService);
    });

    test('NoteProvider.toggleChecklistItem toggles content and persists to StorageService',
        () async {
      final now = DateTime(2026, 11, 14, 9, 0);
      await noteProvider.addNote(
        NoteItem(
          id: 'checklist_persist_1',
          title: 'Pack Bag',
          content: '- [ ] Passport\n- [x] Ticket',
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final toggled = await noteProvider.toggleChecklistItem(
        'checklist_persist_1',
        0,
      );
      expect(toggled, isTrue);

      final reloadedProvider = NoteProvider(storageService);
      final persistedNote = reloadedProvider.notes
          .firstWhere((n) => n.id == 'checklist_persist_1');
      expect(persistedNote.content, equals('- [x] Passport\n- [x] Ticket'));
      expect(persistedNote.checklistSummary.completed, equals(2));
      expect(persistedNote.checklistSummary.total, equals(2));

      // Non-checklist line / unknown id safely returns false
      expect(
        await noteProvider.toggleChecklistItem('missing_note', 0),
        isFalse,
      );
      expect(
        await noteProvider.toggleChecklistItem('checklist_persist_1', 5),
        isFalse,
      );
    });

    testWidgets('Compact MarkdownContentView handles 6+ lines with maxLines: 4 and reports exact lineIndex',
        (tester) async {
      int? tappedLine;
      const longChecklist =
          '- [ ] Item one\n'
          '- [x] Item two\n'
          '- [ ] Item three\n'
          '- [ ] Item four\n'
          '- [ ] Item five\n'
          '- [ ] Item six';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MarkdownContentView(
                content: longChecklist,
                isCompact: true,
                maxLines: 4,
                onChecklistToggle: (index) => tappedLine = index,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('markdown_checkbox_2')));
      await tester.pump();
      expect(tappedLine, equals(2));
    });

    testWidgets('Tapping checkbox directly on Note Card toggles state without opening editor',
        (tester) async {
      final now = DateTime.now().add(const Duration(minutes: 1));
      await noteProvider.addNote(
        NoteItem(
          id: 'note_card_checklist',
          title: 'Grocery List',
          content: '- [ ] Fresh oats\n- [x] Green tea',
          category: AlarmCategory.fromType(AlarmCategoryType.personal),
          isPinned: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NoteProvider>.value(
            value: noteProvider,
            child: const NotesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts at 1/2
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Edit Note'), findsNothing);

      final cardFinder = find.ancestor(
        of: find.text('Grocery List'),
        matching: find.byType(Card),
      );

      // Tap the unchecked checkbox (line 0) inside the card
      final uncheckedBox = find.descendant(
        of: cardFinder,
        matching: find.byKey(const ValueKey('markdown_checkbox_0')),
      );
      await tester.tap(uncheckedBox);
      await tester.pumpAndSettle();

      // Editor must NOT have opened; state & progress badge update inline
      expect(find.text('Edit Note'), findsNothing);
      expect(find.text('2/2'), findsOneWidget);
      final updated = noteProvider.notes
          .firstWhere((n) => n.id == 'note_card_checklist');
      expect(updated.content, equals('- [x] Fresh oats\n- [x] Green tea'));

      // Tap the same checkbox again to uncheck back to 1/2
      await tester.tap(
        find.descendant(
          of: cardFinder,
          matching: find.byKey(const ValueKey('markdown_checkbox_0')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Note'), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
      expect(
        noteProvider.notes
            .firstWhere((n) => n.id == 'note_card_checklist')
            .content,
        equals('- [ ] Fresh oats\n- [x] Green tea'),
      );

      // Tapping the note title STILL opens the full note editor
      await tester.tap(find.text('Grocery List'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Note'), findsOneWidget);

      // Switching to Live Preview also allows toggling checkbox & saving
      await tester.tap(find.text('Live Preview'));
      await tester.pumpAndSettle();

      final livePreviewView = find.byWidgetPredicate(
        (w) => w is MarkdownContentView && !w.isCompact,
      );
      await tester.tap(
        find.descendant(
          of: livePreviewView,
          matching: find.byKey(const ValueKey('markdown_checkbox_0')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Note'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Note'), findsNothing);
      expect(find.text('2/2'), findsOneWidget);
    });
  });
}
