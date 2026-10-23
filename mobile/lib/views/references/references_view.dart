import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_header.dart';

/// Placeholder da área de referências visuais (redesign visual, Etapa 4).
/// Sem upload/importação real ainda — só a interface.
class ReferencesView extends StatelessWidget {
  const ReferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          ScreenHeader(
            titulo: 'Inspirações',
            subtitulo: 'Em breve',
          ),
          Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.image_outlined, size: 56, color: AppColors.sage),
                SizedBox(height: 16),
                Text(
                  'Em breve, você vai poder importar fotos de looks que quer recriar.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
