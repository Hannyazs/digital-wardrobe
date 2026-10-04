import 'package:flutter/material.dart';

/// Paleta única do app — baseada no Figma "VIRTUALASSIST"
/// (docs/figma-reference/catalogo_looks_screen.png). Nenhuma tela deve usar
/// `Color(0x...)` direto; sempre através daqui, pra trocar o tema inteiro
/// num lugar só no futuro.
class AppColors {
  AppColors._();

  /// Fundo principal das telas — off-white, não branco puro (mais suave).
  static const background = Color(0xFFFBFBF7);

  /// Fundo secundário — superfícies elevadas (cards brancos sobre o fundo).
  static const backgroundSecondary = Color(0xFFFFFFFF);

  /// Verde/menta pastel — usado em gradientes de cabeçalho e destaques leves.
  static const mint = Color(0xFFD3FFE9);

  /// Verde acinzentado — cor "padrão" dos cards de peça/look (placeholder
  /// de imagem) e de acentos discretos.
  static const sage = Color(0xFF9BBDB3);

  /// Preto pra texto — nunca `Colors.black` puro, levemente suavizado.
  static const textPrimary = Color(0xFF14160F);

  /// Cinza pra texto secundário/legendas.
  static const textSecondary = Color(0xFF6E736B);

  static const white = Color(0xFFFFFFFF);

  /// Cor de fundo da barra de navegação inferior.
  static const navBar = Color(0xFF0D0D0D);

  /// Cor de destaque sobre a nav bar (ex: avatar/indicador da aba ativa).
  static const navBarAccent = Color(0xFF8FD9C4);

  static const error = Color(0xFFC75450);
}
