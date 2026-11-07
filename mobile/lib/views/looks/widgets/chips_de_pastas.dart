import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pasta_look.dart';
import '../pastas_controller.dart';
import 'dialogos_de_pasta.dart';

/// Fileira de chips no topo da aba Looks (E3.F6.2): "Todos", uma por pasta
/// (com a quantidade), "Sem pasta" e "Nova pasta". Com uma pasta escolhida,
/// aparece o menu dela (renomear e excluir).
///
/// Se as pastas não carregarem, ficam só "Todos" e "Sem pasta" e um botão de
/// recarregar: a lista de looks continua funcionando.
class ChipsDePastas extends ConsumerWidget {
  const ChipsDePastas({super.key});

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final nome = await pedirNomeDaPasta(context, titulo: 'Nova pasta');
    if (nome == null) return;
    try {
      await ref.read(pastasProvider.notifier).criar(nome);
    } catch (erro) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDeErroDaPasta(erro, acao: 'criar'))));
    }
  }

  Future<void> _renomear(BuildContext context, WidgetRef ref, PastaLook pasta) async {
    final messenger = ScaffoldMessenger.of(context);
    final nome = await pedirNomeDaPasta(context, titulo: 'Renomear pasta', nomeAtual: pasta.nome);
    if (nome == null || nome == pasta.nome) return;
    try {
      await ref.read(pastasProvider.notifier).renomear(pasta.id, nome);
    } catch (erro) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDeErroDaPasta(erro, acao: 'renomear'))));
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, PastaLook pasta) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmarExclusaoDaPasta(context, pasta.nome)) return;
    try {
      await ref.read(pastasProvider.notifier).excluir(pasta.id);
    } catch (erro) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDeErroDaPasta(erro, acao: 'excluir'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastasAsync = ref.watch(pastasProvider);
    final pastas = pastasAsync.valueOrNull ?? const <PastaLook>[];
    final selecao = ref.watch(pastaSelecionadaProvider);
    void escolher(SelecaoPasta nova) => ref.read(pastaSelecionadaProvider.notifier).state = nova;

    PastaLook? escolhida;
    for (final pasta in pastas) {
      if (pasta.id == selecao.pastaId) escolhida = pasta;
    }

    Widget chip(String rotulo, SelecaoPasta valor, {String? chave}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: chave == null ? null : ValueKey(chave),
            label: Text(rotulo),
            selected: selecao == valor,
            onSelected: (_) => escolher(valor),
          ),
        );

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              children: [
                chip('Todos', SelecaoPasta.todos),
                for (final pasta in pastas)
                  chip('${pasta.nome} (${pasta.quantidade})', SelecaoPasta.pasta(pasta.id),
                      chave: 'chip-pasta-${pasta.id}'),
                chip('Sem pasta', SelecaoPasta.nenhuma),
                if (pastasAsync.hasError)
                  IconButton(
                    tooltip: 'Recarregar pastas',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(pastasProvider),
                  )
                else
                  ActionChip(
                    avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('Nova pasta'),
                    onPressed: () => _criar(context, ref),
                  ),
              ],
            ),
          ),
          if (escolhida != null)
            PopupMenuButton<String>(
              tooltip: 'Opções da pasta',
              icon: const Icon(Icons.more_vert),
              onSelected: (acao) => acao == 'renomear'
                  ? _renomear(context, ref, escolhida!)
                  : _excluir(context, ref, escolhida!),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renomear', child: Text('Renomear pasta')),
                PopupMenuItem(value: 'excluir', child: Text('Excluir pasta')),
              ],
            ),
        ],
      ),
    );
  }
}
