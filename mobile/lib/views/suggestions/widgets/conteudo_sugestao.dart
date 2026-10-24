import 'package:flutter/material.dart';

import '../../../models/sugestao.dart';
import '../../looks/widgets/pecas_do_look.dart';

/// Miolo de um look sugerido: miniaturas das peças, explicações e avisos.
/// Compartilhado pelos cards da aba Sugestões (E5.F2.1) e do "Look do dia"
/// na Casa (E6.F1.2); cada um põe as próprias ações embaixo. O "Look do dia"
/// só mostra o resumo no card e abre isto sem as peças (`mostrarPecas: false`)
/// na folha de detalhes.
class ConteudoSugestao extends StatelessWidget {
  const ConteudoSugestao({super.key, required this.sugestao, this.mostrarPecas = true});

  final Sugestao sugestao;
  final bool mostrarPecas;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarPecas) ...[
          PecasDoLook(pecas: sugestao.pecas),
          const SizedBox(height: 8),
        ],
        for (final frase in sugestao.explicacoes) Text('• $frase', style: estilo),
        for (final aviso in sugestao.avisos)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(aviso, style: estilo)),
              ],
            ),
          ),
      ],
    );
  }
}
