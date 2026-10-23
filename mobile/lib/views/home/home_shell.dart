import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../looks/montar_look_view.dart';
import '../references/references_view.dart';
import '../suggestions/suggestions_view.dart';
import '../wardrobe/wardrobe_view.dart';
import 'home_view.dart';

/// Casca de navegação principal do app (redesign visual, Etapa 4) — 5 abas:
/// Casa (atalhos + calendário de looks), Armário (peças e looks salvos),
/// Looks (montagem de um look novo), Sugestões (antiga "IA", E5.F2.1) e Referências
/// (placeholder). Cada aba mantém seu próprio `Scaffold`; esta casca só
/// adiciona a barra inferior e preserva o estado de cada aba via
/// `IndexedStack`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indiceAtual = 0;

  static const _telas = [
    HomeView(),
    WardrobeView(),
    MontarLookView(),
    SuggestionsView(),
    ReferencesView(),
  ];

  @override
  Widget build(BuildContext context) {
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
