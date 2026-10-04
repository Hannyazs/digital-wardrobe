import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/peca.dart';
import '../upload/peca_form_view.dart';
import '../upload/upload_controller.dart' show pecaServiceProvider;
import 'wardrobe_controller.dart';

/// Detalhe de uma peça do armário (E1.F3.1): imagem + metadados em modo
/// leitura, com opções de editar (reaproveita [PecaFormView]) e excluir.
class PecaDetailView extends ConsumerStatefulWidget {
  const PecaDetailView({super.key, required this.peca});

  final Peca peca;

  @override
  ConsumerState<PecaDetailView> createState() => _PecaDetailViewState();
}

class _PecaDetailViewState extends ConsumerState<PecaDetailView> {
  bool _excluindo = false;

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

    setState(() => _excluindo = true);
    try {
      await ref.read(pecaServiceProvider).excluirPeca(widget.peca.id);
      ref.invalidate(pecaListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _excluindo = false);
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

  String _mensagemDeErro(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível excluir a peça.';
    }
    return 'Não foi possível excluir a peça. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final peca = widget.peca;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe da peça'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: _excluindo ? null : _editar,
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
            onPressed: _excluindo ? null : _confirmarExclusao,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 240,
            child: Image.network(
              AppConstants.resolveMediaUrl(peca.imagemUrl),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 64),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _CampoDetalhe(label: 'Categoria', valor: peca.categoria),
          _CampoDetalhe(label: 'Subcategoria', valor: peca.subcategoria),
          _CampoDetalhe(label: 'Cor principal', valor: peca.corPrincipal),
          _CampoDetalhe(label: 'Estação', valor: peca.estacao),
          _CampoDetalhe(label: 'Ocasião', valor: peca.ocasiao),
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
