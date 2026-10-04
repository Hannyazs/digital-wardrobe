import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Hierarquia tipográfica única do app, espelhando a combinação de fontes
/// do Figma "VIRTUALASSIST": uma fonte forte/serifada pro título principal
/// ("Morning, Mo!" → Bevan), uma monoespaçada pro resto do texto com
/// personalidade ("Let's get started.", labels, botões, nav bar → Source
/// Code Pro — mais fácil de obter no Flutter que a Cascadia Code original
/// do design, mesma sensação de "máquina de escrever"), uma cursiva pros
/// toques "levemente divertidos" (Caveat), e uma fonte simples/legível pro
/// conteúdo real do app (formulários, descrições — texto corrido longo não
/// deveria ser monoespaçado nem cursivo, prejudica leitura).
///
/// Nenhuma tela deve chamar `GoogleFonts.x()` diretamente — sempre por aqui,
/// pra manter a hierarquia consistente em vez de fontes soltas tela a tela.
class AppTextStyles {
  AppTextStyles._();

  /// Título principal de tela (ex: "Morning, Mo!").
  static TextStyle titulo({Color color = AppColors.textPrimary}) =>
      GoogleFonts.bevan(fontSize: 26, color: color, height: 1.2);

  /// Subtítulo logo abaixo do título (ex: "Let's get started.").
  static TextStyle subtitulo({Color color = AppColors.textPrimary}) =>
      GoogleFonts.sourceCodePro(fontSize: 19, fontWeight: FontWeight.w500, color: color);

  /// Texto normal — conteúdo real (formulários, descrições, listas). Fonte
  /// simples e legível, não estilizada.
  static TextStyle corpo({Color color = AppColors.textPrimary}) =>
      TextStyle(fontSize: 14, color: color, height: 1.4);

  /// Texto secundário/legenda com um toque mais pessoal e descontraído.
  static TextStyle secundario({Color color = AppColors.textSecondary}) =>
      GoogleFonts.caveat(fontSize: 20, color: color);

  /// Label de categoria (ex: "ACESSÓRIOS", "TOPS") — monoespaçada, caixa
  /// alta, mesma família do subtítulo/botões.
  static TextStyle labelCategoria({Color color = AppColors.textPrimary}) =>
      GoogleFonts.sourceCodePro(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.6,
      );

  /// Texto de botões.
  static TextStyle botao({Color color = AppColors.textPrimary}) =>
      GoogleFonts.sourceCodePro(fontSize: 14, fontWeight: FontWeight.w600, color: color);

  /// Labels da barra de navegação inferior.
  static TextStyle navBar({Color color = AppColors.white}) =>
      GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.w500, color: color);
}
