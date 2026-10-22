import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import '../looks/calendario_de_looks.dart';
import '../looks/looks_controller.dart';
import '../looks/montar_look_view.dart';
import '../preferences/preferences_view.dart';
import '../upload/upload_view.dart';
import 'look_do_dia_controller.dart';
import 'widgets/card_look_do_dia.dart';

/// Tela inicial do app — aba "Casa" (redesign visual, Etapa 4). Concentra o
/// que é útil no dia a dia: atalhos para as ações mais comuns e o calendário
/// de looks usados (E3.F4.3, antes dentro dos looks salvos), com o card "Look
/// do dia" (E6.F1.2) no topo, acima dos atalhos.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

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
            const ScreenHeader(
              titulo: 'Welcome!',
              subtitulo: "Let's get started.",
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CardLookDoDia(),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Adicionar peça',
                    // Ícone diferente do FAB do armário (Icons.add_a_photo) de
                    // propósito: o `IndexedStack` do `HomeShell` mantém todas
                    // as abas montadas ao mesmo tempo, então os dois ícones
                    // coexistem na árvore de widgets — precisam ser distintos
                    // pra não ficar ambíguo em testes (`find.byIcon`).
                    icon: Icons.add_photo_alternate_outlined,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const UploadView()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Montar um look',
                    icon: Icons.checkroom,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const MontarLookView()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Preferências de estilo',
                    icon: Icons.tune,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PreferencesView()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Calendário de looks', style: AppTextStyles.labelCategoria()),
                  const SizedBox(height: 4),
                  const CalendarioDeLooks(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
