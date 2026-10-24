import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../models/peca.dart';
import '../../models/referencia.dart';
import '../../models/sugestao_de_look.dart';
import '../looks/looks_controller.dart' show lookListProvider;
import '../looks/montar_look_controller.dart' show lookServiceProvider;
import '../looks/widgets/pecas_do_look.dart';
import 'references_controller.dart';

/// "Ligar a um look" no modo automático (E8.F5.3): a IA compara a referência
/// com as peças do usuário e propõe um look. Nada é salvo ou ligado sem o toque
/// do usuário; só aparecem peças do armário e as lacunas ficam à vista.
class SugestaoDeLookView extends ConsumerStatefulWidget {
  const SugestaoDeLookView({super.key, required this.referenciaId, this.aoEscolherManualmente});

  final String referenciaId;

  /// Chamado por "Escolher manualmente" (a tela se fecha antes).
  final VoidCallback? aoEscolherManualmente;

  @override
  ConsumerState<SugestaoDeLookView> createState() => _SugestaoDeLookViewState();
}

class _SugestaoDeLookViewState extends ConsumerState<SugestaoDeLookView> {
  bool _gravando = false;

  Referencia? get _referencia => ref
      .read(referenciasProvider)
      .valueOrNull
      ?.where((r) => r.id == widget.referenciaId)
      .firstOrNull;

  String _nomeSugerido() {
    final nota = _referencia?.nota?.trim();
    if (nota != null && nota.isNotEmpty) {
      return 'Inspirado em ${nota.length > 30 ? '${nota.substring(0, 30)}…' : nota}';
    }
    final hoje = DateTime.now();
    final dd = hoje.day.toString().padLeft(2, '0');
    final mm = hoje.month.toString().padLeft(2, '0');
    return 'Inspirado em uma referência – $dd/$mm';
  }

  Future<void> _ligarAoLookSalvo(String lookId) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _gravando = true);
    try {
      await ref.read(referenciasProvider.notifier).ligarLook(widget.referenciaId, lookId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Referência ligada ao look.')));
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroDaReferencia(erro, acao: 'ligar o look à'))),
      );
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  Future<void> _salvarELigar(SugestaoDeLook sugestao) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nome = await _pedirNome();
    if (nome == null || !mounted) return;

    setState(() => _gravando = true);
    String criadoId;
    try {
      final look = await ref
          .read(lookServiceProvider)
          .criarLook(nome: nome, pecaIds: [for (final p in sugestao.pecas) p.id]);
      criadoId = look.id;
      ref.invalidate(lookListProvider);
    } catch (erro) {
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErro(erro, padrao: 'Não foi possível salvar o look. Tente novamente.'))),
      );
      if (mounted) setState(() => _gravando = false);
      return;
    }
    try {
      await ref.read(referenciasProvider.notifier).ligarLook(widget.referenciaId, criadoId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Look salvo e ligado à referência.')));
    } catch (erro) {
      // O look já existe: não se perde nem se duplica; só a ligação falhou.
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'O look foi salvo, mas não deu para ligá-lo à referência. Ligue-o pelo modo manual.',
          ),
        ),
      );
    }
  }

  Future<String?> _pedirNome() {
    return showDialog<String>(
      context: context,
      builder: (_) => _DialogoNomeDoLook(nomeInicial: _nomeSugerido()),
    );
  }

  void _escolherManualmente() {
    Navigator.of(context).pop();
    widget.aoEscolherManualmente?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sugestao = ref.watch(sugestaoDeLookProvider(widget.referenciaId));
    return Scaffold(
      appBar: AppBar(title: const Text('Ligar a um look')),
      body: sugestao.when(
        loading: () => const _Analisando(),
        error: (erro, _) => _Erro(
          mensagem: mensagemDeErro(
            erro,
            padrao: 'Não foi possível analisar a referência agora. Tente novamente.',
          ),
          aoTentarDeNovo: () => ref.invalidate(sugestaoDeLookProvider(widget.referenciaId)),
          aoEscolherManualmente: _escolherManualmente,
        ),
        data: (dados) => _Resultado(
          sugestao: dados,
          gravando: _gravando,
          aoLigarAoLookSalvo: _ligarAoLookSalvo,
          aoSalvarELigar: () => _salvarELigar(dados),
          aoEscolherManualmente: _escolherManualmente,
          aoDescartar: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _Analisando extends StatelessWidget {
  const _Analisando();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Analisando a referência…',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Isso pode levar cerca de 1 minuto. Você pode voltar a qualquer momento.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({
    required this.mensagem,
    required this.aoTentarDeNovo,
    required this.aoEscolherManualmente,
  });

  final String mensagem;
  final VoidCallback aoTentarDeNovo;
  final VoidCallback aoEscolherManualmente;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.sage),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            AppButton(label: 'Tentar de novo', onPressed: aoTentarDeNovo),
            AppButton(
              label: 'Escolher manualmente',
              variant: AppButtonVariant.text,
              onPressed: aoEscolherManualmente,
            ),
          ],
        ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.sugestao,
    required this.gravando,
    required this.aoLigarAoLookSalvo,
    required this.aoSalvarELigar,
    required this.aoEscolherManualmente,
    required this.aoDescartar,
  });

  final SugestaoDeLook sugestao;
  final bool gravando;
  final void Function(String lookId) aoLigarAoLookSalvo;
  final VoidCallback aoSalvarELigar;
  final VoidCallback aoEscolherManualmente;
  final VoidCallback aoDescartar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final look = sugestao.look;

    final (titulo, subtitulo) = switch (sugestao.tipo) {
      SugestaoDeLook.tipoLookSalvo => (
          'Encontrei um look seu parecido',
          'Ele já tem as peças que a IA achou na referência.',
        ),
      SugestaoDeLook.tipoLookNovo => (
          'Montei um look com as suas peças',
          'É uma sugestão: confira antes de salvar.',
        ),
      _ => (
          'Não encontrei peças suas parecidas',
          'Nenhuma peça do seu armário combinou com o que a IA viu na referência.',
        ),
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(titulo, style: tema.titleLarge),
        const SizedBox(height: 4),
        Text(subtitulo, style: tema.bodyMedium),
        const SizedBox(height: 16),
        if (look != null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(look.nome, style: tema.titleMedium),
                  const SizedBox(height: 8),
                  PecasDoLook(pecas: look.pecas),
                ],
              ),
            ),
          ),
        if (look != null) const SizedBox(height: 16),
        if (sugestao.itens.isNotEmpty) ...[
          Text('O que a IA achou na referência', style: tema.labelLarge),
          const SizedBox(height: 8),
          for (final item in sugestao.itens) _LinhaDoItem(item: item),
        ],
        if (sugestao.lacunas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Aviso(
            icone: Icons.info_outline,
            texto: 'Sem peça equivalente: ${sugestao.lacunas.join(', ')}.',
          ),
        ],
        if (sugestao.naoAnalisadas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Aviso(
            icone: Icons.hourglass_empty,
            texto: 'Não deu tempo de analisar: ${sugestao.naoAnalisadas.join(', ')}.',
          ),
        ],
        const SizedBox(height: 24),
        if (sugestao.tipo == SugestaoDeLook.tipoLookSalvo && look != null)
          AppButton(
            label: 'Ligar a este look',
            icon: Icons.link,
            loading: gravando,
            onPressed: () => aoLigarAoLookSalvo(look.id),
          ),
        if (sugestao.tipo == SugestaoDeLook.tipoLookNovo)
          AppButton(
            label: 'Salvar como look e ligar',
            icon: Icons.bookmark_add_outlined,
            loading: gravando,
            onPressed: aoSalvarELigar,
          ),
        if (sugestao.tipo == SugestaoDeLook.tipoSemPecas)
          AppButton(label: 'Escolher manualmente', onPressed: aoEscolherManualmente)
        else
          AppButton(
            label: 'Escolher manualmente',
            variant: AppButtonVariant.secondary,
            onPressed: gravando ? null : aoEscolherManualmente,
          ),
        AppButton(
          label: 'Descartar',
          variant: AppButtonVariant.text,
          onPressed: gravando ? null : aoDescartar,
        ),
      ],
    );
  }
}

