import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema global do app — Etapa 0 do redesign visual (ver
/// docs/redesign-visual.md). Define só o que é global (cores, tipografia,
/// formato padrão de botões/cards/inputs); nenhuma tela foi alterada aqui,
/// elas herdam isso automaticamente por já usarem widgets Material padrão.
class AppTheme {
  AppTheme._();

  static final ThemeData light = _buildTheme();

  static ThemeData _buildTheme() {
    const corScheme = ColorScheme.light(
      primary: AppColors.sage,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.mint,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.backgroundSecondary,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.white,
    );

    // Raio padrão dos elementos arredondados do app — levemente arredondado,
    // não o "pill" exagerado nem o quadrado seco do Material puro.
    const raioPadrao = 14.0;

    return ThemeData(
      useMaterial3: true,
      colorScheme: corScheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.subtitulo(),
      ),

      textTheme: TextTheme(
        headlineLarge: AppTextStyles.titulo(),
        headlineMedium: AppTextStyles.titulo(),
        titleLarge: AppTextStyles.subtitulo(),
        titleMedium: AppTextStyles.labelCategoria(),
        bodyLarge: AppTextStyles.corpo(),
        bodyMedium: AppTextStyles.corpo(),
        bodySmall: AppTextStyles.secundario(),
        labelLarge: AppTextStyles.botao(),
        labelMedium: AppTextStyles.labelCategoria(),
      ),

      cardTheme: CardThemeData(
        color: AppColors.backgroundSecondary,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raioPadrao)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.textPrimary,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          textStyle: AppTextStyles.botao(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raioPadrao)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.sage),
          textStyle: AppTextStyles.botao(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raioPadrao)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: AppTextStyles.botao(),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        labelStyle: AppTextStyles.corpo(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPadrao),
          borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPadrao),
          borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(raioPadrao),
          borderSide: const BorderSide(color: AppColors.sage, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedColor: AppColors.sage,
        labelStyle: AppTextStyles.botao(),
        secondaryLabelStyle: AppTextStyles.botao(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(raioPadrao),
          side: BorderSide(color: AppColors.sage.withValues(alpha: 0.4)),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBar,
        selectedItemColor: AppColors.navBarAccent,
        unselectedItemColor: AppColors.white.withValues(alpha: 0.6),
        selectedLabelStyle: AppTextStyles.navBar(color: AppColors.navBarAccent),
        unselectedLabelStyle: AppTextStyles.navBar(),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navBarAccent,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }
}
