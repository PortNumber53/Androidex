import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/codex_controller.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models.dart';
import 'package:mobile/widgets.dart';

void main() {
  testWidgets('sessions fill the screen and switch with a horizontal swipe', (
    tester,
  ) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Build the mobile client'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(PersistentActionBar), findsOneWidget);
    expect(find.byType(ComposerBar), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Swipe sessions  ·  1 of 2'), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    final sessionPicker = find.byType(SessionPickerSheet);
    expect(
      find.descendant(
        of: sessionPicker,
        matching: find.text('/workspace/androidex'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: sessionPicker,
        matching: find.text('Build the mobile client'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sessionPicker,
        matching: find.text('Review backend changes'),
      ),
      findsOneWidget,
    );

    final sessionActions = find.descendant(
      of: sessionPicker,
      matching: find.byTooltip('Session actions'),
    );
    expect(sessionActions, findsNWidgets(2));
    await tester.tap(sessionActions.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename session'));
    await tester.pumpAndSettle();

    final renameDialog = find.byType(RenameSessionDialog);
    expect(renameDialog, findsOneWidget);
    await tester.enterText(
      find.descendant(of: renameDialog, matching: find.byType(TextField)),
      'Mobile session name',
    );
    await tester.tap(
      find.descendant(
        of: renameDialog,
        matching: find.widgetWithText(FilledButton, 'Rename'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: sessionPicker,
        matching: find.text('Mobile session name'),
      ),
      findsOneWidget,
    );

    Navigator.of(tester.element(sessionPicker)).pop();
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Review backend changes'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Swipe sessions  ·  2 of 2'), findsOneWidget);
  });

  testWidgets('composer offers slash command suggestions', (tester) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    final composerField = find.descendant(
      of: find.byType(ComposerBar),
      matching: find.byType(TextField),
    );

    await tester.enterText(composerField, '/rev');
    await tester.pump();

    expect(find.byKey(const ValueKey('slash-command-menu')), findsOneWidget);
    expect(find.text('/review [instructions]'), findsOneWidget);
    expect(find.text('/compact'), findsNothing);
  });

  testWidgets('session picker groups sessions by working folder', (
    tester,
  ) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);
    controller.sessions.last.workspace = '/workspace/backend';

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('session-workspace-/workspace/androidex')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('session-workspace-/workspace/backend')),
      findsOneWidget,
    );
    expect(find.text('/workspace/androidex'), findsOneWidget);
    expect(find.text('/workspace/backend'), findsOneWidget);
  });

  testWidgets('account menu exposes profile and settings while connecting', (
    tester,
  ) async {
    final controller = CodexController(
      initialServerUrl: 'http://10.0.2.2:40001',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pump();

    expect(find.text('Connecting to Codex…'), findsOneWidget);
    expect(find.byType(PersistentActionBar), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ServerSettingsPage), findsOneWidget);
    expect(find.text('Codex server'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Keep connected in background'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.tap(find.widgetWithText(FilledButton, 'Save settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.backgroundConnectionEnabled, isFalse);
    expect(find.text('Settings updated.'), findsOneWidget);
  });

  testWidgets('account menu opens the profile page', (tester) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Shared Codex app-server account'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Connected · realtime reconnecting'), findsOneWidget);
  });

  testWidgets(
    'session picker sorts active then folder then title without changing selection',
    (tester) async {
      final controller = CodexController(preview: true);
      addTearDown(controller.dispose);
      controller.sessions.first
        ..title = 'Z active'
        ..workspace = '/z';
      controller.sessions.last
        ..title = 'Zulu'
        ..workspace = '/a';
      controller.sessions.add(
        MobileSession(localId: 'alpha', title: 'Alpha', workspace: '/a'),
      );

      await tester.pumpWidget(CodexMobileApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();

      final picker = find.byType(SessionPickerSheet);
      final tiles = tester
          .widgetList<ListTile>(
            find.descendant(of: picker, matching: find.byType(ListTile)),
          )
          .where((tile) => tile.title is Text)
          .toList();
      expect(tiles.map((tile) => (tile.title as Text).data), [
        'Z active',
        'Alpha',
        'Zulu',
      ]);
      expect(controller.sessions.first.title, 'Z active');
      expect(controller.selectedSession?.title, 'Z active');
      expect(find.byTooltip('Reorder session'), findsNothing);
      final selectedTile = tester
          .widgetList<ListTile>(
            find.descendant(of: picker, matching: find.byType(ListTile)),
          )
          .where((tile) => tile.selected);
      expect(selectedTile, hasLength(1));

      Navigator.of(tester.element(picker)).pop();
      await tester.pumpAndSettle();

      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, closeTo(0, .01));
    },
  );

  testWidgets('session picker searches and selects original session indices', (
    tester,
  ) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    final picker = find.byType(SessionPickerSheet);
    final search = find.byKey(const ValueKey('session-search-field'));
    expect(search, findsOneWidget);

    await tester.enterText(search, 'review backend');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: picker,
        matching: find.text('Review backend changes'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: picker,
        matching: find.text('Build the mobile client'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Reorder session'), findsNothing);

    await tester.tap(
      find.descendant(
        of: picker,
        matching: find.text('Review backend changes'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.selectedIndex, 1);
    expect(find.text('Swipe sessions  ·  2 of 2'), findsOneWidget);
  });

  testWidgets('session list stays above the system navigation inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 80);
    addTearDown(tester.view.resetPadding);
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    final list = find.descendant(
      of: find.byType(SessionPickerSheet),
      matching: find.byType(ListView),
    );
    expect(list, findsOneWidget);
    expect(
      tester.getBottomRight(list).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height - 80),
    );
  });

  testWidgets('session search results stay above the software keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('session-search-field'));
    await tester.tap(search);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    final list = find.descendant(
      of: find.byType(SessionPickerSheet),
      matching: find.byType(ListView),
    );
    expect(list, findsOneWidget);
    expect(tester.getBottomRight(list).dy, lessThanOrEqualTo(480));
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('composer stays above the software keyboard', (tester) async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);
    addTearDown(() => tester.view.resetViewInsets());

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final composer = find.byType(ComposerBar);
    expect(composer, findsOneWidget);
    final composerContext = tester.element(composer);
    final keyboardTop =
        MediaQuery.sizeOf(composerContext).height -
        MediaQuery.viewInsetsOf(composerContext).bottom;
    expect(tester.getBottomRight(composer).dy, lessThanOrEqualTo(keyboardTop));
  });

  testWidgets(
    'opening and scrolling above the keyboard keeps the transcript bottom visible',
    (tester) async {
      final controller = CodexController(preview: true);
      controller.sessions.first.messages = List.generate(
        30,
        (index) => ChatItem(
          role: index.isEven ? 'user' : 'assistant',
          text:
              'Transcript entry $index with enough text to remain scrollable.',
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(() => tester.view.resetViewInsets());

      await tester.pumpWidget(CodexMobileApp(controller: controller));
      await tester.pumpAndSettle();

      final transcript = find.byType(CustomScrollView).first;
      final position = tester
          .widget<CustomScrollView>(transcript)
          .controller!
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      final composerField = find.descendant(
        of: find.byType(ComposerBar),
        matching: find.byType(TextField),
      );
      await tester.tap(composerField);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();

      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      expect(
        tester.widget<TextField>(composerField).focusNode?.hasFocus,
        isTrue,
      );

      await tester.drag(transcript, const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(composerField).focusNode?.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'sessions retain transcript position and offer a latest shortcut',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = CodexController(preview: true);
      controller.sessions.first.messages = List.generate(
        30,
        (index) => ChatItem(
          role: index.isEven ? 'user' : 'assistant',
          text: 'Scrollable session entry $index with a useful amount of text.',
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(CodexMobileApp(controller: controller));
      await tester.pumpAndSettle();

      final firstTranscript = find.byType(CustomScrollView).first;
      final firstPosition = tester
          .widget<CustomScrollView>(firstTranscript)
          .controller!
          .position;
      firstPosition.jumpTo(firstPosition.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      final savedOffset = firstPosition.pixels;

      expect(find.byTooltip('Scroll to latest'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();

      expect(firstPosition.pixels, closeTo(savedOffset, 1));

      await tester.tap(find.byTooltip('Scroll to latest'));
      await tester.pumpAndSettle();

      expect(firstPosition.pixels, closeTo(firstPosition.maxScrollExtent, 1));
      expect(find.byTooltip('Scroll to latest'), findsNothing);

      tester.view.physicalSize = const Size(800, 450);
      await tester.pumpAndSettle();

      expect(firstPosition.pixels, closeTo(firstPosition.maxScrollExtent, 1));
      expect(find.byTooltip('Scroll to latest'), findsNothing);

      await tester.drag(firstTranscript, const Offset(0, 180));
      await tester.pumpAndSettle();
      final readingOffset = firstPosition.pixels;
      controller.sessions.first.messages.add(
        const ChatItem(
          role: 'assistant',
          text: 'New content while reading older messages.',
        ),
      );
      await controller.selectSession(0);
      await tester.pumpAndSettle();
      expect(firstPosition.pixels, closeTo(readingOffset, 1));
      controller.sessions.first.messages.last = const ChatItem(
        role: 'assistant',
        text: 'New content while reading older messages. More streaming text.',
      );
      await controller.selectSession(0);
      await tester.pumpAndSettle();
      expect(firstPosition.pixels, closeTo(readingOffset, 1));
      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();

      expect(firstPosition.pixels, lessThan(firstPosition.maxScrollExtent));
      expect(find.byTooltip('Scroll to latest'), findsOneWidget);
      await tester.tap(find.byTooltip('Scroll to latest'));
      await tester.pumpAndSettle();
      controller.sessions.first.messages.add(
        const ChatItem(
          role: 'assistant',
          text: 'Continue following new messages.',
        ),
      );
      await controller.selectSession(0);
      await tester.pumpAndSettle();
      expect(firstPosition.pixels, closeTo(firstPosition.maxScrollExtent, 1));
    },
  );

  testWidgets('paused transcript position survives rotation and new content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);
    final session = controller.sessions.first;
    session.messages = List.generate(
      50,
      (index) => ChatItem(
        role: 'assistant',
        text: 'Transcript message $index to keep while rotating.',
      ),
    );
    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();
    ScrollPosition position() => tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .controller!
        .position;
    position().jumpTo(1000);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    final saved = position().pixels;
    expect(saved, greaterThan(0));
    expect(session.transcriptUserScrolledAway, isTrue);

    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    expect(position().pixels, closeTo(saved, 1));
    session.messages.add(
      const ChatItem(role: 'assistant', text: 'New streaming reply'),
    );
    await controller.selectSession(0);
    await tester.pumpAndSettle();
    expect(position().pixels, closeTo(saved, 1));

    tester.view.physicalSize = const Size(600, 1000);
    await tester.pumpAndSettle();
    expect(position().pixels, closeTo(saved, 1));
    expect(session.transcriptFollowLatest, isFalse);
  });

  testWidgets('large landscape displays show two independent conversations', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = CodexController(preview: true);
    final loadedSessions = List<MobileSession>.of(controller.sessions);
    controller.sessions.clear();
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexMobileApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(PersistentActionBar), findsNWidgets(2));
    expect(find.byType(ComposerBar), findsNWidgets(2));
    expect(find.byType(PageView), findsNothing);

    controller.sessions.addAll(loadedSessions);
    await controller.selectSession(0);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNWidgets(2));

    final pageViews = tester
        .widgetList<PageView>(find.byType(PageView))
        .toList();
    final primaryPages = pageViews[0].controller!;
    final secondaryPages = pageViews[1].controller!;
    expect(primaryPages.page, closeTo(0, .01));
    expect(secondaryPages.page, closeTo(1, .01));

    await tester.fling(find.byType(PageView).at(1), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();

    expect(primaryPages.page, closeTo(0, .01));
    expect(secondaryPages.page, closeTo(0, .01));

    tester.view.physicalSize = const Size(800, 1200);
    await tester.pumpAndSettle();

    expect(find.byType(PersistentActionBar), findsOneWidget);
    expect(find.byType(ComposerBar), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
