import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/widgets/error_boundary.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/utils/system_ui_style.dart';
import 'core/providers/app_startup_providers.dart';
import 'features/agent/permissions/permission_providers.dart';
import 'features/agent/permissions/permission_dialog_handler.dart';

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

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // pdfrx warmup (for PDF viewing in chat)
      unawaited(
        pdfrxFlutterInitialize().catchError((Object error, StackTrace stackTrace) {
          debugPrint('pdfrx init error: $error');
        }),
      );

      // Global error handlers
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('Flutter error: ${details.exception}');
        final stack = details.stack;
        if (stack != null) {
          debugPrintStack(stackTrace: stack);
        }
      };
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        debugPrint('Platform error: $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

      final providerContainer = ProviderContainer(
        overrides: [],
      );

      runApp(
        UncontrolledProviderScope(
          container: providerContainer,
          child: const NerdinApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Zone error: $error');
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

    return ErrorBoundary(
      child: AdaptiveApp.router(
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
      ),
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
