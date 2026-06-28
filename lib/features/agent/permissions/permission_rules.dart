import 'dart:async';

/// Core types for the Nerdin Mobile permission system.
///
/// Phase 1b — Permission System.
/// Based on Opencode's v2 permission model (anomalyco/opencode).

/// The effect of a permission rule.
enum PermissionEffect {
  /// Allow the operation without asking.
  allow,

  /// Deny the operation silently.
  deny,

  /// Ask the user for confirmation.
  ask,
}

/// User reply to a pending permission request.
enum PermissionReply {
  /// Allow this one time.
  once,

  /// Allow for the remainder of the session (in-memory).
  alwaysSession,

  /// Allow forever (persisted to Drift database).
  always,

  /// Reject this request and all pending requests for this session.
  reject,

  /// Edit the command/input and re-submit (currently only for run_command).
  edit,
}

/// A single permission rule.
///
/// Maps an (action, resource) pair to a [PermissionEffect].
/// Resource patterns use wildcard matching (* and ?).
class PermissionRule {
  /// The permission key / operation type.
  /// Examples: "run_command", "read", "edit", "delete_file", "network", etc.
  final String action;

  /// The resource pattern to match.
  /// Examples: "git *", "lib/**/*.dart", "*.env", "*"
  final String resource;

  /// The effect when this rule matches.
  final PermissionEffect effect;

  /// Optional agent ID for future multi-agent support (Phase 2-3).
  /// When null, the rule is global.
  final String? agentId;

  const PermissionRule({
    required this.action,
    required this.resource,
    required this.effect,
    this.agentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionRule &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          resource == other.resource &&
          effect == other.effect &&
          agentId == other.agentId;

  @override
  int get hashCode => Object.hash(action, resource, effect, agentId);

  @override
  String toString() =>
      'PermissionRule(action: $action, resource: $resource, effect: $effect${agentId != null ? ', agentId: $agentId' : ''})';
}

/// A pending permission request waiting for user input.
class PermissionRequest {
  /// Unique request ID.
  final String id;

  /// Session ID this request belongs to.
  final String sessionId;

  /// The action being requested.
  final String action;

  /// The specific resources (paths, commands, URLs) being accessed.
  final List<String> resources;

  /// Patterns to save if user chooses "always".
  final List<String>? savePatterns;

  /// Optional metadata (e.g., full command text, file path).
  final Map<String, dynamic>? metadata;

  /// When the request was created.
  final DateTime createdAt;

  /// Completer that resolves when the user responds.
  /// Completes with null on allow, errors on reject.
  final Completer<void> completer;

  PermissionRequest({
    required this.id,
    required this.sessionId,
    required this.action,
    required this.resources,
    this.savePatterns,
    this.metadata,
    DateTime? createdAt,
    Completer<void>? completer,
  })  : createdAt = createdAt ?? DateTime.now(),
        completer = completer ?? Completer<void>();
}

/// An exception thrown when a permission is denied.
class PermissionDeniedException implements Exception {
  final String action;
  final String resource;
  final PermissionRule rule;

  const PermissionDeniedException(this.action, this.resource, this.rule);

  @override
  String toString() =>
      'Permission denied: $action on $resource (rule: ${rule.effect})';
}

/// An exception thrown when the user chooses to edit the input.
/// The original request is rejected and a new one should be made
/// with the edited content.
class PermissionEditedException implements Exception {
  final String editedInput;

  const PermissionEditedException(this.editedInput);

  @override
  String toString() => 'Permission edited: user modified the input';
}

/// Default permission rules for MVP.
class DefaultRules {
  DefaultRules._();

  /// All default rules in order of specificity (last-match-wins).
  /// More specific rules should come before catch-all rules.
  static List<PermissionRule> get all => [
        // ── run_command: safe commands inside project ──
        PermissionRule(
          action: 'run_command',
          resource: 'git *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'ls *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'cat *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'dart *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'flutter *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'cd *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'pwd',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'echo *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'mkdir *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'touch *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'head *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'tail *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'wc *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'sort *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'find *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'grep *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'diff *',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'which *',
          effect: PermissionEffect.allow,
        ),
        // ── run_command: always deny ──
        PermissionRule(
          action: 'run_command',
          resource: 'sudo *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'chown *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'su *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'passwd *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'rm -rf /*',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'dd *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'mkfs *',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'run_command',
          resource: '> /dev/*',
          effect: PermissionEffect.deny,
        ),
        // ── run_command: ask (moderately dangerous) ──
        PermissionRule(
          action: 'run_command',
          resource: 'rm *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'mv *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'cp *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'chmod *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'curl *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'wget *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'npm install *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'npm run *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'pip *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'pip3 *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'cargo *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'go install *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'gem install *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'kill *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'systemctl *',
          effect: PermissionEffect.ask,
        ),
        PermissionRule(
          action: 'run_command',
          resource: 'service *',
          effect: PermissionEffect.ask,
        ),
        // ── run_command: catch-all ──
        PermissionRule(
          action: 'run_command',
          resource: '*',
          effect: PermissionEffect.ask,
        ),

        // ── read: sensitive files ──
        PermissionRule(
          action: 'read',
          resource: '*.env',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'read',
          resource: '.env*',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'read',
          resource: '*id_rsa*',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'read',
          resource: '*id_ed25519*',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'read',
          resource: '*/.ssh/*',
          effect: PermissionEffect.deny,
        ),
        PermissionRule(
          action: 'read',
          resource: '*.pem',
          effect: PermissionEffect.deny,
        ),
        // ── read: catch-all ──
        PermissionRule(
          action: 'read',
          resource: '*',
          effect: PermissionEffect.allow,
        ),

        // ── edit ──
        PermissionRule(
          action: 'edit',
          resource: '*',
          effect: PermissionEffect.ask,
        ),

        // ── delete_file: always ask ──
        PermissionRule(
          action: 'delete_file',
          resource: '*',
          effect: PermissionEffect.ask,
        ),

        // ── external_directory: always ask ──
        PermissionRule(
          action: 'external_directory',
          resource: '*',
          effect: PermissionEffect.ask,
        ),

        // ── network: API endpoints are allowed ──
        PermissionRule(
          action: 'network',
          resource: 'api.openai.com/*',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'network',
          resource: 'openrouter.ai/*',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'network',
          resource: 'localhost:*',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'network',
          resource: '127.0.0.1:*',
          effect: PermissionEffect.allow,
        ),
        // ── network: catch-all ──
        PermissionRule(
          action: 'network',
          resource: '*',
          effect: PermissionEffect.ask,
        ),

        // ── glob / grep: always allow ──
        PermissionRule(
          action: 'glob',
          resource: '*',
          effect: PermissionEffect.allow,
        ),
        PermissionRule(
          action: 'grep',
          resource: '*',
          effect: PermissionEffect.allow,
        ),

        // ── doom_loop: repetitive tool calls ──
        PermissionRule(
          action: 'doom_loop',
          resource: '*',
          effect: PermissionEffect.ask,
        ),
      ];
}
