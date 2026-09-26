import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/codex_controller.dart';

void main() {
  test(
    'health check repairs missed idle event through runtime snapshot',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscribed = Completer<void>();
      final recovered = Completer<void>();
      var subscriptions = 0;
      server.listen((request) async {
        if (request.uri.path == '/api/ws') {
          final socket = await WebSocketTransformer.upgrade(request);
          addTearDown(() => socket.close());
          socket.listen((payload) {
            if (jsonDecode(payload as String)['type'] != 'subscribe') return;
            subscriptions++;
            if (!subscribed.isCompleted) {
              subscribed.complete();
            } else {
              socket.add(
                jsonEncode({
                  'type': 'runtime/snapshot',
                  'threadId': 'thread-1',
                  'working': false,
                  'approvals': [],
                }),
              );
            }
          });
          return;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path == '/api/health'
                ? {'codex': 'ready', 'workspace': '/workspace'}
                : {
                    'threads': [
                      {'id': 'thread-1', 'cwd': '/workspace'},
                    ],
                  },
          ),
        );
        await request.response.close();
      });
      final controller = CodexController(
        initialServerUrl: 'http://127.0.0.1:${server.port}',
      );
      addTearDown(controller.dispose);
      await controller.appResumed();
      await subscribed.future.timeout(const Duration(seconds: 5));
      final session = controller.sessions.first;
      session.working = true;
      session.active = true;
      session.activity = 'Working';
      controller.addListener(() {
        if (!session.working && !recovered.isCompleted) recovered.complete();
      });
      await controller.refreshHealth(silent: true);
      await recovered.future.timeout(const Duration(seconds: 5));
      expect(subscriptions, greaterThanOrEqualTo(2));
      expect(session.active, isFalse);
      expect(session.activity, isEmpty);
    },
  );

  test('handles local slash commands without starting model turns', () async {
    final controller = CodexController(preview: true);
    addTearDown(controller.dispose);
    final session = controller.sessions.first;
    final originalCount = session.messages.length;

    await controller.sendMessage(session, '/status');

    expect(session.messages, hasLength(originalCount + 2));
    expect(session.messages[originalCount].text, '/status');
    expect(session.messages.last.kind, 'notice');
    expect(
      session.messages.last.text,
      contains('Workspace: /workspace/androidex'),
    );

    await controller.sendMessage(session, '/rename Slash-ready session');
    expect(session.title, 'Slash-ready session');
    expect(session.working, isFalse);
  });

  test('foreground resume refreshes the complete session list', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var threadRequests = 0;
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/health') {
        request.response.write(
          jsonEncode({
            'codex': 'ready',
            'workspace': '/workspace',
            'auth': {
              'type': 'auth/snapshot',
              'status': 'authenticated',
              'requiresOpenaiAuth': true,
            },
          }),
        );
      } else if (request.uri.path == '/api/threads') {
        threadRequests += 1;
        request.response.write(
          jsonEncode({
            'workspace': '/workspace',
            'threads': [
              {
                'id': 'thread-1',
                'title': 'Fresh session',
                'cwd': '/workspace',
                'updatedAt': 2,
              },
              {
                'id': 'thread-2',
                'title': 'Another session',
                'cwd': '/other-workspace',
                'updatedAt': 1,
              },
            ],
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final controller = CodexController(
      initialServerUrl: 'http://127.0.0.1:${server.port}',
    )..socketConnected = true;
    addTearDown(controller.dispose);

    await controller.appResumed();

    expect(threadRequests, 1);
    expect(controller.connection, BridgeConnection.ready);
    expect(controller.sessions.map((session) => session.threadId), [
      'thread-1',
      'thread-2',
    ]);
  });
}
