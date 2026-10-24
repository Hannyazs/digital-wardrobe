import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/referencia.dart';
import '../references_controller.dart';
import 'dialogo_de_nota.dart';
import 'etiquetas_da_referencia.dart';
import 'look_da_referencia.dart';

/// Detalhe de uma referência (E8.F1.2 a E8.F2.2): imagem grande com zoom, a
/// nota (editável), a coleção (trocável) e a exclusão. Lê a referência da
/// lista pelo [id], então as mudanças aparecem aqui e na grade assim que o
/// servidor confirma.
class ReferenciaDetalhe extends ConsumerWidget {
  const ReferenciaDetalhe({super.key, required this.id});

  final String id;

  Future<void> _editarNota(
      BuildContext context, WidgetRef ref, Referencia referencia) async {
    final messenger = ScaffoldMessenger.of(context);
    final nota = await pedirNotaDaReferencia(
      context,
      titulo: 'Nota da referência',
      notaAtual: referencia.nota,
    );
    if (nota == null) return;
    try {
      await ref.read(referenciasProvider.notifier).atualizarNota(id, nota);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                mensagemDeErroDaReferencia(erro, acao: 'salvar a nota da'))),
      );
    }
  }

  Future<void> _mover(
      BuildContext context, WidgetRef ref, String? colecaoId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(referenciasProvider.notifier).mover(id, colecaoId);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(mensagemDeErroDaReferencia(erro, acao: 'mover a'))),
      );
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Excluir esta referência?'),
        content: const Text('Não dá para desfazer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await ref.read(referenciasProvider.notifier).excluir(id);
      navigator.pop();
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(mensagemDeErroDaReferencia(erro, acao: 'excluir a'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referencia = ref
        .watch(referenciasProvider)
        .valueOrNull
        ?.where((r) => r.id == id)
        .firstOrNull;
    // Já excluída (a tela está fechando).
    if (referencia == null) return const Scaffold();

    final colecoes = ref.watch(colecoesProvider).valueOrNull;
    final nota = referencia.nota;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referência'),
        actions: [
          IconButton(
            tooltip: 'Excluir referência',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _excluir(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.network(
                  AppConstants.resolveMediaUrl(referencia.imagemUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, erro, stack) =>
                      const Icon(Icons.broken_image_outlined, size: 64),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    nota ?? 'Sem nota',
                    style: nota == null
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: nota == null ? 'Adicionar nota' : 'Editar nota',
                    icon: Icons.edit_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _editarNota(context, ref, referencia),
                  ),
                  const SizedBox(height: 16),
                EtiquetasDaReferencia(referencia: referencia),
                const SizedBox(height: 12),
                LookDaReferencia(referencia: referencia),
                // Sem as coleções carregadas não há o que escolher.
                  if (colecoes != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('colecao-${referencia.colecaoId}'),
                      initialValue:
                          colecoes.any((c) => c.id == referencia.colecaoId)
                              ? referencia.colecaoId
                              : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Coleção'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Sem coleção')),
                        for (final c in colecoes)
                          DropdownMenuItem<String?>(
                              value: c.id, child: Text(c.nome)),
                      ],
                      onChanged: (valor) {
                        if (valor != referencia.colecaoId) {
                          _mover(context, ref, valor);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
