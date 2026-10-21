import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/peca.dart';

/// Fileira de miniaturas das peças de um look. Compartilhada entre o card da
/// lista de looks e o histórico (E3.F4.3).
class PecasDoLook extends StatelessWidget {
  const PecasDoLook({super.key, required this.pecas});

  final List<Peca> pecas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (final peca in pecas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 64,
                height: 64,
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
  }
}
