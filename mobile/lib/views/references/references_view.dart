import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import '../../models/referencia.dart';
import 'colecoes_tab.dart';
import 'references_controller.dart';
import 'widgets/adicionar_referencia.dart';
import 'widgets/botao_adicionar_referencia.dart';
import 'widgets/grade_de_referencias.dart';
import 'widgets/referencia_detalhe.dart';

/// Mural de referências: aba "Todas" (grade com todas as imagens, adição pela
/// galeria — E8.F1.2) e aba "Coleções" (separações do usuário — E8.F2.2).
class ReferencesView extends StatelessWidget {
  const ReferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final abas = DefaultTabController.of(context);
          return Scaffold(
            // O botão "Adicionar" é só da aba "Todas"; em "Coleções" cada grade
            // tem o seu, já com a coleção escolhida.
            floatingActionButton: AnimatedBuilder(
              animation: abas,
              builder: (context, _) => abas.index == 0
                  ? const BotaoAdicionarReferencia()
                  : const SizedBox.shrink(),
            ),
            body: const Column(
              children: [
                ScreenHeader(
                  titulo: 'Inspirações',
                  subtitulo: 'Seu mural de referências',
                ),
                TabBar(tabs: [Tab(text: 'Todas'), Tab(text: 'Coleções')]),
                Expanded(
                  child: TabBarView(children: [_TodasTab(), ColecoesTab()]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodasTab extends ConsumerWidget {
  const _TodasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referencias = ref.watch(referenciasProvider);
    final enviando = ref.watch(enviandoReferenciaProvider);

    return ListView(
      children: [
        referencias.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (erro, stack) => _Mensagem(
            icone: Icons.cloud_off_outlined,
            texto: 'Não foi possível carregar suas referências.',
            acao: AppButton(
              label: 'Tentar de novo',
              onPressed: () => ref.invalidate(referenciasProvider),
            ),
          ),
          data: (lista) => lista.isEmpty
              ? _Mensagem(
                  icone: Icons.image_outlined,
                  texto: 'Salve aqui looks que te inspiram.',
                  acao: AppButton(
                    label: 'Adicionar',
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed:
                        enviando ? null : () => adicionarReferencia(context),
                  ),
                )
              : GradeDeReferencias(
                  referencias: lista,
                  onAbrir: (Referencia referencia) =>
                      Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => ReferenciaDetalhe(id: referencia.id)),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem(
      {required this.icone, required this.texto, required this.acao});

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
