import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../models/peca.dart';
import '../../services/peca_service.dart';
import '../looks/looks_controller.dart';
import '../preferences/preferences_controller.dart'
    show evitadasProvider, mensagemDeErroEvitadas, preferenciaServiceProvider;
import '../suggestions/suggestions_view.dart';
import '../upload/peca_form_view.dart';
import '../upload/upload_controller.dart' show pecaServiceProvider;
import 'wardrobe_controller.dart';

/// Detalhe de uma peça do armário (E1.F3.1): imagem + metadados em modo
/// leitura, com opções de editar (reaproveita [PecaFormView]) e excluir, e de
/// evitar a peça nas sugestões (E4.F4.2).
class PecaDetailView extends ConsumerStatefulWidget {
  const PecaDetailView({super.key, required this.peca});

  final Peca peca;

  @override
  ConsumerState<PecaDetailView> createState() => _PecaDetailViewState();
}

class _PecaDetailViewState extends ConsumerState<PecaDetailView> {
  bool _excluindo = false;
  bool _alternandoEvitada = false;

  /// Marca ou desmarca a peça como evitada nas sugestões (E4.F4.2).
  Future<void> _alternarEvitada(bool evitadaAgora) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _alternandoEvitada = true);
    try {
      final service = ref.read(preferenciaServiceProvider);
      if (evitadaAgora) {
        await service.pararDeEvitarPeca(widget.peca.id);
      } else {
        await service.evitarPeca(widget.peca.id);
      }
      ref.invalidate(evitadasProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(evitadaAgora
            ? 'A peça voltou a poder aparecer nas sugestões.'
            : 'Peça marcada para não aparecer nas sugestões.'),
      ));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroEvitadas(error, 'atualizar a peça'))),
      );
    } finally {
      if (mounted) setState(() => _alternandoEvitada = false);
    }
  }

  /// Abre as sugestões com esta peça fixa (E5.F2.2), empilhadas — não troca a aba.
  void _montarLooks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SuggestionsView(pecaBase: widget.peca)),
    );
  }

  void _editar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PecaFormView(
          imagemUrl: widget.peca.imagemUrl,
          pecaExistente: widget.peca,
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir peça?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    await _excluir(removerDosLooks: false);
  }

  Future<void> _excluir({required bool removerDosLooks}) async {
    setState(() => _excluindo = true);
    try {
      await ref
          .read(pecaServiceProvider)
          .excluirPeca(widget.peca.id, removerDosLooks: removerDosLooks);
      ref.invalidate(pecaListProvider);
      // Os looks que usavam a peça mudaram.
      ref.invalidate(lookListProvider);
      // O backend apaga em cascata a peça das evitadas (E4.F4.1).
      ref.invalidate(evitadasProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _excluindo = false);
      final emLooks = PecaService.quantidadeDeLooksDoConflito(e);
      if (emLooks != null) {
        await _confirmarRemocaoDosLooks(emLooks);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensagemDeErro(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _excluindo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir a peça. Tente novamente.')),
      );
    }
  }

  /// A peça está em looks salvos: só segue depois de o usuário aceitar que
  /// ela saia deles (os looks continuam existindo, sem essa peça).
  Future<void> _confirmarRemocaoDosLooks(int quantidade) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Peça usada em looks'),
        content: Text(
          quantidade == 1
              ? 'Esta peça está em 1 look. Ao excluir, ela será removida desse look, '
                  'que continuará salvo sem ela. Essa ação não pode ser desfeita.'
              : 'Esta peça está em $quantidade looks. Ao excluir, ela será removida '
                  'desses looks, que continuarão salvos sem ela. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir mesmo assim'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    await _excluir(removerDosLooks: true);
  }

  String _mensagemDeErro(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível excluir a peça.';
    }
    return 'Não foi possível excluir a peça. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final peca = widget.peca;
    // Carregando ou com erro vira "não evitada": a ação continua funcionando
    // (marcar é idempotente no backend).
    final evitada =
        ref.watch(evitadasProvider).valueOrNull?.contemPeca(peca.id) ?? false;
    final ocupado = _excluindo || _alternandoEvitada;
    final faltando = camposIncompletos(peca);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe da peça'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: ocupado ? null : _editar,
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: _excluindo
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: ocupado ? null : _confirmarExclusao,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (faltando.isNotEmpty) ...[
            _AvisoIncompleta(faltando: faltando, onEditar: ocupado ? null : _editar),
            const SizedBox(height: 16),
          ],
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              AppConstants.resolveMediaUrl(peca.imagemUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          ),
          if (evitada) ...[
            const SizedBox(height: 16),
            const _AvisoEvitada(),
          ],
          const SizedBox(height: 24),
          _CampoDetalhe(label: 'Categoria', valor: peca.categoria),
          _CampoDetalhe(label: 'Subcategoria', valor: peca.subcategoria),
          _CampoDetalhe(label: 'Cor principal', valor: peca.corPrincipal),
          _CampoDetalhe(label: 'Outras cores', valor: peca.coresSecundarias.join(', ')),
          _CampoDetalhe(label: 'Tonalidade da cor', valor: peca.tonalidadeCor),
          _CampoDetalhe(label: 'Estações', valor: peca.estacoes.join(', ')),
          _CampoDetalhe(label: 'Estilos', valor: peca.estilos.join(', ')),
          _CampoDetalhe(label: 'Modelagem', valor: peca.modelagem),
          _CampoDetalhe(label: 'Ocasiões', valor: peca.ocasioes.join(', ')),
          const SizedBox(height: 24),
          // Acessórios não entram nos looks sugeridos (regras-sugestoes.md).
          if (peca.categoria != 'Acessórios') ...[
            AppButton(
              label: 'Montar looks com esta peça',
              icon: Icons.auto_awesome,
              onPressed: ocupado ? null : _montarLooks,
            ),
            const SizedBox(height: 12),
          ],
          // Antes era só um ícone na barra (círculo cortado), difícil de
          // entender sem a dica do toque longo.
          AppButton(
            label: evitada ? 'Parar de evitar' : 'Evitar nas sugestões',
            icon: evitada ? Icons.do_not_disturb_on : Icons.do_not_disturb_on_outlined,
            variant: AppButtonVariant.secondary,
            loading: _alternandoEvitada,
            onPressed: ocupado ? null : () => _alternarEvitada(evitada),
          ),
        ],
      ),
    );
  }
}

class _CampoDetalhe extends StatelessWidget {
  const _CampoDetalhe({required this.label, required this.valor});

  final String label;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(
            flex: 2,
            child: Text(valor == null || valor!.isEmpty ? '—' : valor!),
          ),
        ],
      ),
    );
  }
}

/// Faixa "Cadastro incompleto: sem cor, estilo" (E5.F4.1), com atalho para a
/// edição já existente. Peças assim entram nas sugestões só como coringa.
class _AvisoIncompleta extends StatelessWidget {
  const _AvisoIncompleta({required this.faltando, required this.onEditar});

  final List<String> faltando;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    final cor = Colors.orange.shade900;
    return Container(
      key: const ValueKey('faixa-cadastro-incompleto'),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cadastro incompleto: sem ${faltando.join(', ')}',
                  style: TextStyle(color: cor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete para a peça aparecer melhor nas sugestões.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEditar, child: const Text('Editar')),
        ],
      ),
    );
  }
}

class _AvisoEvitada extends StatelessWidget {
  const _AvisoEvitada();

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cores.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.do_not_disturb_on, color: cores.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Evitada nas sugestões',
              style: TextStyle(color: cores.onErrorContainer, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
