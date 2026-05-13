import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'logic/game_provider.dart';
import 'screens/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final gp = GameProvider();
  // SharedPreferences yükleme yolunu ısıt (ana menü butonları için).
  await GameProvider.hasSavedGame();

  runApp(
    ChangeNotifierProvider.value(
      value: gp,
      child: const PresidentoApp(),
    ),
  );
}

class PresidentoApp extends StatelessWidget {
  const PresidentoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kulüp Başkanı Tycoon',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const MainMenuScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    const navyDark = Color(0xFF0A1628);
    const navy = Color(0xFF1A2744);
    const anthracite = Color(0xFF1E2530);
    const anthraciteLight = Color(0xFF2C3546);
    const cyan = Color(0xFF38BDF8);
    const onDark = Color(0xFFE8EDF5);
    const onDarkMuted = Color(0xFF8A9BB8);

    final colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: cyan,
      onPrimary: navyDark,
      primaryContainer: const Color(0xFF0C4A6E),
      onPrimaryContainer: const Color(0xFFE0F2FE),
      secondary: const Color(0xFF94A3B8),
      onSecondary: navyDark,
      secondaryContainer: const Color(0xFF334155),
      onSecondaryContainer: onDark,
      tertiary: const Color(0xFF67E8F9),
      onTertiary: navyDark,
      error: const Color(0xFFFF5252),
      onError: navyDark,
      surface: navy,
      onSurface: onDark,
      surfaceContainerHighest: anthraciteLight,
      outline: onDarkMuted,
    );

    final textTheme = GoogleFonts.rajdhaniTextTheme().apply(
      bodyColor: onDark,
      displayColor: onDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: navyDark,
      cardColor: anthracite,
      dividerColor: onDarkMuted.withValues(alpha: 0.2),
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: onDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onDark,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: cyan),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyan,
          foregroundColor: navyDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          elevation: 2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onDark,
          side: BorderSide(color: onDarkMuted.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: anthracite,
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: anthraciteLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cyan, width: 2),
        ),
        labelStyle: const TextStyle(color: onDarkMuted),
        hintStyle: const TextStyle(color: onDarkMuted),
        prefixIconColor: onDarkMuted,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: cyan,
        linearTrackColor: anthraciteLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: anthraciteLight,
        contentTextStyle: GoogleFonts.rajdhani(color: onDark, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: anthracite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.rajdhani(
          color: onDark,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.rajdhani(
          color: onDarkMuted,
          fontSize: 16,
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF38BDF8),
        brightness: Brightness.light,
      ),
    );
  }
}
