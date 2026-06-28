import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/agent_providers.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_definitions.dart';
import 'package:nerdin_mobile_workspace/features/agent/engine/tool_registry.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_bootstrap.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_command_service.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_file_service.dart';
import 'package:nerdin_mobile_workspace/features/agent/termux/termux_providers.dart';

/// Integrates Termux backends into the agent engine after daemon bootstrap.
///
/// Call this after [TermuxBootstrap.bootstrap] succeeds.
/// Re-registers builtin tools with Termux backends wired in, so tools
/// like `read_file`, `write_file`, and `run_command` can execute on the
/// termux target.
void registerTermuxTools(Ref ref) {
  final registry = ref.read(toolRegistryProvider);
  final commandService = ref.read(termuxCommandServiceProvider);
  final fileService = ref.read(termuxFileServiceProvider);

  final backends = ToolBackends(
    termuxCommand: commandService,
    termuxFile: fileService,
  );

  // Re-register builtin tools with backends (overrides local-only handlers)
  registry.registerAll(createBuiltinTools(backends: backends));
}
