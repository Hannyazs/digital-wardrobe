import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
    final ativo = quantidade > 0;
    // Ícone + texto: só o ícone de linhas pode ser lido como "menu", e a dica
    // do `Tooltip` só aparece com toque longo no celular.
    return Tooltip(
      message: 'Filtros',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: ativo ? 'Filtros, $quantidade marcados' : 'Filtros',
        excludeSemantics: true,
        child: Material(
          color: ativo ? AppColors.sage : AppColors.backgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: ativo,
                      label: Text('$quantidade'),
                      backgroundColor: AppColors.textPrimary,
                      child: const Icon(Icons.filter_list, color: AppColors.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text('Filtros', style: AppTextStyles.botao()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
