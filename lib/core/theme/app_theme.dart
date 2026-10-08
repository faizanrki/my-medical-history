
import 'package:flutter/material.dart';
import 'app_colors.dart';

// ==============================================
// MY MEDICAL HISTORY
// PROFESSIONAL APPLICATION THEME
// ==============================================

class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    // ==========================================
    // BASIC THEME SETTINGS
    // ==========================================

    useMaterial3: true,

    brightness: Brightness.light,

    // Professional, clean medical-app font.
    fontFamily: 'Roboto',

    scaffoldBackgroundColor: AppColors.background,

    // ==========================================
    // COLOR SCHEME
    // ==========================================

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,

      secondary: AppColors.success,
      onSecondary: Colors.white,

      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,

      outline: AppColors.border,
      outlineVariant: AppColors.border,

      error: AppColors.error,
      onError: Colors.white,
    ),

    // ==========================================
    // TEXT STYLES
    // ==========================================

    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
      ),

      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.6,
      ),

      headlineMedium: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      ),

      headlineSmall: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),

      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),

      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      ),

      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      ),

      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),

      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),

      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),

    // ==========================================
    // APP BAR
    // ==========================================

    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,

      surfaceTintColor: Colors.transparent,

      elevation: 0,
      scrolledUnderElevation: 0,

      centerTitle: false,

      toolbarHeight: 64,

      titleSpacing: 20,

      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: 23,
      ),

      actionsIconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: 23,
      ),

      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    ),

    // ==========================================
    // CARDS
    // ==========================================

    cardTheme: CardThemeData(
      color: AppColors.surface,

      surfaceTintColor: Colors.transparent,

      elevation: 0,

      margin: EdgeInsets.zero,

      clipBehavior: Clip.antiAlias,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),

        side: const BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
    ),

    // ==========================================
    // PRIMARY FILLED BUTTONS
    // ==========================================

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,

        disabledBackgroundColor:
        AppColors.surfaceSoft,

        disabledForegroundColor:
        AppColors.textMuted,

        minimumSize: const Size(0, 52),

        elevation: 0,

        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 14,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ==========================================
    // OUTLINED BUTTONS
    // ==========================================

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,

        backgroundColor: AppColors.surface,

        minimumSize: const Size(0, 50),

        side: const BorderSide(
          color: AppColors.border,
          width: 1.2,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ==========================================
    // ELEVATED BUTTONS
    // ==========================================

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,

        minimumSize: const Size(0, 52),

        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ==========================================
    // TEXT BUTTONS
    // ==========================================

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,

        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ==========================================
    // INPUT FIELDS
    // ==========================================

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,

      fillColor: AppColors.surface,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),

      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),

      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
      ),

      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),

      prefixIconColor: AppColors.textSecondary,

      suffixIconColor: AppColors.textSecondary,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.6,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(
          color: AppColors.error,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.6,
        ),
      ),
    ),

    // ==========================================
    // BOTTOM NAVIGATION BAR
    // ==========================================

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:
      AppColors.navigationBackground,

      surfaceTintColor: Colors.transparent,

      elevation: 0,

      height: 72,

      labelBehavior:
      NavigationDestinationLabelBehavior.alwaysShow,

      indicatorColor: AppColors.primaryLight,

      iconTheme:
      WidgetStateProperty.resolveWith<IconThemeData>(
            (states) {
          final selected =
          states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected
                ? AppColors.navigationSelected
                : AppColors.navigationUnselected,

            size: 23,
          );
        },
      ),

      labelTextStyle:
      WidgetStateProperty.resolveWith<TextStyle>(
            (states) {
          final selected =
          states.contains(WidgetState.selected);

          return TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w500,

            color: selected
                ? AppColors.navigationSelected
                : AppColors.navigationUnselected,
          );
        },
      ),
    ),

    // ==========================================
    // THREE-DOT POPUP MENU STYLE
    // ==========================================

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,

      surfaceTintColor: Colors.transparent,

      elevation: 6,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),

        side: const BorderSide(
          color: AppColors.border,
        ),
      ),

      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),

    // ==========================================
    // LIST TILES
    // ==========================================

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primary,

      textColor: AppColors.textPrimary,

      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),

      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      subtitleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    ),

    // ==========================================
    // DIVIDERS
    // ==========================================

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // ==========================================
    // DIALOGS
    // ==========================================

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,

      surfaceTintColor: Colors.transparent,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),

      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),

      contentTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    ),

    // ==========================================
    // SNACKBARS
    // ==========================================

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,

      backgroundColor: AppColors.textPrimary,

      contentTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        color: Colors.white,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // ==========================================
    // PROGRESS INDICATORS
    // ==========================================

    progressIndicatorTheme:
    const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.primaryLight,
    ),

    // ==========================================
    // FLOATING ACTION BUTTON
    // ==========================================

    floatingActionButtonTheme:
    FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,

      elevation: 3,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}
