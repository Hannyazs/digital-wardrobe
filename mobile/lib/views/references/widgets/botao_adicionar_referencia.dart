import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../references_controller.dart';
import 'adicionar_referencia.dart';

/// Botão flutuante "Adicionar" do mural e das grades de coleção; vira
/// "Analisando a referência…" enquanto uma foto sobe e a IA etiqueta as peças.
class BotaoAdicionarReferencia extends ConsumerWidget {
  const BotaoAdicionarReferencia({super.key, this.colecaoInicial});

  final String? colecaoInicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enviando = ref.watch(enviandoReferenciaProvider);
    return FloatingActionButton.extended(
      // Sem tag de Hero: as abas ficam todas montadas na HomeShell e a tag padrão
      // se repetiria entre os botões flutuantes, quebrando a navegação.
      heroTag: null,
      onPressed: enviando
          ? null
          : () => adicionarReferencia(context, colecaoInicial: colecaoInicial),
      icon: enviando
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.add_photo_alternate_outlined),
      // O envio inclui a análise da IA (alguns segundos): o texto diz o que acontece.
      label: Text(enviando ? 'Analisando a referência…' : 'Adicionar'),
    );
  }
}
