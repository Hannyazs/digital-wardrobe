import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/referencia.dart';

/// Grade em duas colunas no estilo mural: cada imagem mantém a própria
/// proporção, então as colunas ficam com alturas diferentes. Os itens se
/// alternam entre as colunas (mais recente à esquerda, a seguinte à direita…).
/// Montada com `Column`s para não depender de pacote de grade.
class GradeDeReferencias extends StatelessWidget {
  const GradeDeReferencias(
      {super.key, required this.referencias, required this.onAbrir});

  final List<Referencia> referencias;
  final void Function(Referencia referencia) onAbrir;

  @override
  Widget build(BuildContext context) {
    final esquerda = <Referencia>[];
    final direita = <Referencia>[];
    for (var i = 0; i < referencias.length; i++) {
      (i.isEven ? esquerda : direita).add(referencias[i]);
    }

    Widget coluna(List<Referencia> itens, {required bool ladoEsquerdo}) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(
              left: ladoEsquerdo ? 0 : 6, right: ladoEsquerdo ? 6 : 0),
          child: Column(
            children: [
              for (final referencia in itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CartaoDeReferencia(
                      referencia: referencia, onTap: () => onAbrir(referencia)),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          coluna(esquerda, ladoEsquerdo: true),
          coluna(direita, ladoEsquerdo: false),
        ],
      ),
    );
  }
}

class CartaoDeReferencia extends StatelessWidget {
  const CartaoDeReferencia(
      {super.key, required this.referencia, required this.onTap});

  final Referencia referencia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nota = referencia.nota;
    return Semantics(
      button: true,
      image: true,
      label: [
        nota == null ? 'Referência' : 'Referência: $nota',
        if (referencia.look != null) 'ligada ao look ${referencia.look!.nome}',
      ].join(', '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: AppColors.backgroundSecondary,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Image.network(
                  AppConstants.resolveMediaUrl(referencia.imagemUrl),
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  loadingBuilder: (context, child, progresso) => progresso == null
                      ? child
                      : const SizedBox(
                          height: 180,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                  errorBuilder: (context, erro, stack) => const SizedBox(
                    height: 180,
                    child:
                        Center(child: Icon(Icons.broken_image_outlined, size: 40)),
                  ),
                ),
                if (referencia.look != null) const _SeloDeLook(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo no canto da imagem: a referência está ligada a um look salvo.
class _SeloDeLook extends StatelessWidget {
  const _SeloDeLook();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 8,
      bottom: 8,
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.navBar,
          child: Icon(Icons.checkroom, size: 16, color: AppColors.white),
        ),
      ),
    );
  }
}
