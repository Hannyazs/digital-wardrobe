import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Card de uma peça de roupa — usado no armário, na grade de seleção pra
/// montar um look, e nas miniaturas de um look salvo. Unifica o que antes
/// eram três widgets quase idênticos (`_Miniatura` em wardrobe_view,
/// `_PecaSelecionavel`/`_CardPeca` em montar_look_view).
///
/// Quando `onTap` é informado, o conteúdo fica dentro de um `InkWell` de
/// verdade — testes existentes que fazem `find.byType(InkWell)` continuam
/// funcionando sem ajuste.
class ClothingCard extends StatelessWidget {
  const ClothingCard({
    super.key,
    required this.imagemUrl,
    this.tamanho = 110,
    this.selecionavel = false,
    this.selecionada = false,
    this.incompleta = false,
    this.onTap,
  });

  final String imagemUrl;
  final double tamanho;

  /// Quando `true`, mostra o selo de seleção e a borda de destaque conforme
  /// [selecionada]. Quando `false`, o card é só ilustrativo (ex: miniatura
  /// dentro de um look salvo, sem interação).
  final bool selecionavel;
  final bool selecionada;

  /// Selo de "cadastro incompleto" (E5.F4.1). Só o armário liga; a montagem
  /// de look e as miniaturas de look não mostram.
  final bool incompleta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final conteudo = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
            border: selecionavel && selecionada
                ? Border.all(color: AppColors.sage, width: 3)
                : Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            AppConstants.resolveMediaUrl(imagemUrl),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
            ),
          ),
        ),
        if (selecionavel && selecionada)
          const Positioned(
            top: -6,
            right: -6,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.sage,
              child: Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
        if (incompleta)
          Positioned(
            left: 6,
            bottom: 6,
            child: Tooltip(
              key: const ValueKey('selo-cadastro-incompleto'),
              message: 'Cadastro incompleto',
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.orange.shade700,
                child: const Icon(Icons.priority_high, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return conteudo;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: conteudo);
  }
}
