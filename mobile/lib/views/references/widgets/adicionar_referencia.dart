import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/colecao.dart';
import '../references_controller.dart';
import 'dialogo_de_nota.dart';

/// Fluxo de adicionar uma referência pela galeria (usado no mural e nas grades
/// de cada coleção): escolhe a foto, pede nota e coleção, envia e mostra o
/// erro, se houver. [colecaoInicial] vem pré-selecionada no diálogo.
///
/// Usa o `ProviderContainer` em vez de um `WidgetRef`: se a tela for fechada
/// durante o envio, o `ref` dela já não vale, mas o container sim.
Future<void> adicionarReferencia(BuildContext context,
    {String? colecaoInicial}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final foto = await container.read(galeriaProvider)();
    if (foto == null || !context.mounted) return;

    // Sem as coleções carregadas o diálogo só oferece "Sem coleção".
    List<Colecao> colecoes;
    try {
      colecoes = await container.read(colecoesProvider.future);
    } catch (_) {
      colecoes = const [];
    }
    if (!context.mounted) return;

    final dados = await pedirDadosDaNovaReferencia(
      context,
      colecoes: colecoes,
      colecaoInicial: colecaoInicial,
    );
    if (dados == null) return;

    container.read(enviandoReferenciaProvider.notifier).state = true;
    await container
        .read(referenciasProvider.notifier)
        .adicionar(foto, nota: dados.nota, colecaoId: dados.colecaoId);
  } catch (erro) {
    messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroDaReferencia(erro))));
  } finally {
    container.read(enviandoReferenciaProvider.notifier).state = false;
  }
}
