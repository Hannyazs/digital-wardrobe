import 'package:flutter/material.dart';

import '../looks/looks_view.dart';
import '../wardrobe/wardrobe_view.dart';

/// Casca de navegação com as duas telas principais do app (E2.F1.1).
/// Cada aba mantém seu próprio `Scaffold`/`AppBar`; esta casca só adiciona
/// a barra inferior e preserva o estado de cada aba via `IndexedStack`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indiceAtual = 0;

  static const _telas = [WardrobeView(), LooksView()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (index) => setState(() => _indiceAtual = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: 'Armário'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Looks'),
        ],
      ),
    );
  }
}
