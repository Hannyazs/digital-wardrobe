import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../models/colecao.dart';
import '../../models/referencia.dart';
import 'colecao_grade_view.dart';
import 'references_controller.dart';
import 'widgets/dialogos_de_colecao.dart';

/// Aba "Coleções" do mural (E8.F2.2): as separações criadas pelo usuário, com
/// quantidade e miniatura, mais a entrada "Sem coleção". Criar, renomear e
/// excluir coleção; tocar abre a grade dela.
class ColecoesTab extends ConsumerWidget {
  const ColecoesTab({super.key});

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final nome = await pedirNomeDaColecao(context, titulo: 'Nova coleção');
    if (nome == null) return;
    try {
      await ref.read(colecoesProvider.notifier).criar(nome);
    } catch (erro) {
      messenger
          .showSnackBar(SnackBar(content: Text(mensagemDeErroDaColecao(erro))));
    }
  }

  Future<void> _renomear(
      BuildContext context, WidgetRef ref, Colecao colecao) async {
    final messenger = ScaffoldMessenger.of(context);
    final nome = await pedirNomeDaColecao(context,
        titulo: 'Renomear coleção', nomeAtual: colecao.nome);
    if (nome == null || nome == colecao.nome) return;
    try {
      await ref.read(colecoesProvider.notifier).renomear(colecao.id, nome);
    } catch (erro) {
      messenger
          .showSnackBar(SnackBar(content: Text(mensagemDeErroDaColecao(erro))));
    }
  }

  Future<void> _excluir(
      BuildContext context, WidgetRef ref, Colecao colecao) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmarExclusaoDaColecao(context, colecao.nome)) return;
    try {
      await ref.read(colecoesProvider.notifier).excluir(colecao.id);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(mensagemDeErroDaColecao(erro, acao: 'excluir a'))),
      );
    }
  }

  void _abrir(BuildContext context, String? colecaoId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => ColecaoGradeView(colecaoId: colecaoId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colecoesAsync = ref.watch(colecoesProvider);
    final referencias =
        ref.watch(referenciasProvider).valueOrNull ?? const <Referencia>[];

    // Durante uma atualização das contagens a lista anterior continua na tela.
    final colecoes = colecoesAsync.valueOrNull;
    if (colecoes == null) {
      if (colecoesAsync.hasError) {
        return ListView(
          children: [
            _Aviso(
              icone: Icons.cloud_off_outlined,
              texto: 'Não foi possível carregar suas coleções.',
              acao: AppButton(
                label: 'Tentar de novo',
                onPressed: () => ref.invalidate(colecoesProvider),
              ),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final semColecao = referencias.where((r) => r.colecaoId == null).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        AppButton(
          label: 'Nova coleção',
          icon: Icons.create_new_folder_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => _criar(context, ref),
        ),
        const SizedBox(height: 12),
        if (colecoes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Crie coleções para separar suas referências (ex.: Festa, Trabalho).',
              textAlign: TextAlign.center,
            ),
          ),
        for (final colecao in colecoes)
          _CartaoDeColecao(
            titulo: colecao.nome,
            quantidade: colecao.quantidade,
            miniatura:
                referencias.where((r) => r.colecaoId == colecao.id).firstOrNull,
            onTap: () => _abrir(context, colecao.id),
            menu: PopupMenuButton<String>(
              tooltip: 'Opções da coleção ${colecao.nome}',
              onSelected: (opcao) => opcao == 'renomear'
                  ? _renomear(context, ref, colecao)
                  : _excluir(context, ref, colecao),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ),
        _CartaoDeColecao(
          titulo: 'Sem coleção',
          quantidade: semColecao.length,
          miniatura: semColecao.firstOrNull,
          onTap: () => _abrir(context, null),
        ),
      ],
    );
  }
}

class _CartaoDeColecao extends StatelessWidget {
  const _CartaoDeColecao({
    required this.titulo,
    required this.quantidade,
    required this.miniatura,
    required this.onTap,
    this.menu,
  });

  final String titulo;
  final int quantidade;
  final Referencia? miniatura;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: miniatura == null
                ? const ColoredBox(
                    color: AppColors.mint,
                    child: Icon(Icons.folder_outlined,
                        color: AppColors.sageEscuro),
                  )
                : Image.network(
                    AppConstants.resolveMediaUrl(miniatura!.imagemUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, erro, stack) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        title: Text(titulo),
        subtitle:
            Text(quantidade == 1 ? '1 referência' : '$quantidade referências'),
        trailing: menu,
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, required this.acao});

  final IconData icone;
  final String texto;
  final Widget acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icone, size: 56, color: AppColors.sage),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          acao,
        ],
      ),
    );
  }
}
