class SlashCommandDefinition {
  const SlashCommandDefinition(
    this.command,
    this.description, {
    this.usage = '',
  });

  final String command;
  final String description;
  final String usage;

  String get label => '$command${usage.isEmpty ? '' : ' $usage'}';
}

class SlashCommandInvocation {
  const SlashCommandInvocation(this.name, this.arguments);

  final String name;
  final String arguments;
}

const slashCommands = <SlashCommandDefinition>[
  SlashCommandDefinition('/help', 'Show available commands'),
  SlashCommandDefinition(
    '/new',
    'Start a new conversation',
    usage: '[absolute path]',
  ),
  SlashCommandDefinition('/rename', 'Rename this session', usage: '<name>'),
  SlashCommandDefinition('/compact', 'Compact this session context'),
  SlashCommandDefinition(
    '/review',
    'Review working changes',
    usage: '[instructions]',
  ),
  SlashCommandDefinition('/status', 'Show session and workspace status'),
];

SlashCommandInvocation? parseSlashCommand(String input) {
  final value = input.trim();
  if (!value.startsWith('/') || value.length == 1) return null;
  final separator = value.indexOf(RegExp(r'\s'));
  final token = separator < 0 ? value : value.substring(0, separator);
  if (token.length == 1) return null;
  return SlashCommandInvocation(
    token.substring(1).toLowerCase(),
    separator < 0 ? '' : value.substring(separator).trim(),
  );
}

List<SlashCommandDefinition> matchingSlashCommands(String input) {
  if (!input.startsWith('/') || input.substring(1).contains(RegExp(r'\s'))) {
    return const [];
  }
  final query = input.substring(1).toLowerCase();
  return slashCommands
      .where((command) => command.command.substring(1).startsWith(query))
      .toList(growable: false);
}

String get slashCommandHelp => slashCommands
    .map((command) => '${command.label} — ${command.description}')
    .join('\n');
