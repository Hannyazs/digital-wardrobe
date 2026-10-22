import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botão de filtros (ícone de "menu" de linhas) usado no armário, nas gavetas,
/// nos looks salvos e na montagem de look. Abre o painel de filtros
/// (`abrirPainelDeFiltros`); com filtros ativos mostra quantos estão marcados.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.onTap, this.quantidade = 0});

  final VoidCallback onTap;

  /// Quantos valores de filtro estão marcados; 0 = nenhum (sem selo).
  final int quantidade;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Filtros',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: quantidade > 0 ? AppColors.sage : AppColors.backgroundSecondary,
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      icon: Badge(
        isLabelVisible: quantidade > 0,
        label: Text('$quantidade'),
        backgroundColor: AppColors.textPrimary,
        child: const Icon(Icons.filter_list, color: AppColors.textPrimary),
      ),
    );
  }
}
