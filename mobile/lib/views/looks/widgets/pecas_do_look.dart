import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/peca.dart';

/// Fileira de miniaturas das peças de um look. Compartilhada entre o card da
/// lista de looks, o histórico (E3.F4.3) e o card "Look do dia".
///
/// Por padrão cada miniatura tem 64 px e a fileira rola se não couber. Com
/// [ajustarALargura] as miniaturas encolhem (até 40 px) para todas caberem
/// numa única linha sem rolagem, mantendo o formato quadrado.
class PecasDoLook extends StatelessWidget {
  const PecasDoLook({super.key, required this.pecas, this.ajustarALargura = false});

  final List<Peca> pecas;
  final bool ajustarALargura;

  static const _tamanhoPadrao = 64.0;
  static const _tamanhoMinimo = 40.0;
  static const _espaco = 8.0;

  @override
  Widget build(BuildContext context) {
    // Uma frase para o leitor de tela no lugar de várias fotos sem nome.
    return Semantics(
      label: 'Peças: ${pecas.map(descricaoPeca).join('; ')}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, restricoes) {
            var tamanho = _tamanhoPadrao;
            if (ajustarALargura && pecas.isNotEmpty && restricoes.maxWidth.isFinite) {
              final cabe = (restricoes.maxWidth - (pecas.length - 1) * _espaco) / pecas.length;
              tamanho = cabe.clamp(_tamanhoMinimo, _tamanhoPadrao);
            }
            return SizedBox(
              height: tamanho,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final peca in pecas)
                    Padding(
                      padding: const EdgeInsets.only(right: _espaco),
                      child: Container(
                        width: tamanho,
                        height: tamanho,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Só ilustrativa — sem InkWell/ripple: tocar aqui não leva a
                        // lugar nenhum ainda (sem detalhe de peça dentro de um look).
                        child: Image.network(
                          AppConstants.resolveMediaUrl(peca.imagemUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
