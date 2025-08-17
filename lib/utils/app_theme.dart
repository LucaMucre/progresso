import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme management with modern Material 3 design
class AppTheme {
  // Enhanced color palette
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFD97706);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color infoColor = Color(0xFF0EA5E9);
  
  // Gradient colors for visual appeal
  static const List<Color> primaryGradient = [
    Color(0xFF2563EB),
    Color(0xFF3B82F6),
  ];
  
  static const List<Color> successGradient = [
    Color(0xFF059669),
    Color(0xFF10B981),
  ];
  
  // Surface variations for depth
  static const Color glassSurface = Color(0x0AFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  
  /// Create light theme
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );
    
    return _buildTheme(colorScheme);
  }
  
  /// Create dark theme
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    );
    
    return _buildTheme(colorScheme);
  }
  
  /// Build theme with shared configuration
  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      
      // Text theme with Google Fonts
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      
      // Enhanced card theme with modern shadows
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      
      // Enhanced elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 3,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          // Add hover/press effects
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.onPrimary.withValues(alpha: 0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.onPrimary.withValues(alpha: 0.05);
            }
            return null;
          }),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark 
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Navigation rail theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
          ? colorScheme.inverseSurface
          : colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      
      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outline),
      ),
      
      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
      ),
    );
  }
  
  // Utility methods for modern UI effects
  
  /// Create glassmorphism effect
  static BoxDecoration glassContainer({
    required BuildContext context,
    double opacity = 0.1,
    double borderOpacity = 0.2,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: colorScheme.surface.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: colorScheme.outline.withValues(alpha: borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  /// Create modern card shadow
  static List<BoxShadow> modernCardShadow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }
  
  /// Create gradient container
  static BoxDecoration gradientContainer({
    required List<Color> colors,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      boxShadow: boxShadow,
    );
  }
  
  /// Success notification style
  static BoxDecoration successNotification(BuildContext context) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: successGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: successColor.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  /// Error notification style
  static BoxDecoration errorNotification(BuildContext context) {
    return BoxDecoration(
      color: errorColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: errorColor.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}