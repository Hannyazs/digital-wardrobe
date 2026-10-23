import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/peca_opcoes.dart' show comValorAtual, ocasioesFixas;
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../suggestions/widgets/conteudo_sugestao.dart';
import '../look_do_dia_controller.dart';

/// Card "Look do dia" no topo da Casa (E6.F1.2): um look para a ocasião
/// escolhida, montado pelo motor do Épico 5 em modo rotatividade (E6.F1.1).
/// Erros e armário insuficiente ficam dentro do card — os atalhos e o
/// calendário da Casa continuam funcionando.
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Look do dia', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (estado.ocasiao != null)
                  DropdownButton<String>(
                    key: const ValueKey('look-do-dia-ocasiao'),
                    value: estado.ocasiao,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final o in comValorAtual(ocasioesFixas, estado.ocasiao))
                        DropdownMenuItem(value: o, child: Text(o)),
                    ],
                    onChanged: carregando || estado.ocupado
                        ? null
                        : (o) {
                            if (o != null && o != estado.ocasiao) _trocarOcasiao(context, ref, o);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConteudoSugestao(sugestao: look),
                      if (jaExistia)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Este look já está em Armário › Looks.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppButton(
                            label: 'Outra sugestão',
                            variant: AppButtonVariant.text,
                            onPressed:
                                dia.temMais && !estado.ocupado ? controller.outraSugestao : null,
                          ),
                          AppButton(
                            label: jaExistia ? 'Já salvo' : (salvo ? 'Salvo' : 'Salvar'),
                            icon: salvo ? Icons.check : Icons.bookmark_add_outlined,
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
                            icon: usado ? Icons.check : Icons.today,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icone, size: 32, color: AppColors.sage),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
