import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/peca_parada.dart';
import '../looks/montar_look_view.dart';
import '../references/references_view.dart';
import '../suggestions/suggestions_view.dart';
import '../wardrobe/wardrobe_view.dart';
import 'home_view.dart';
import 'peca_parada_controller.dart';
import 'widgets/dialogo_peca_parada.dart';

/// Casca de navegação principal do app (redesign visual, Etapa 4) — 5 abas:
/// Casa (atalhos + calendário de looks), Armário (peças e looks salvos),
/// Looks (montagem de um look novo), Sugestões (antiga "IA", E5.F2.1) e Referências
/// (placeholder). Cada aba mantém seu próprio `Scaffold`; esta casca só
/// adiciona a barra inferior e preserva o estado de cada aba via
/// `IndexedStack`.
///
/// Na primeira vez que aparece na sessão, mostra o aviso de peça parada
/// (E13.F1.2), se houver alguma.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _indiceAtual = 0;

  /// Um aviso por sessão, e só com a casca visível: nunca por cima de uma
  /// tela empilhada (se houver uma, o aviso fica para a próxima abertura).
  void _talvezAvisarPecaParada(PecaParada? parada) {
    if (parada == null || ref.read(avisoPecaParadaMostradoProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(avisoPecaParadaMostradoProvider)) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      ref.read(avisoPecaParadaMostradoProvider.notifier).state = true;
      mostrarDialogoPecaParada(context, parada);
    });
  }

  static const _telas = [
    HomeView(),
    WardrobeView(),
    MontarLookView(),
    SuggestionsView(),
    ReferencesView(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PecaParada?>>(
      pecaParadaProvider,
      (_, proximo) => _talvezAvisarPecaParada(proximo.valueOrNull),
    );
    return Scaffold(
      body: IndexedStack(index: _indiceAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (index) => setState(() => _indiceAtual = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Casa'),
          const BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: 'Armário'),
          BottomNavigationBarItem(
            // Item central com destaque visual permanente (não só quando
            // selecionado) — espelha o recorte/destaque do botão central
            // no Figma de referência.
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.navBarAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_fix_high, color: AppColors.textPrimary, size: 20),
            ),
            // "Montar", não "Looks": os looks salvos ficam em Armário › Looks.
            label: 'Montar',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Sugestões'),
          const BottomNavigationBarItem(icon: Icon(Icons.image_outlined), label: 'Referências'),
        ],
      ),
    );
  }
}
