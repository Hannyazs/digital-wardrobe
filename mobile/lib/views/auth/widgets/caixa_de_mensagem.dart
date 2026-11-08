import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Mensagem em destaque nas telas de conta: erro (vermelho) ou informação
/// (verde do tema). Anunciada por leitores de tela quando aparece.
class CaixaDeMensagem extends StatelessWidget {
  const CaixaDeMensagem(this.mensagem, {super.key, this.erro = true, this.acao});

  final String mensagem;
  final bool erro;

  /// Botão opcional abaixo do texto (ex.: "Pedir um link novo").
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cor = erro ? AppColors.error : AppColors.sageEscuro;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(erro ? Icons.error_outline : Icons.info_outline, color: cor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(mensagem, style: AppTextStyles.corpo())),
              ],
            ),
            if (acao != null) Align(alignment: Alignment.centerRight, child: acao),
          ],
        ),
      ),
    );
  }
}
