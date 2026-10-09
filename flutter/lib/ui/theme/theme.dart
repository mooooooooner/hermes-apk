import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/prefs/settings_repository.dart';
import 'colors.dart';
import 'typography.dart';

const _lightColors = ColorScheme(
  brightness: Brightness.light,
  primary: lightPrimary,
  onPrimary: lightOnPrimary,
  primaryContainer: lightPrimaryContainer,
  onPrimaryContainer: lightOnPrimaryContainer,
  secondary: lightSecondary,
  onSecondary: lightOnSecondary,
  secondaryContainer: lightSecondaryContainer,
  onSecondaryContainer: lightOnSecondaryContainer,
  tertiary: lightTertiary,
  onTertiary: lightOnTertiary,
  tertiaryContainer: lightTertiaryContainer,
  onTertiaryContainer: lightOnTertiaryContainer,
  error: lightError,
  onError: lightOnError,
  errorContainer: lightErrorContainer,
  onErrorContainer: lightOnErrorContainer,
  surface: lightSurface,
  onSurface: lightOnSurface,
  onSurfaceVariant: lightOnSurfaceVariant,
  outline: lightOutline,
  outlineVariant: lightOutlineVariant,
  inverseSurface: lightInverseSurface,
  onInverseSurface: lightInverseOnSurface,
  inversePrimary: lightInversePrimary,
  surfaceDim: lightSurfaceDim,
  surfaceBright: lightSurfaceBright,
  surfaceContainerLowest: lightSurfaceContainerLowest,
  surfaceContainerLow: lightSurfaceContainerLow,
  surfaceContainer: lightSurfaceContainer,
  surfaceContainerHigh: lightSurfaceContainerHigh,
  surfaceContainerHighest: lightSurfaceContainerHighest,
);

const _darkColors = ColorScheme(
  brightness: Brightness.dark,
  primary: darkPrimary,
  onPrimary: darkOnPrimary,
  primaryContainer: darkPrimaryContainer,
  onPrimaryContainer: darkOnPrimaryContainer,
  secondary: darkSecondary,
  onSecondary: darkOnSecondary,
  secondaryContainer: darkSecondaryContainer,
  onSecondaryContainer: darkOnSecondaryContainer,
  tertiary: darkTertiary,
  onTertiary: darkOnTertiary,
  tertiaryContainer: darkTertiaryContainer,
  onTertiaryContainer: darkOnTertiaryContainer,
  error: darkError,
  onError: darkOnError,
  errorContainer: darkErrorContainer,
  onErrorContainer: darkOnErrorContainer,
  surface: darkSurface,
  onSurface: darkOnSurface,
  onSurfaceVariant: darkOnSurfaceVariant,
  outline: darkOutline,
  outlineVariant: darkOutlineVariant,
  inverseSurface: darkInverseSurface,
  onInverseSurface: darkInverseOnSurface,
  inversePrimary: darkInversePrimary,
  surfaceDim: darkSurfaceDim,
  surfaceBright: darkSurfaceBright,
  surfaceContainerLowest: darkSurfaceContainerLowest,
  surfaceContainerLow: darkSurfaceContainerLow,
  surfaceContainer: darkSurfaceContainer,
  surfaceContainerHigh: darkSurfaceContainerHigh,
  surfaceContainerHighest: darkSurfaceContainerHighest,
);

class HermesTheme extends StatelessWidget {
  final AppThemeMode themeMode;
  final bool dynamicColor;
  final Widget child;

  const HermesTheme({
    super.key,
    required this.themeMode,
    required this.dynamicColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final darkTheme = switch (themeMode) {
      AppThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
    };
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final scheme = dynamicColor && lightDynamic != null
            ? (darkTheme ? darkDynamic!.harmonized() : lightDynamic.harmonized())
            : (darkTheme ? _darkColors : _lightColors);
        final systemDark = View.of(context).platformDispatcher.platformBrightness ==
            Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: systemDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: systemDark ? Brightness.dark : Brightness.light,
          ),
          child: Theme(
            data: _materialTheme(scheme),
            child: child,
          ),
        );
      },
    );
  }
}

ThemeData _materialTheme(ColorScheme scheme) {
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: HermesTypography.headlineMedium,
      titleLarge: HermesTypography.titleLarge,
      titleMedium: HermesTypography.titleMedium,
      titleSmall: HermesTypography.titleSmall,
      bodyLarge: HermesTypography.bodyLarge,
      bodyMedium: HermesTypography.bodyMedium,
      bodySmall: HermesTypography.bodySmall,
      labelLarge: HermesTypography.labelLarge,
      labelMedium: HermesTypography.labelMedium,
    ),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: HermesTypography.titleMedium.copyWith(
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        textStyle: HermesTypography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        textStyle: HermesTypography.labelLarge,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      backgroundColor: scheme.surfaceContainerLow,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: scheme.surfaceContainerHigh,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
