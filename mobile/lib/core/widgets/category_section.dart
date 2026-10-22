import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Seção de categoria: label + carrossel horizontal de itens. Mesmo formato
/// usado no armário, nas gavetas e na montagem de look (ver
/// docs/redesign-visual.md) — espelha os carrosséis por categoria do Figma.
///
/// Depois dos itens vêm espaços vazios (cards brancos esmaecidos) até passar
/// da largura da tela: mesmo com uma ou duas peças a fileira continua com
/// cara de carrossel, sugerindo que há espaço para percorrer.
class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.titulo,
    required this.itemCount,
    required this.itemBuilder,
    this.contagem,
    this.altura = 120,
    this.larguraItem = 110,
    this.onTap,
  });

  final String titulo;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Quando informado, aparece como "`titulo` (`contagem`)" — usado no
  /// armário, que já mostrava a quantidade de peças por categoria.
  final int? contagem;
  final double altura;

  /// Largura de cada item (a do `ClothingCard`): base do cálculo dos espaços vazios.
  final double larguraItem;

  /// Quando informado, o título vira um link (com seta) — ex.: abrir a gaveta.
  final VoidCallback? onTap;

  static const _espaco = 10.0;
  static const _margem = 20.0;

  /// Quantos espaços vazios cabem depois dos itens até a fileira passar da
  /// tela em meio card. Pelo menos um, mesmo quando os itens já transbordam.
  int _espacosVazios(double larguraTela) {
    final ocupado = _margem + itemCount * (larguraItem + _espaco);
    final faltando = larguraTela + larguraItem / 2 - ocupado;
    if (faltando <= 0) return 1;
    return (faltando / (larguraItem + _espaco)).ceil().clamp(1, 6);
  }

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(
      contagem == null ? titulo : '$titulo ($contagem)',
      style: AppTextStyles.labelCategoria(),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onTap == null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: _margem), child: rotulo)
          else
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_margem, 4, 12, 4),
                child: Row(
                  children: [
                    Expanded(child: rotulo),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: altura,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vazios = _espacosVazios(constraints.maxWidth);
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: _margem),
                  itemCount: itemCount + vazios,
                  separatorBuilder: (context, index) => const SizedBox(width: _espaco),
                  itemBuilder: (context, index) => index < itemCount
                      ? itemBuilder(context, index)
                      : _EspacoVazio(
                          largura: larguraItem,
                          // Cada espaço seguinte um pouco mais apagado.
                          opacidade: (0.9 - (index - itemCount) * 0.25).clamp(0.25, 0.9),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EspacoVazio extends StatelessWidget {
  const _EspacoVazio({required this.largura, required this.opacidade});

  final double largura;
  final double opacidade;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Opacity(
        key: const ValueKey('carrossel-espaco-vazio'),
        opacity: opacidade,
        child: Container(
          width: largura,
          height: largura,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ),
      ),
    );
  }
}
