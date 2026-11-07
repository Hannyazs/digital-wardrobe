import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/peca.dart';
import '../../../models/peca_parada.dart';
import '../../suggestions/suggestions_view.dart';
import '../../upload/upload_controller.dart' show pecaServiceProvider;
import '../../wardrobe/acoes_da_peca.dart';

/// Abre o aviso de peça parada (E13.F1.2). Fechar sem escolher (toque fora,
/// voltar) não adia nada: a peça volta na próxima abertura do app.
Future<void> mostrarDialogoPecaParada(BuildContext context, PecaParada parada) {
  return showDialog<void>(
    context: context,
    builder: (_) => DialogoPecaParada(parada: parada),
  );
}

/// "Você não usa esta peça há N dias", com três escolhas: doar (exclui do app,
/// E13.F1.3), sugerir looks com ela (E13.F1.3) e lembrar depois (30 dias).
class DialogoPecaParada extends ConsumerStatefulWidget {
  const DialogoPecaParada({super.key, required this.parada});

  final PecaParada parada;

  @override
  ConsumerState<DialogoPecaParada> createState() => _DialogoPecaParadaState();
}

class _DialogoPecaParadaState extends ConsumerState<DialogoPecaParada> {
  bool _excluindo = false;
  bool _adiando = false;

  bool get _ocupado => _excluindo || _adiando;

  Peca get _peca => widget.parada.peca;

  String get _mensagem => widget.parada.ultimoUso == null
      ? 'Você ainda não usou esta peça.'
      : 'Você não usa esta peça há ${widget.parada.diasParada} dias.';

  /// Doar = excluir do app, de forma definitiva (decisão de 2026-11-06). Se a
  /// confirmação for cancelada, o aviso continua aberto.
  Future<void> _doar() async {
    final excluiu = await confirmarEExcluirPeca(
      context,
      ref,
      _peca,
      titulo: 'Doar e remover do app?',
      mensagem: 'A peça sai do seu armário no app. Essa ação não pode ser desfeita.',
      confirmar: 'Remover do app',
      aoMudarOcupado: (ocupado) {
        if (mounted) setState(() => _excluindo = ocupado);
      },
    );
    if (excluiu && mounted) Navigator.of(context).pop();
  }

  /// Abre as sugestões com a peça fixa (E5.F2.2). Não adia o lembrete: a peça
  /// continua parada até ser de fato usada.
  void _sugerirLook() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => SuggestionsView(pecaBase: _peca)),
    );
  }

  Future<void> _lembrarDepois() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adiando = true);
    try {
      await ref.read(pecaServiceProvider).adiarLembrete(_peca.id, hoje: DateTime.now());
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Não foi possível adiar o lembrete. A peça pode aparecer de novo.'),
      ));
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final descricao = descricaoPeca(_peca);
    // Acessórios não entram nos looks sugeridos (regras-sugestoes.md), como no detalhe.
    final podeSugerir = _peca.categoria != 'Acessórios';
    const tamanhoMinimo = Size.fromHeight(48);

    return AlertDialog(
      title: const Text('Peça parada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              image: true,
              label: 'Foto da peça: $descricao',
              child: ExcludeSemantics(
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    AppConstants.resolveMediaUrl(_peca.imagemUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(descricao, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_mensagem),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: tamanhoMinimo),
              onPressed: _ocupado ? null : _doar,
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Doar a peça'),
            ),
            if (podeSugerir) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: tamanhoMinimo),
                onPressed: _ocupado ? null : _sugerirLook,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Sugerir look com ela'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: tamanhoMinimo),
              onPressed: _ocupado ? null : _lembrarDepois,
              child: _adiando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lembrar depois'),
            ),
          ],
        ),
      ),
    );
  }
}