/// Uma etiqueta da referência e a peça do armário que a IA achou (ou o motivo).
class _LinhaDoItem extends StatelessWidget {
  const _LinhaDoItem({required this.item});

  final ItemDaSugestao item;

  String get _situacao => switch (item.situacao) {
        ItemDaSugestao.semPecaEquivalente => 'Sem peça equivalente',
        ItemDaSugestao.naoEntendida => 'Não entendi esta peça',
        ItemDaSugestao.naoAnalisada => 'Não deu tempo de analisar',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final peca = item.peca;
    final tema = Theme.of(context).textTheme;
    final descricao = peca == null ? _situacao : descricaoPeca(peca);
    return Semantics(
      label: '${item.etiqueta}: $descricao${item.corDiferente ? ', cor diferente da referência' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: peca == null
                    ? const Icon(Icons.help_outline, color: AppColors.textSecondary)
                    : Image.network(
                        AppConstants.resolveMediaUrl(peca.imagemUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, erro, stack) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.etiqueta, style: tema.bodyLarge),
                    Text(
                      descricao,
                      style: tema.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Mesmo tipo de peça, outra cor: a sugestão vale, mas a pessoa vê a diferença.
                    if (item.corDiferente)
                      Text(
                        'Cor diferente da referência',
                        style: tema.bodySmall?.copyWith(color: AppColors.sageEscuro),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _DialogoNomeDoLook extends StatefulWidget {
  const _DialogoNomeDoLook({required this.nomeInicial});

  final String nomeInicial;

  @override
  State<_DialogoNomeDoLook> createState() => _DialogoNomeDoLookState();
}

class _DialogoNomeDoLookState extends State<_DialogoNomeDoLook> {
  late final _controller = TextEditingController(text: widget.nomeInicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nome = _controller.text.trim();
    if (nome.isNotEmpty) Navigator.of(context).pop(nome);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nome do look'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirmar(),
        decoration: const InputDecoration(labelText: 'Nome'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Salvar e ligar'),
        ),
      ],
    );
  }
}
