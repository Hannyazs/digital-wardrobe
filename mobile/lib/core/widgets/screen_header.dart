import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Cabeçalho com gradiente menta → fundo, usado no topo das telas
/// principais (Home, Criação de Looks, IA, Referências) — a mesma peça
/// visual do Figma de referência ("Morning, Mo!" / "Let's get started."),
/// reaproveitada com texto diferente em cada tela.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.textoSecundario,
    this.acao,
  });

  final String titulo;
  final String? subtitulo;
  final String? textoSecundario;

  /// Ação opcional (ex: botão "Meus looks") exibida no canto superior
  /// direito do próprio cabeçalho — em vez de uma `AppBar` separada, que
  /// ocuparia espaço extra e empurraria o degradê pra baixo.
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.6, 1.0],
          colors: [AppColors.mint, AppColors.mint, AppColors.background],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppTextStyles.titulo()),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 12),
                    Text(subtitulo!, style: AppTextStyles.subtitulo()),
                  ],
                  if (textoSecundario != null) ...[
                    const SizedBox(height: 6),
                    Text(textoSecundario!, style: AppTextStyles.secundario()),
                  ],
                ],
              ),
            ),
            if (acao != null) acao!,
          ],
        ),
      ),
    );
  }
}
