import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/peca_opcoes.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/preferencia.dart';
import '../preferences_controller.dart';

/// Máximo de pares aceito pelo backend (E4.F1.1: `MAX_COMBINACOES_CORES`).
const maxCombinacoesCores = 20;

/// Seção "Cores que combinam" (E4.F1.2): pares de cores favoritas, salvos na
/// hora a cada adição ou remoção.
class SecaoCoresFavoritas extends ConsumerWidget {
  const SecaoCoresFavoritas({super.key, required this.combinacoes});

  final List<CombinacaoCores> combinacoes;

  Future<void> _salvar(
    BuildContext context,
    WidgetRef ref,
    List<CombinacaoCores> novaLista,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final erro = await ref.read(preferenciasProvider.notifier).atualizar(
      {'combinacoes_cores': novaLista.map((par) => par.toJson()).toList()},
      (atual) => atual.copyWith(combinacoesCores: novaLista),
    );
    if (erro != null) messenger.showSnackBar(SnackBar(content: Text(erro)));
  }

  Future<void> _adicionar(BuildContext context, WidgetRef ref) async {
    final novo = await showModalBottomSheet<CombinacaoCores>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NovaCombinacaoSheet(existentes: combinacoes),
    );
    if (novo == null || !context.mounted) return; // sheet dispensado
    await _salvar(context, ref, [...combinacoes, novo]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cheio = combinacoes.length >= maxCombinacoesCores;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cores que combinam', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pares de cores que você gosta de usar juntas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (combinacoes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhuma combinação ainda. Adicione a primeira.'),
              )
            else
              for (final par in combinacoes)
                _LinhaDoPar(
                  par: par,
                  onRemover: () => _salvar(
                    context,
                    ref,
                    combinacoes.where((outro) => outro != par).toList(),
                  ),
                ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Adicionar combinação',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: cheio ? null : () => _adicionar(context, ref),
            ),
            if (cheio)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Limite de $maxCombinacoesCores combinações. Remova uma para adicionar outra.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _corDe(String nome) {
  for (final opcao in coresFixas) {
    if (opcao.nome == nome) return opcao.cor;
  }
  return Colors.grey; // cor fora da lista fixa (ex.: vinda de outro cliente)
}

class _Amostra extends StatelessWidget {
  const _Amostra(this.nome);

  final String nome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _corDe(nome),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}

class _LinhaDoPar extends StatelessWidget {
  const _LinhaDoPar({required this.par, required this.onRemover});

  final CombinacaoCores par;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Amostra(par.corA),
        const SizedBox(width: 4),
        _Amostra(par.corB),
        const SizedBox(width: 12),
        Expanded(child: Text('${par.corA} + ${par.corB}')),
        IconButton(
          tooltip: 'Remover ${par.corA} + ${par.corB}',
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemover,
        ),
      ],
    );
  }
}

/// Bottom sheet com duas fileiras de cores. "Adicionar" só habilita com duas
/// cores diferentes e um par que ainda não existe (em qualquer ordem).
class _NovaCombinacaoSheet extends StatefulWidget {
  const _NovaCombinacaoSheet({required this.existentes});

  final List<CombinacaoCores> existentes;

  @override
  State<_NovaCombinacaoSheet> createState() => _NovaCombinacaoSheetState();
}

class _NovaCombinacaoSheetState extends State<_NovaCombinacaoSheet> {
  String? _corA;
  String? _corB;

  String? get _problema {
    if (_corA == null || _corB == null) return null;
    if (_corA == _corB) return 'Escolha duas cores diferentes.';
    final par = CombinacaoCores(_corA!, _corB!);
    if (widget.existentes.any(par.mesmoPar)) return 'Essa combinação já existe.';
    return null;
  }

  bool get _valido => _corA != null && _corB != null && _problema == null;

  Widget _fileira(String titulo, Key chave, String? selecionada, ValueChanged<String> aoEscolher) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          key: chave,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final opcao in coresFixas)
              ChoiceChip(
                avatar: _Amostra(opcao.nome),
                label: Text(opcao.nome),
                selected: selecionada == opcao.nome,
                onSelected: (_) => aoEscolher(opcao.nome),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fileira('Primeira cor', const Key('cores-a'), _corA, (nome) => setState(() => _corA = nome)),
            const SizedBox(height: 16),
            _fileira('Segunda cor', const Key('cores-b'), _corB, (nome) => setState(() => _corB = nome)),
            if (_problema != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _problema!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Adicionar',
              onPressed: _valido
                  ? () => Navigator.of(context).pop(CombinacaoCores(_corA!, _corB!))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
