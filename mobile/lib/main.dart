import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'views/wardrobe/wardrobe_view.dart';

void main() {
  runApp(const ProviderScope(child: GuardaRoupaApp()));
}

class GuardaRoupaApp extends StatelessWidget {
  const GuardaRoupaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guarda-Roupa Virtual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WardrobeView(),
    );
  }
}
