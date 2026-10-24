import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'references_controller.dart';
import 'widgets/botao_adicionar_referencia.dart';
import 'widgets/grade_de_referencias.dart';
import 'widgets/referencia_detalhe.dart';

/// Grade com as referências de uma coleção (E8.F2.2), ou as sem coleção
/// quando [colecaoId] é `null`. Filtra a lista já carregada do mural, então
/// acompanha adições, movimentações e exclusões na hora.
class ColecaoGradeView extends ConsumerWidget {
  const ColecaoGradeView({super.key, required this.colecaoId});

  final String? colecaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nome = colecaoId == null
        ? 'Sem coleção'
        : ref
                .watch(colecoesProvider)
                .valueOrNull
                ?.where((c) => c.id == colecaoId)
                .firstOrNull
                ?.nome ??
            'Coleção';
    final referencias = ref
            .watch(referenciasProvider)
            .valueOrNull
            ?.where((r) => r.colecaoId == colecaoId)
            .toList() ??
        const [];

    return Scaffold(
      appBar: AppBar(title: Text(nome)),
      floatingActionButton: BotaoAdicionarReferencia(colecaoInicial: colecaoId),
      body: referencias.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.image_outlined, size: 56, color: AppColors.sage),
                  SizedBox(height: 16),
                  Text('Nenhuma referência aqui ainda.',
                      textAlign: TextAlign.center),
                ],
              ),
            )
          : SingleChildScrollView(
              child: GradeDeReferencias(
                referencias: referencias,
                onAbrir: (referencia) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => ReferenciaDetalhe(id: referencia.id)),
                ),
              ),
            ),
    );
  }
}
