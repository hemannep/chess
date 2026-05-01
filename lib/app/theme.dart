import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B7B4B),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF4B7B4B),
          secondary: const Color(0xFFB58863),
          surface: const Color(0xFFFAF8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2EFE8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF8F4),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFAF8F4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x1A000000), width: 0.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4B7B4B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        extensions: const [ChessThemeExtension.light()],
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B7B4B),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF6EA86E),
          secondary: const Color(0xFFD4A574),
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE8E4D8),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
          ),
        ),
        extensions: const [ChessThemeExtension.dark()],
      );
}

@immutable
class ChessThemeExtension extends ThemeExtension<ChessThemeExtension> {
  final Color lightSquare;
  final Color darkSquare;
  final Color lastMoveHighlight;
  final Color selectedHighlight;
  final Color legalMoveColor;
  final Color checkColor;
  final Color clockActive;
  final Color clockWarning;
  final Color clockCritical;

  const ChessThemeExtension({
    required this.lightSquare,
    required this.darkSquare,
    required this.lastMoveHighlight,
    required this.selectedHighlight,
    required this.legalMoveColor,
    required this.checkColor,
    required this.clockActive,
    required this.clockWarning,
    required this.clockCritical,
  });

  const ChessThemeExtension.light()
      : lightSquare = const Color(0xFFF0D9B5),
        darkSquare = const Color(0xFFB58863),
        lastMoveHighlight = const Color(0x99CDD16E),
        selectedHighlight = const Color(0xAAF6F669),
        legalMoveColor = const Color(0x4D000000),
        checkColor = const Color(0xCCFF4444),
        clockActive = const Color(0xFF2E7D32),
        clockWarning = const Color(0xFFE65100),
        clockCritical = const Color(0xFFB71C1C);

  const ChessThemeExtension.dark()
      : lightSquare = const Color(0xFFCCB88A),
        darkSquare = const Color(0xFF8B6343),
        lastMoveHighlight = const Color(0x88AABB44),
        selectedHighlight = const Color(0xAAE8E840),
        legalMoveColor = const Color(0x55FFFFFF),
        checkColor = const Color(0xCCFF6666),
        clockActive = const Color(0xFF66BB6A),
        clockWarning = const Color(0xFFFF9800),
        clockCritical = const Color(0xFFF44336);

  @override
  ChessThemeExtension copyWith({Color? lightSquare, Color? darkSquare}) =>
      ChessThemeExtension(
        lightSquare: lightSquare ?? this.lightSquare,
        darkSquare: darkSquare ?? this.darkSquare,
        lastMoveHighlight: lastMoveHighlight,
        selectedHighlight: selectedHighlight,
        legalMoveColor: legalMoveColor,
        checkColor: checkColor,
        clockActive: clockActive,
        clockWarning: clockWarning,
        clockCritical: clockCritical,
      );

  @override
  ChessThemeExtension lerp(
      ThemeExtension<ChessThemeExtension>? other, double t) {
    if (other is! ChessThemeExtension) return this;
    return ChessThemeExtension(
      lightSquare: Color.lerp(lightSquare, other.lightSquare, t)!,
      darkSquare: Color.lerp(darkSquare, other.darkSquare, t)!,
      lastMoveHighlight:
          Color.lerp(lastMoveHighlight, other.lastMoveHighlight, t)!,
      selectedHighlight:
          Color.lerp(selectedHighlight, other.selectedHighlight, t)!,
      legalMoveColor: Color.lerp(legalMoveColor, other.legalMoveColor, t)!,
      checkColor: Color.lerp(checkColor, other.checkColor, t)!,
      clockActive: Color.lerp(clockActive, other.clockActive, t)!,
      clockWarning: Color.lerp(clockWarning, other.clockWarning, t)!,
      clockCritical: Color.lerp(clockCritical, other.clockCritical, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  ChessThemeExtension get chessTheme =>
      Theme.of(this).extension<ChessThemeExtension>()!;
}
