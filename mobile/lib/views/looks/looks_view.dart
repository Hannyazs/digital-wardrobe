import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/look.dart';
import 'looks_controller.dart';
import 'montar_look_view.dart';

/// Listagem dos looks salvos (E3.F1.3). Tocar num look não faz nada ainda
/// — detalhe/edição é uma PBI futura, sem endpoint próprio hoje.
class LooksView extends ConsumerWidget {
  const LooksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final looksAsync = ref.watch(lookListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Looks')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lookListProvider);
          await ref.read(lookListProvider.future);
        },
        child: looksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Erro(
            mensagem: _mensagemDeErro(error),
            onTentarNovamente: () => ref.invalidate(lookListProvider),
          ),
          data: (looks) => looks.isEmpty ? const _SemLooks() : _ListaDeLooks(looks: looks),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // `HomeShell` mantém Armário e Looks montados ao mesmo tempo
        // (`IndexedStack`) — sem uma hero tag própria, este FAB colide com o
        // de `WardrobeView` (mesma tag padrão em todo `FloatingActionButton`).
        heroTag: 'looks-montar-look-fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MontarLookView()),
          );
        },
        icon: const Icon(Icons.checkroom),
        label: const Text('Montar look'),
      ),
    );
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Sessão expirada ou inválida. Não foi possível carregar seus looks.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
        case DioExceptionType.connectionError:
          return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
        default:
          return 'Não foi possível carregar seus looks. Tente novamente.';
      }
    }
    return 'Não foi possível carregar seus looks. Tente novamente.';
  }
}

class _ListaDeLooks extends StatelessWidget {
  const _ListaDeLooks({required this.looks});

  final List<Look> looks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: looks.length,
      itemBuilder: (context, index) => _LookCard(look: looks[index]),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({required this.look});

  final Look look;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              look.nome,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (final peca in look.pecas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Só ilustrativa — sem InkWell/ripple: tocar aqui não
                        // leva a lugar nenhum ainda (sem detalhe de peça
                        // dentro do contexto de um look).
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SemLooks extends StatelessWidget {
  const _SemLooks();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_outlined, size: 64),
                SizedBox(height: 16),
                Text('Você ainda não tem nenhum look salvo'),
                SizedBox(height: 8),
                Text('Toque em "Montar look" para criar o primeiro'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 400,
          child: Center(
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
        ),
      ],
    );
  }
}
