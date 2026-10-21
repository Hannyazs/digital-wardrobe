import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart';
import '../../models/preferencia.dart';
import 'preferences_controller.dart';
import 'widgets/secao_combinacoes_evitadas.dart';
import 'widgets/secao_cores_favoritas.dart';
import 'widgets/secao_criatividade.dart';
import 'widgets/secao_de_chips.dart';
import 'widgets/secao_pecas_evitadas.dart';

/// Configuração de preferências de estilo (MVP #6): cores favoritas,
/// sobreposições, estilos preferidos, peças a evitar, nível de criatividade.
/// Cada seção entra numa PBI própria do Épico 4: estilos (E4.F3.1), cores
/// (E4.F1.2), sobreposições (E4.F2.1), criatividade (E4.F5.1), peças
/// evitadas (E4.F4.2) e combinações evitadas (E4.F4.3). Estilos vêm primeiro: é a preferência
/// central da história do épico ("combinar com meu gosto pessoal").
/// Alterações são salvas na hora, sem botão "Salvar".
class PreferencesView extends ConsumerWidget {
  const PreferencesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferenciasAsync = ref.watch(preferenciasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de Estilo')),
      body: preferenciasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Erro(
          mensagem: mensagemDeErroAoCarregar(error),
          onTentarNovamente: () => ref.invalidate(preferenciasProvider),
        ),
        data: (preferencia) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SecaoDeChips(
              titulo: 'Estilos preferidos',
              apoio: 'Marque quantos quiser. Nenhum marcado = sem preferência.',
              opcoes: estilosFixos,
              selecionadas: preferencia.estilos,
              onAlternar: (opcao) => _alternar(
                context,
                ref,
                campo: 'estilos',
                opcao: opcao,
                ordem: estilosFixos,
                ler: (p) => p.estilos,
                aplicar: (p, lista) => p.copyWith(estilos: lista),
              ),
            ),
            SecaoCoresFavoritas(combinacoes: preferencia.combinacoesCores),
            SecaoDeChips(
              titulo: 'Sobreposições',
              apoio: 'Camadas que você gosta de usar. Nenhuma marcada = sem preferência.',
              opcoes: sobreposicoesFixas,
              selecionadas: preferencia.sobreposicoes,
              onAlternar: (opcao) => _alternar(
                context,
                ref,
                campo: 'sobreposicoes',
                opcao: opcao,
                ordem: sobreposicoesFixas,
                ler: (p) => p.sobreposicoes,
                aplicar: (p, lista) => p.copyWith(sobreposicoes: lista),
              ),
            ),
            SecaoCriatividade(
              nivel: preferencia.criatividade,
              onSalvar: (nivel) => _salvarCriatividade(context, ref, nivel),
            ),
            const SecaoPecasEvitadas(),
            const SecaoCombinacoesEvitadas(),
          ],
        ),
      ),
    );
  }

  /// Marca/desmarca [opcao] num campo de lista ([campo], lido com [ler] e
  /// gravado com [aplicar]) e salva. Parte do estado **atual** do controller
  /// (já com mudanças otimistas anteriores), não do capturado no build, para
  /// dois toques seguidos não perderem o primeiro.
  /// Devolve `true` se gravou (a seção usa isso para desfazer o arrasto em falha).
  Future<bool> _salvarCriatividade(BuildContext context, WidgetRef ref, int nivel) async {
    final messenger = ScaffoldMessenger.of(context);
    final erro = await ref.read(preferenciasProvider.notifier).atualizar(
      {'criatividade': nivel},
      (p) => p.copyWith(criatividade: nivel),
    );
    if (erro != null) messenger.showSnackBar(SnackBar(content: Text(erro)));
    return erro == null;
  }

  Future<void> _alternar(
    BuildContext context,
    WidgetRef ref, {
    required String campo,
    required String opcao,
    required List<String> ordem,
    required List<String> Function(Preferencia) ler,
    required Preferencia Function(Preferencia, List<String>) aplicar,
  }) async {
    final atual = ref.read(preferenciasProvider).valueOrNull;
    if (atual == null) return;
    final nova = alternarNaLista(ler(atual), opcao, ordem);
    final messenger = ScaffoldMessenger.of(context);
    final erro = await ref.read(preferenciasProvider.notifier).atualizar(
      {campo: nova},
      (p) => aplicar(p, nova),
    );
    if (erro != null) messenger.showSnackBar(SnackBar(content: Text(erro)));
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTentarNovamente,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
