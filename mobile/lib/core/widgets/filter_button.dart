import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Botão pílula "filtros" flutuando sobre o conteúdo — visual idêntico ao
/// do Figma de referência. O que `onTap` faz depende da tela: em telas com
/// filtro de verdade (armário), alterna a visibilidade do painel já
/// existente; em telas sem filtro implementado ainda, pode só avisar que
/// "ainda não está disponível" — nunca finge uma funcionalidade que não
/// existe.
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.onTap, this.ativo = false});

  final VoidCallback onTap;

  /// `true` quando algum filtro está aplicado — muda a cor de fundo pra
  /// dar feedback visual de que o filtro está ativo.
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ativo ? AppColors.sage : AppColors.backgroundSecondary,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 6),
              Text('filtros', style: AppTextStyles.botao()),
            ],
          ),
        ),
      ),
    );
  }
}
