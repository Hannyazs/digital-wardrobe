import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/screen_header.dart';
import '../looks/looks_controller.dart';
import '../looks/montar_look_view.dart';
import '../preferences/preferences_view.dart';
import '../upload/upload_view.dart';
import 'look_do_dia_controller.dart';
import 'widgets/calendario_recolhivel.dart';
import 'widgets/card_look_do_dia.dart';

/// Tela inicial do app — aba "Casa". Do mais para o menos usado: saudação com
/// o acesso discreto às preferências de estilo (ícone no cabeçalho), as duas
/// ações principais lado a lado (adicionar peça, montar um look), o card
/// compacto do "Look do dia" (E6.F1.2) e o calendário de looks (E3.F4.3),
/// recolhido até a pessoa querer vê-lo.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final mes = ref.read(mesVisivelProvider);
          ref.invalidate(historicoMesProvider(mes));
          await Future.wait([
            ref.read(historicoMesProvider(mes).future),
            ref.read(lookDoDiaProvider.notifier).carregar(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
              titulo: 'Olá!',
              subtitulo: 'Vamos escolher o que vestir.',
              compacto: true,
              acao: IconButton(
                tooltip: 'Preferências de estilo',
                icon: const Icon(Icons.tune),
                onPressed: () => _abrir(context, const PreferencesView()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Os dois botões com a mesma altura (o de texto mais longo manda).
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AcaoPrincipal(
                            label: 'Adicionar peça',
                            // Ícone diferente do FAB do armário (Icons.add_a_photo) de
                            // propósito: o `IndexedStack` do `HomeShell` mantém todas
                            // as abas montadas ao mesmo tempo, então os dois ícones
                            // coexistem na árvore de widgets — precisam ser distintos
                            // pra não ficar ambíguo em testes (`find.byIcon`).
                            icone: Icons.add_photo_alternate_outlined,
                            destaque: true,
                            onPressed: () =>
                                _abrir(context, const UploadView()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AcaoPrincipal(
                            label: 'Montar um look',
                            icone: Icons.checkroom,
                            onPressed: () =>
                                _abrir(context, const MontarLookView()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const CardLookDoDia(),
                  const SizedBox(height: 12),
                  const CalendarioRecolhivel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atalho grande da Casa: ícone sobre o rótulo, num botão do tema (o primeiro
/// preenchido, o segundo com contorno). O texto pode quebrar em duas linhas
/// em telas estreitas, em vez de estourar a largura.
class _AcaoPrincipal extends StatelessWidget {
  const _AcaoPrincipal({
    required this.label,
    required this.icone,
    required this.onPressed,
    this.destaque = false,
  });

  final String label;
  final IconData icone;
  final VoidCallback onPressed;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 26),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, maxLines: 2),
      ],
    );
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    const minimo = Size(0, 76);
    return destaque
        ? ElevatedButton(
            onPressed: onPressed,
            style:
                ElevatedButton.styleFrom(padding: padding, minimumSize: minimo),
            child: conteudo,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style:
                OutlinedButton.styleFrom(padding: padding, minimumSize: minimo),
            child: conteudo,
          );
  }
}
