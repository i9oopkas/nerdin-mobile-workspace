import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/utils/system_ui_style.dart';
import 'core/providers/app_startup_providers.dart';
import 'core/providers/chat_seed_provider.dart';
import 'features/agent/permissions/permission_providers.dart';
import 'features/agent/permissions/permission_dialog_handler.dart';
import 'shared/widgets/error_screen.dart';
import 'core/utils/provider_observer.dart';

/// Provides a shared [FlutterSecureStorage] instance.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      sharedPreferencesName: 'nerdin_secure_prefs',
      preferencesKeyPrefix: 'nerdin_',
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accountName: 'nerdin_secure_storage',
      synchronizable: false,
    ),
  );
});

// ──────────────────────────────────────────────
//  Crash screen logic — catches errors and shows
//  a report with save/share/restart actions
// ──────────────────────────────────────────────

/// Global reference to the app's ProviderContainer (for restart).
ProviderContainer? _appContainer;

/// Collects ALL errors that occur during a crash sequence.
/// Shows them all on the ErrorScreen at once.
List<FlutterErrorDetails> _pendingErrors = [];

/// Shows the ErrorScreen after the current frame completes.
/// Accumulates errors — each call adds to the list, and the ErrorScreen
/// shows ALL collected errors so the user can see every stack trace.
void _showErrorScreen(FlutterErrorDetails details) {
  _pendingErrors.add(details);

  // If this is the first error, schedule the ErrorScreen
  if (_pendingErrors.length == 1) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Take a snapshot of all errors collected so far
      final errors = List<FlutterErrorDetails>.from(_pendingErrors);
      _pendingErrors.clear();

      // Don't dispose _appContainer here! It becomes unreachable when runApp
      // replaces the old widget tree and will be GC'd.
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ErrorScreen(
            errorDetails: errors.first,           // primary error
            additionalErrors: errors.sublist(1),  // cascading errors
            onRestart: _restartApp,
          ),
        ),
      );
    });
  } else {
    debugPrint('📋 Collected cascading error #${_pendingErrors.length}:');
    debugPrint('   ${details.exception}');
  }
}

/// Restarts the app with a fresh ProviderContainer.
void _restartApp() {
  _pendingErrors.clear();  // Clear collected errors
  _appContainer?.dispose();
  _appContainer = ProviderContainer(overrides: []);
  runApp(
    UncontrolledProviderScope(
      container: _appContainer!,
      child: const NerdinApp(),
    ),
  );
  // Re-seed chat tab after restart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _appContainer?.read(chatTabSeedProvider);
  });
}

void main() {
  // Debug: log every widget rebuild — helps identify the _dirty culprit
  debugPrintRebuildDirtyWidgets = true;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // pdfrx warmup (for PDF viewing in chat)
      unawaited(
        pdfrxFlutterInitialize().catchError((Object error, StackTrace stackTrace) {
          debugPrint('pdfrx init error: $error');
        }),
      );

      // Create the app's ProviderContainer
      _appContainer = ProviderContainer(
        overrides: [],
        observers: [const NerdinProviderObserver()],
      );

      // ── Flutter error handler ──
      // Catches all Flutter errors (assertions, build errors, etc.),
      // prints full details to console, then shows ErrorScreen.
      FlutterError.onError = (FlutterErrorDetails details) {
        // 1. Print standard error message
        FlutterError.presentError(details);

        // 2. Print full details to console
        final errorMsg = details.exception.toString();
        debugPrint('');
        debugPrint('══════════ FLUTTER ERROR ══════════');
        debugPrint('Type:     ${details.exception.runtimeType}');
        debugPrint('Error:    $errorMsg');
        if (details.stack != null) {
          debugPrint('Stack:');
          debugPrint(details.stack.toString());
        } else {
          debugPrint('Stack:    null');
          // Try to extract stack from exception itself
          try {
            throw details.exception;
          }           catch (_, s) {
            debugPrint('Stack:    $s');
          }
        }
        debugPrint('═══════════════════════════════════');
        debugPrint('');

        // 3. Ignore non-fatal layout warnings (overflow, constraints, etc.)
        //    These are just logged, not shown as crash screen.
        if (errorMsg.contains('overflowed') || 
            errorMsg.contains('overflow') ||
            errorMsg.contains('RenderFlex') ||
            errorMsg.contains('A Render') ||
            errorMsg.contains('flex') ||
            errorMsg.contains('does not support')) {
          debugPrint('⚠️ Non-fatal layout warning — not showing crash screen');
          return;
        }

        // 4. Show crash screen after frame completes for FATAL errors only
        _showErrorScreen(details);
      };

      // ── Platform error handler ──
      // Catches low-level platform errors (rare in Flutter).
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        debugPrint('❌ Platform error: $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

      // ── Launch the app ──
      runApp(
        UncontrolledProviderScope(
          container: _appContainer!,
          child: const NerdinApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('❌ Zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class NerdinApp extends ConsumerStatefulWidget {
  const NerdinApp({super.key});

  @override
  ConsumerState<NerdinApp> createState() => _NerdinAppState();
}

class _NerdinAppState extends ConsumerState<NerdinApp> {
  Brightness? _lastAppliedOverlayBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAppState());
  }

  void _initializeAppState() {
    debugPrint('app: init');
    ref.read(appStartupFlowProvider.notifier).start();
    ref.read(permissionInitProvider);
    ref.read(chatTabSeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final router = ref.watch(goRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    final lightTheme = ref.watch(appLightThemeProvider);
    final darkTheme = ref.watch(appDarkThemeProvider);
    final cupertinoLight = ref.watch(appCupertinoLightThemeProvider);
    final cupertinoDark = ref.watch(appCupertinoDarkThemeProvider);

    return AdaptiveApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => 'Nerdin',
      materialLightTheme: lightTheme,
      materialDarkTheme: darkTheme,
      cupertinoLightTheme: cupertinoLight,
      cupertinoDarkTheme: cupertinoDark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en')],
      localeListResolutionCallback: (deviceLocales, supported) {
        if (locale != null) return locale;
        return supported.first;
      },
      material: (_, _) =>
          const MaterialAppData(debugShowCheckedModeBanner: false),
      cupertino: (_, _) =>
          const CupertinoAppData(debugShowCheckedModeBanner: false),
      builder: (context, child) {
        late final Brightness brightness;
        switch (themeMode) {
          case ThemeMode.dark:
            brightness = Brightness.dark;
          case ThemeMode.light:
            brightness = Brightness.light;
          case ThemeMode.system:
            brightness = MediaQuery.platformBrightnessOf(context);
        }
        if (_lastAppliedOverlayBrightness != brightness) {
          _lastAppliedOverlayBrightness = brightness;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            applySystemUiOverlayStyleOnce(brightness: brightness);
          });
        }
        final safeChild = child ?? const SizedBox.shrink();

        final materialTheme = brightness == Brightness.dark
            ? darkTheme
            : lightTheme;

        return Theme(
          data: materialTheme,
          child: PermissionDialogHandler(
            child: _KeyboardDismissOnScroll(child: safeChild),
          ),
        );
      },
    );
  }
}

/// Dismisses the soft keyboard whenever the user scrolls.
class _KeyboardDismissOnScroll extends StatelessWidget {
  const _KeyboardDismissOnScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.idle) return false;
        final focusedNode = FocusManager.instance.primaryFocus;
        if (focusedNode != null && focusedNode.hasFocus) {
          focusedNode.unfocus();
        }
        return false;
      },
      child: child,
    );
  }
}
