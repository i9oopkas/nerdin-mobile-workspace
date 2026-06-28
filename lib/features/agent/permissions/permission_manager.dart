import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:nerdin_mobile_workspace/features/agent/permissions/permission_rules.dart';
import 'package:nerdin_mobile_workspace/features/agent/permissions/wildcard.dart';

/// Core permission manager implementing the Opencode-inspired permission model.
///
/// Flow:
/// 1. `assert()` is called with an action and resources
/// 2. `evaluate()` applies last-match-wins across [defaultRules] < [driftRules] < [sessionRules]
/// 3. If allow → returns quietly
/// 4. If deny → throws [PermissionDeniedException]
/// 5. If ask → creates a [PermissionRequest], stores it, and returns a Future
///    that resolves when the user replies via `reply()`
///
/// Design decisions:
/// - Session ID is used to scope pending requests and cascade/idempotent-reject
/// - [sessionRules] are in-memory only (lost on app restart)
/// - [driftRules] are persisted rules loaded from Drift on startup
/// - Default rules are hardcoded in [DefaultRules]
/// - Last-match-wins: later rules override earlier ones
class PermissionManager {
  final List<PermissionRule> _defaultRules;
  final List<PermissionRule> _sessionRules = [];
  List<PermissionRule> _driftRules = [];
  final Map<String, PermissionRequest> _pending = {};
  int _requestCounter = 0;

  /// Callback invoked when a new permission request is created (ask → pending).
  /// UI providers listen to this to show dialogs.
  void Function(PermissionRequest request)? onPendingRequest;

  /// Callback invoked when a pending request is resolved (removed from pending).
  void Function(String requestId)? onRequestResolved;

  PermissionManager({List<PermissionRule>? defaultRules})
      : _defaultRules = defaultRules ?? DefaultRules.all;

  /// Update the persisted rules from Drift.
  /// Called on startup and after saving a new rule.
  void updateDriftRules(List<PermissionRule> rules) {
    _driftRules = List.unmodifiable(rules);
  }

  /// All pending requests currently waiting for user input.
  UnmodifiableMapView<String, PermissionRequest> get pendingRequests =>
      UnmodifiableMapView(_pending);

  /// Evaluate a single (action, resource) against all rules.
  ///
  /// Returns the matching [PermissionRule] or `null` if no rule matches
  /// (which is treated as "ask" by default).
  @visibleForTesting
  PermissionRule? evaluate(String action, String resource) {
    // Last-match-wins: concatenate rules with later = higher priority
    // Order: defaultRules < driftRules < sessionRules
    final allRules = [
      ..._defaultRules,
      ..._driftRules,
      ..._sessionRules,
    ];

    // Iterate in reverse to find last match
    for (final rule in allRules.reversed) {
      if (Wildcard.match(action, rule.action) &&
          Wildcard.match(resource, rule.resource)) {
        return rule;
      }
    }

    return null; // No rule matches → treat as ask
  }

