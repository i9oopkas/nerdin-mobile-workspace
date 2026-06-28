import 'package:flutter/widgets.dart';

class AppLocalizations {
  static final AppLocalizations _instance = AppLocalizations._();
  AppLocalizations._();

  static AppLocalizations of(BuildContext context) => _instance;
  static AppLocalizations? maybeOf(BuildContext context) => _instance;
  static const List<Locale> supportedLocales = [Locale('en')];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      return _toEnglish(invocation.memberName);
    }
    if (invocation.isMethod) {
      final name = _toEnglish(invocation.memberName);
      final positional = invocation.positionalArguments;
      if (positional.isEmpty) return name;
      return positional.fold<String>(name, (prev, arg) => '$prev $arg');
    }
    return super.noSuchMethod(invocation);
  }

  static String _toEnglish(Symbol symbol) {
    final raw = symbol.toString();
    final name = raw.startsWith('Symbol("')
        ? raw.substring(8, raw.length - 2)
        : raw;
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => ' ${m.group(0)!.toLowerCase()}',
        )
        .trim();
  }
}

AppLocalizations currentAppLocalizations() => AppLocalizations._instance;
