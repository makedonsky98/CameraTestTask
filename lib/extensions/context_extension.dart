import 'package:flutter/material.dart';

extension BuildContextExtensions on BuildContext {

  ThemeData get theme => Theme.of(this);
  TextTheme get text => theme.textTheme;
  ColorScheme get colors => theme.colorScheme;
  bool get isDark => theme.brightness == Brightness.dark;

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get width => mediaQuery.size.width;
  double get height => mediaQuery.size.height;
  double get shortest => mediaQuery.size.shortestSide;
  double get defaultPadding => shortest * 0.05;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;

  NavigatorState get navigator => Navigator.of(this);

  bool canPop() => navigator.canPop();

  Future<T?> push<T>(Widget page) {
    return navigator.push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<T?> pushReplacement<T>(Widget page) {
    return navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void pop<T>([T? result]) => navigator.pop(result);

  ScaffoldMessengerState get scaffoldMessenger => ScaffoldMessenger.of(this);

  void showSnackBar(String message, {bool isDismissible = false, bool isCentered = false}) {
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: isCentered ? .center : .start,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: .w400,
          ),
        ),
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.9),
        elevation: 2,
        behavior: .floating,
        dismissDirection: .down,
        shape: RoundedRectangleBorder(
          borderRadius: .circular(16),
        ),
        margin: const .all(16),
        showCloseIcon: isDismissible,
        closeIconColor: colors.onSurface,
      ),
    );
  }

  void showErrorSnackBar(String message, {bool isDismissible = false, bool isCentered = false}) {
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: isCentered ? .center : .start,
          style: TextStyle(
            color: colors.onError,
            fontWeight: .w500,
          ),
        ),
        backgroundColor: colors.error.withValues(alpha: 0.9),
        behavior: .floating,
        dismissDirection: .down,
        shape: RoundedRectangleBorder(
          borderRadius: .circular(16),
        ),
        margin: const .all(16),
        showCloseIcon: isDismissible,
        closeIconColor: colors.onError,
      ),
    );
  }

  void unfocus() {
    FocusScope.of(this).unfocus();
  }
}