import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Seção de categoria: label + carrossel horizontal de itens. Mesmo formato
/// usado no armário e na montagem de look (ver docs/redesign-visual.md) —
/// espelha os carrosséis por categoria do Figma de referência.
class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.titulo,
    required this.itemCount,
    required this.itemBuilder,
    this.contagem,
    this.altura = 120,
  });

  final String titulo;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Quando informado, aparece como "`titulo` (`contagem`)" — usado no
  /// armário, que já mostrava a quantidade de peças por categoria.
  final int? contagem;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              contagem == null ? titulo : '$titulo ($contagem)',
              style: AppTextStyles.labelCategoria(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: altura,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: itemCount,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
