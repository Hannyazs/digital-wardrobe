import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../models/look.dart';
import '../../../models/referencia.dart';
import '../../looks/looks_controller.dart' show lookListProvider;
import '../../looks/widgets/pecas_do_look.dart';
import '../references_controller.dart';
import '../sugestao_de_look_view.dart';

/// Bloco "Look" do detalhe da referência (E8.F3.1): mostra o look salvo ao
/// qual ela está ligada (nome e peças) e permite ligar, trocar ou desligar.
class LookDaReferencia extends ConsumerWidget {
  const LookDaReferencia({super.key, required this.referencia});

  final Referencia referencia;

  Future<void> _ligar(BuildContext context, WidgetRef ref, String? lookId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(referenciasProvider.notifier).ligarLook(referencia.id, lookId);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErroDaReferencia(erro, acao: lookId == null ? 'desligar o look da' : 'ligar o look à'),
          ),
        ),
      );
    }
  }

  /// "Ligar a um look" / "Trocar look": primeiro a forma (manual ou automática).
  Future<void> _escolherAForma(BuildContext context, WidgetRef ref) async {
    final temEtiquetas = referencia.etiquetas.isNotEmpty;
    final forma = await showModalBottomSheet<_FormaDeLigar>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.touch_app_outlined),
              title: const Text('Manual'),
              subtitle: const Text('Escolher um look que você já salvou'),
              onTap: () => Navigator.of(sheet).pop(_FormaDeLigar.manual),
            ),
            ListTile(
              enabled: temEtiquetas,
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Automático (IA)'),
              subtitle: Text(
                temEtiquetas
                    ? 'A IA compara a imagem com as suas peças e sugere um look'
                    : 'Adicione as etiquetas das peças da imagem primeiro',
              ),
              onTap: temEtiquetas ? () => Navigator.of(sheet).pop(_FormaDeLigar.automatico) : null,
            ),
          ],
        ),
      ),
    );
    if (forma == null || !context.mounted) return;
    if (forma == _FormaDeLigar.manual) {
      await _escolherManualmente(context, ref);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SugestaoDeLookView(
            referenciaId: referencia.id,
            aoEscolherManualmente: () {
              if (context.mounted) _escolherManualmente(context, ref);
            },
          ),
        ),
      );
    }
  }

  Future<void> _escolherManualmente(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    List<Look> looks;
    try {
      looks = await ref.read(lookListProvider.future);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar seus looks. Tente novamente.')),
      );
      return;
    }
    if (!context.mounted) return;

    if (looks.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Nenhum look salvo'),
          content: const Text('Monte um look na aba Montar para poder ligá-lo a esta referência.'),
          actions: [
            FilledButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Entendi')),
          ],
        ),
      );
      return;
    }

    final escolhido = await showDialog<Look>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: const Text('Ligar a qual look?'),
        children: [
          for (final look in looks)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogo).pop(look),
              child: Text(look.nome),
            ),
        ],
      ),
    );
    if (escolhido == null || !context.mounted) return;
    await _ligar(context, ref, escolhido.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligado = referencia.look;
    if (ligado == null) {
      return AppButton(
        label: 'Ligar a um look',
        icon: Icons.checkroom_outlined,
        variant: AppButtonVariant.secondary,
        onPressed: () => _escolherAForma(context, ref),
      );
    }

    // As peças vêm da lista de looks; enquanto ela não chega, só o nome.
    final pecas = ref
        .watch(lookListProvider)
        .valueOrNull
        ?.where((look) => look.id == ligado.id)
        .firstOrNull
        ?.pecas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Look ligado', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(ligado.nome, style: Theme.of(context).textTheme.bodyLarge),
        if (pecas != null && pecas.isNotEmpty) ...[
          const SizedBox(height: 8),
          PecasDoLook(pecas: pecas),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Trocar look',
                variant: AppButtonVariant.secondary,
                onPressed: () => _escolherAForma(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Desligar',
                variant: AppButtonVariant.text,
                onPressed: () => _ligar(context, ref, null),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _FormaDeLigar { manual, automatico }
