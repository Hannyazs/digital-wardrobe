import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_header.dart';

/// Placeholder da área de sugestões por IA (redesign visual, Etapa 4).
/// Sem IA implementada ainda — só a interface, deixando claro que é aqui
/// que as recomendações automáticas vão aparecer no futuro (Épicos 5-7).
class SuggestionsView extends StatelessWidget {
  const SuggestionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          ScreenHeader(
            titulo: 'Your suggestions',
            subtitulo: "Let's find a look for you.",
          ),
          Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 56, color: AppColors.sage),
                SizedBox(height: 16),
                Text(
                  'Em breve, looks sugeridos especialmente pra você vão aparecer aqui.',
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
