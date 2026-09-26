import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/slash_commands.dart';

void main() {
  test('parses command names and arguments', () {
    final command = parseSlashCommand(' /REVIEW focus on auth ');

    expect(command?.name, 'review');
    expect(command?.arguments, 'focus on auth');
    expect(parseSlashCommand('review'), isNull);
    expect(parseSlashCommand('/'), isNull);
  });

  test('filters command suggestions before the argument separator', () {
    expect(matchingSlashCommands('/re').map((command) => command.command), [
      '/rename',
      '/review',
    ]);
    expect(matchingSlashCommands('/review auth'), isEmpty);
  });
}
