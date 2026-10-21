import 'package:flutter/material.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/screen_header.dart';
import '../looks/montar_look_view.dart';
import '../preferences/preferences_view.dart';
import '../upload/upload_view.dart';

/// Tela inicial do app — aba "Casa" (redesign visual, Etapa 4). Saudação +
/// atalhos pras ações mais comuns, sem virar um dashboard (sem métricas,
/// sem gráficos — só o convite pra próxima ação).
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const ScreenHeader(
            titulo: 'Welcome!',
            subtitulo: "Let's get started.",
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