  /// Assert that [action] on [resources] is permitted.
  ///
  /// Returns a Future that:
  /// - completes normally if allowed
  /// - throws [PermissionDeniedException] if denied
  /// - throws [PermissionEditedException] if user chose to edit
  /// - throws [TimeoutException] if user takes too long
  Future<void> assert_({
    required String action,
    required List<String> resources,
    String sessionId = 'default',
    List<String>? savePatterns,
    Map<String, dynamic>? metadata,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    for (final resource in resources) {
      final rule = evaluate(action, resource);

      if (rule == null || rule.effect == PermissionEffect.ask) {
        // Need to ask the user
        await _ask(
          action: action,
          resources: [resource],
          sessionId: sessionId,
          savePatterns: savePatterns,
          metadata: metadata,
          timeout: timeout,
        );
      } else if (rule.effect == PermissionEffect.deny) {
        throw PermissionDeniedException(action, resource, rule);
      }
      // allow → continue to next resource
    }
  }

  /// Handle a user reply to a pending permission request.
  ///
  /// Returns `true` if the request was found and processed, `false` if not found.
  bool reply(
    String requestId,
    PermissionReply reply, {
    String? editedInput,
  }) {
    final request = _pending[requestId];
    if (request == null) return false;

    switch (reply) {
      case PermissionReply.once:
        request.completer.complete();
        _resolveRequest(requestId);

      case PermissionReply.alwaysSession:
        // Add rule for each resource
        for (final resource in request.resources) {
          _sessionRules.add(PermissionRule(
            action: request.action,
            resource: resource,
            effect: PermissionEffect.allow,
          ));
        }
        request.completer.complete();
        _resolveRequest(requestId);
        // Cascade: check other pending requests
        _cascade(request.sessionId);

      case PermissionReply.always:
        // The caller (provider) should persist to Drift via the DAO.
        // We store the save patterns for the provider to pick up.
        request.metadata?['_pending_save'] = true;
        request.completer.complete();
        _resolveRequest(requestId);
        // Cascade is handled after Drift save (provider calls updateDriftRules first)

      case PermissionReply.reject:
        // Idempotent reject: reject ALL pending for this session
        _rejectAllPending(request.sessionId);

      case PermissionReply.edit:
        // User wants to edit the input. Reject original and signal edit.
        request.completer.completeError(
          PermissionEditedException(editedInput ?? ''),
        );
        _resolveRequest(requestId);
    }

    return true;
  }

  /// Check if a resource pattern would be covered by the given rules.
  /// Used by cascade to determine if pending requests can be auto-approved.
  bool _isCovered(String action, String resource, List<PermissionRule> rules) {
    for (final rule in rules.reversed) {
      if (Wildcard.match(action, rule.action) &&
          Wildcard.match(resource, rule.resource)) {
        return rule.effect == PermissionEffect.allow;
      }
    }
    return false;
  }

  /// Cascade: after adding new allow rules, check all pending requests
  /// and auto-approve any that are now covered.
  void _cascade(String sessionId) {
    final allCurrentRules = [
      ..._defaultRules,
      ..._driftRules,
      ..._sessionRules,
    ];

    final toResolve = <String>[];
    for (final entry in _pending.entries) {
      final request = entry.value;
      if (request.sessionId != sessionId) continue;

      final allCovered = request.resources.every(
        (r) => _isCovered(request.action, r, allCurrentRules),
      );

      if (allCovered) {
        request.completer.complete();
        toResolve.add(entry.key);
      }
    }

    for (final id in toResolve) {
      _resolveRequest(id);
    }
  }

  /// Reject all pending requests for the given session.
  void _rejectAllPending(String sessionId) {
    final toRemove = <String>[];
    for (final entry in _pending.entries) {
      if (entry.value.sessionId == sessionId) {
        entry.value.completer.completeError(
          PermissionDeniedException(
            entry.value.action,
            entry.value.resources.join(', '),
            PermissionRule(
              action: entry.value.action,
              resource: entry.value.resources.join(', '),
              effect: PermissionEffect.deny,
            ),
          ),
        );
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _resolveRequest(id);
    }
  }

  /// Create a pending request and wait for user reply.
  Future<void> _ask({
    required String action,
    required List<String> resources,
    required String sessionId,
    List<String>? savePatterns,
    Map<String, dynamic>? metadata,
    required Duration timeout,
  }) async {
    _requestCounter++;
    final id = 'perm_$_requestCounter';

    final request = PermissionRequest(
      id: id,
      sessionId: sessionId,
      action: action,
      resources: resources,
      savePatterns: savePatterns,
      metadata: metadata,
    );

    _pending[id] = request;
    onPendingRequest?.call(request);

    try {
      await request.completer.future.timeout(timeout);
    } on TimeoutException {
      // On timeout, auto-reject
      _rejectAllPending(sessionId);
      rethrow;
    }
  }

  /// Remove a request from pending and notify listeners.
  void _resolveRequest(String id) {
    _pending.remove(id);
    onRequestResolved?.call(id);
  }

  /// Get the save patterns from a "always" reply for Drift persistence.
  /// Returns null if the request wasn't an "always" reply.
  List<String>? consumeSavePatterns(String requestId) {
    final request = _pending[requestId];
    if (request == null) return null;
    if (request.metadata?['_pending_save'] != true) return null;
    request.metadata?['_pending_save'] = false;
    return request.savePatterns ?? request.resources;
  }

  /// Clear all session rules (e.g., on app restart or explicit reset).
  void clearSessionRules() {
    _sessionRules.clear();
  }
}
