import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/peca.dart';
import '../upload/upload_view.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'looks_controller.dart';
import 'montar_look_controller.dart';

/// Tela de montagem manual de um look (E3.F1.2): seleciona peças do
/// armário, nomeia e confirma. Ao salvar, invalida `lookListProvider`
/// (E3.F1.3) pra "Looks" já mostrar o look novo ao voltar.
class MontarLookView extends ConsumerStatefulWidget {
  const MontarLookView({super.key});

  @override
  ConsumerState<MontarLookView> createState() => _MontarLookViewState();
}

class _MontarLookViewState extends ConsumerState<MontarLookView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nomeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _salvar() {
    final selecao = ref.read(selecaoLookProvider);
    if (!_formKey.currentState!.validate() || selecao.isEmpty) return;
    ref.read(montagemLookProvider.notifier).salvar(
          nome: _nomeController.text.trim(),
          pecaIds: selecao,
        );
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(pecaListProvider);
    final selecao = ref.watch(selecaoLookProvider);
    final montagemState = ref.watch(montagemLookProvider);
    final enviando = montagemState is MontagemEnviando;
    final podeConfirmar =
        !enviando && _nomeController.text.trim().isNotEmpty && selecao.isNotEmpty;

    ref.listen<MontagemLookState>(montagemLookProvider, (previous, next) {
      if (next is MontagemSucesso) {
        ref.invalidate(lookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Look "${next.look.nome}" salvo.')),
        );
        Navigator.of(context).pop();
      } else if (next is MontagemErro) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.mensagem)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Montar look')),
      body: pecasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Erro(
          mensagem: _mensagemDeErro(error),
          onTentarNovamente: () => ref.invalidate(pecaListProvider),
        ),
        data: (pecas) => pecas.isEmpty ? const _ArmarioVazio() : _buildFormulario(pecas, selecao, enviando),
      ),
      bottomNavigationBar: pecasAsync.maybeWhen(
        data: (pecas) => pecas.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: podeConfirmar ? _salvar : null,
                  child: enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar look'),
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildFormulario(List<Peca> pecas, Set<String> selecao, bool enviando) {
    final grupos = agruparPorCategoria(pecas);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _nomeController,
              enabled: !enviando,
              decoration: const InputDecoration(labelText: 'Nome do look *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Dê um nome ao look' : null,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final entry in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 110,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final peca = entry.value[index];
                      return _PecaSelecionavel(
                        peca: peca,
                        selecionada: selecao.contains(peca.id),
                        onToggle: enviando
                            ? null
                            : () {
                                final notifier = ref.read(selecaoLookProvider.notifier);
                                final novaSelecao = {...notifier.state};
                                if (novaSelecao.contains(peca.id)) {
                                  novaSelecao.remove(peca.id);
                                } else {
                                  novaSelecao.add(peca.id);
                                }
                                notifier.state = novaSelecao;
                              },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException && error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível carregar seu armário.';
    }
    return 'Não foi possível carregar seu armário. Tente novamente.';
  }
}

class _PecaSelecionavel extends StatelessWidget {
  const _PecaSelecionavel({
    required this.peca,
    required this.selecionada,
    required this.onToggle,
  });

  final Peca peca;
  final bool selecionada;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onToggle,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: selecionada
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                  : null,
            ),
            child: Image.network(
              AppConstants.resolveMediaUrl(peca.imagemUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          if (selecionada)
            Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArmarioVazio extends StatelessWidget {
  const _ArmarioVazio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Cadastre uma peça antes de montar um look',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UploadView()),
              ),
              child: const Text('Cadastrar peça'),
            ),
          ],
        ),
      ),
    );
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
            ElevatedButton(onPressed: onTentarNovamente, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
