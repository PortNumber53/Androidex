import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/codex_controller.dart';

void main() {
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
