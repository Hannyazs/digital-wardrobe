import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/referencia.dart';
import '../references_controller.dart';

/// Limites do backend (`ETIQUETA_MAX` e `ETIQUETAS_MAX`).
const etiquetaMax = 40;
const etiquetasMax = 10;

/// Etiquetas das peças visíveis na referência (E8.F4.1): chips sugeridos pela
/// IA que o usuário pode tocar para editar, remover ou acrescentar. Cada
/// mudança grava a lista inteira no servidor.
class EtiquetasDaReferencia extends ConsumerWidget {
  const EtiquetasDaReferencia({super.key, required this.referencia});

  final Referencia referencia;

  Future<void> _salvar(BuildContext context, WidgetRef ref, List<String> novas) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(referenciasProvider.notifier).atualizarEtiquetas(referencia.id, novas);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroDaReferencia(erro, acao: 'salvar as etiquetas da'))),
      );
    }
  }

  bool _repetida(String texto, {String? exceto}) => referencia.etiquetas.any(
        (e) => e != exceto && e.toLowerCase() == texto.toLowerCase(),
      );

  Future<void> _adicionar(BuildContext context, WidgetRef ref) async {
    final texto = await pedirEtiqueta(context, titulo: 'Nova etiqueta');
    if (texto == null || !context.mounted || _repetida(texto)) return;
    await _salvar(context, ref, [...referencia.etiquetas, texto]);
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, String atual) async {
    final texto = await pedirEtiqueta(context, titulo: 'Editar etiqueta', atual: atual);
    if (texto == null || texto == atual || !context.mounted || _repetida(texto, exceto: atual)) {
      return;
    }
    await _salvar(context, ref, [for (final e in referencia.etiquetas) e == atual ? texto : e]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etiquetas = referencia.etiquetas;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Peças na imagem', style: tema.labelLarge),
        if (etiquetas.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('Sugeridas pela IA — revise', style: tema.bodySmall)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final etiqueta in etiquetas)
                InputChip(
                  label: Text(etiqueta),
                  onPressed: () => _editar(context, ref, etiqueta),
                  onDeleted: () =>
                      _salvar(context, ref, [for (final e in etiquetas) if (e != etiqueta) e]),
                  deleteButtonTooltipMessage: 'Remover etiqueta $etiqueta',
                ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: etiquetas.length >= etiquetasMax ? null : () => _adicionar(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              etiquetas.length >= etiquetasMax ? 'Limite de etiquetas atingido' : 'Adicionar etiqueta',
            ),
          ),
        ),
      ],
    );
  }
}

/// Diálogo de uma etiqueta (até 40 caracteres). Devolve o texto sem espaços nas
/// pontas, ou `null` se cancelou. Texto vazio não fecha o diálogo.
Future<String?> pedirEtiqueta(BuildContext context, {required String titulo, String? atual}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoDeEtiqueta(titulo: titulo, atual: atual),
  );
}

class _DialogoDeEtiqueta extends StatefulWidget {
  const _DialogoDeEtiqueta({required this.titulo, this.atual});

  final String titulo;
  final String? atual;

  @override
  State<_DialogoDeEtiqueta> createState() => _DialogoDeEtiquetaState();
}

class _DialogoDeEtiquetaState extends State<_DialogoDeEtiqueta> {
  late final _controller = TextEditingController(text: widget.atual);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controller.text.trim();
    if (texto.isNotEmpty) Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controller,
        maxLength: etiquetaMax,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirmar(),
        decoration: const InputDecoration(
          labelText: 'Peça',
          hintText: 'Ex.: camiseta branca',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
