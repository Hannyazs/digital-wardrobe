import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/peca_opcoes.dart' show comValorAtual, ocasioesFixas;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../models/sugestao.dart';
import '../../looks/widgets/pecas_do_look.dart';
import '../../suggestions/widgets/conteudo_sugestao.dart';
import '../look_do_dia_controller.dart';

/// Card "Look do dia" no topo da Casa (E6.F1.2): um look para a ocasião
/// escolhida, montado pelo motor do Épico 5 em modo rotatividade (E6.F1.1).
/// Erros e armário insuficiente ficam dentro do card — os atalhos e o
/// calendário da Casa continuam funcionando.
///
/// Versão compacta (reorganização da Casa): as peças ficam numa única linha,
/// só a primeira justificativa aparece (as demais e os avisos abrem em
/// "Detalhes") e as três ações dividem uma ou duas linhas curtas.
class CardLookDoDia extends ConsumerWidget {
  const CardLookDoDia({super.key});

  Future<void> _avisar(BuildContext context, Future<String?> acao, String sucesso) async {
    final messenger = ScaffoldMessenger.of(context);
    final erro = await acao;
    // A confirmação nova substitui a anterior (ex.: "Salvar" e logo "Usei hoje").
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(erro ?? sucesso)));
  }

  Future<void> _trocarOcasiao(BuildContext context, WidgetRef ref, String ocasiao) async {
    final messenger = ScaffoldMessenger.of(context);
    final erro = await ref.read(lookDoDiaProvider.notifier).trocarOcasiao(ocasiao);
    if (erro != null) messenger.showSnackBar(SnackBar(content: Text(erro)));
  }

  void _verDetalhes(BuildContext context, Sugestao look) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Por que este look', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ConteudoSugestao(sugestao: look, mostrarPecas: false),
            ],
          ),
        ),
      ),
    );
  }

  /// Botões mais enxutos só dentro do card: menos padding lateral e altura
  /// mínima de 44 px (alvo de toque confortável), herdando o resto do tema.
  ThemeData _temaCompacto(ThemeData tema) {
    const enxuto = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      minimumSize: WidgetStatePropertyAll(Size(0, 44)),
      // Sem a área de toque extra do tema: a altura do botão já é a de 44 px.
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return tema.copyWith(
      textButtonTheme: TextButtonThemeData(style: tema.textButtonTheme.style?.merge(enxuto) ?? enxuto),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: tema.outlinedButtonTheme.style?.merge(enxuto) ?? enxuto),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: tema.elevatedButtonTheme.style?.merge(enxuto) ?? enxuto),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(lookDoDiaProvider);
    final controller = ref.read(lookDoDiaProvider.notifier);
    final resultado = estado.resultado;
    final carregando = resultado == null || resultado.isLoading;

    return Card(
      key: const ValueKey('card-look-do-dia'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Look do dia', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (estado.ocasiao != null)
                  // Largura limitada: com fonte grande o seletor encolhe (e corta o
                  // texto com reticências) em vez de empurrar o título para fora.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: DropdownButton<String>(
                      key: const ValueKey('look-do-dia-ocasiao'),
                      value: estado.ocasiao,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final o in comValorAtual(ocasioesFixas, estado.ocasiao))
                          DropdownMenuItem(
                            value: o,
                            child: Text(o, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: carregando || estado.ocupado
                          ? null
                          : (o) {
                              if (o != null && o != estado.ocasiao) _trocarOcasiao(context, ref, o);
                            },
                    ),
                  ),
              ],
            ),
            if (carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              resultado.when(
                loading: () => const SizedBox.shrink(),
                error: (erro, _) => Column(
                  children: [
                    _Mensagem(icone: Icons.error_outline, texto: erro.toString()),
                    AppButton(
                      label: 'Tentar novamente',
                      variant: AppButtonVariant.secondary,
                      onPressed: controller.carregar,
                    ),
                  ],
                ),
                data: (dia) {
                  final look = dia.look;
                  if (look == null) {
                    return _Mensagem(
                      icone: Icons.info_outline,
                      texto: dia.motivo ?? 'Nenhum look disponível para hoje.',
                    );
                  }
                  final jaExistia = dia.lookSalvoId != null;
                  final salvo = estado.idSalvo != null;
                  final usado = estado.usados.contains(look.chave);
                  final temAvisos = look.avisos.isNotEmpty;
                  final temMaisDetalhes = look.explicacoes.length > 1 || temAvisos;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      PecasDoLook(pecas: look.pecas, ajustarALargura: true),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              look.explicacoes.isEmpty ? '' : look.explicacoes.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (temMaisDetalhes)
                            TextButton.icon(
                              style: const ButtonStyle(
                                padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
                                minimumSize: WidgetStatePropertyAll(Size(0, 40)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _verDetalhes(context, look),
                              icon: Icon(
                                temAvisos ? Icons.warning_amber_rounded : Icons.info_outline,
                                size: 18,
                                color: temAvisos ? Colors.orange : null,
                              ),
                              label: const Text('Detalhes'),
                            ),
                        ],
                      ),
                      if (jaExistia)
                        Row(
                          children: [
                            const Icon(Icons.bookmark, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Este look já está em Armário › Looks.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Theme(
                        data: _temaCompacto(Theme.of(context)),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            AppButton(
                              label: 'Outra sugestão',
                              variant: AppButtonVariant.text,
                              onPressed: dia.temMais && !estado.ocupado
                                  ? controller.outraSugestao
                                  : null,
                            ),
                            AppButton(
                              label: jaExistia ? 'Já salvo' : (salvo ? 'Salvo' : 'Salvar'),
                              icon: salvo ? Icons.check : null,
                              variant: AppButtonVariant.secondary,
                              onPressed: salvo || estado.ocupado
                                  ? null
                                  : () => _avisar(
                                        context,
                                        controller.salvar(),
                                        'Look salvo em Armário › Looks.',
                                      ),
                            ),
                            AppButton(
                              label: usado ? 'Usado hoje' : 'Usei hoje',
                              icon: usado ? Icons.check : null,
                              onPressed: usado || estado.ocupado
                                  ? null
                                  : () => _avisar(
                                        context,
                                        controller.usarHoje(),
                                        'Uso registrado para hoje.',
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icone, size: 28, color: AppColors.sage),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
