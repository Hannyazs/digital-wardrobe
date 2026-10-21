import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/peca_opcoes.dart';
import '../../core/state/envio_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../models/peca.dart';
import '../home/home_shell.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'peca_form_controller.dart';

/// Formulário de metadados da peça — última etapa do cadastro (E1.F2.1),
/// depois do resultado do processamento de imagem (E1.F1.3/E1.F1.4), ou
/// a edição de uma peça existente (E1.F3.1) quando [pecaExistente] é
/// passado. Em criação chama `POST /pecas`; em edição, `PUT /pecas/{id}`
/// — a imagem nunca é alterada aqui.
class PecaFormView extends ConsumerStatefulWidget {
  const PecaFormView({
    super.key,
    required this.imagemUrl,
    this.semRemocaoDeFundo = false,
    this.pecaExistente,
  });

  final String imagemUrl;
  final bool semRemocaoDeFundo;
  final Peca? pecaExistente;

  @override
  ConsumerState<PecaFormView> createState() => _PecaFormViewState();
}

class _PecaFormViewState extends ConsumerState<PecaFormView> {
  final _formKey = GlobalKey<FormState>();
  final _subcategoriaController = TextEditingController();
  final _outraOcasiaoController = TextEditingController();
  String? _categoria;
  String? _corPrincipal;
  String? _tonalidadeCor;
  String? _estacao;
  String? _estilo;
  String? _modelagem;
  final Set<String> _ocasioes = {};
  bool _outraOcasiao = false;

  @override
  void initState() {
    super.initState();
    final existente = widget.pecaExistente;
    if (existente != null) {
      _categoria = existente.categoria;
      _subcategoriaController.text = existente.subcategoria ?? '';
      _corPrincipal = existente.corPrincipal;
      _tonalidadeCor = existente.tonalidadeCor;
      _estacao = existente.estacao;
      _estilo = existente.estilo;
      _modelagem = existente.modelagem;
      // Ocasião fora da lista (texto livre de antes, ou "Outros" digitado)
      // volta como "Outros" com o texto preenchido — nada se perde ao editar.
      final personalizadas = <String>[];
      for (final ocasiao in existente.ocasioes) {
        if (ocasioesFixas.contains(ocasiao)) {
          _ocasioes.add(ocasiao);
        } else {
          personalizadas.add(ocasiao);
        }
      }
      if (personalizadas.isNotEmpty) {
        _outraOcasiao = true;
        _outraOcasiaoController.text = personalizadas.join(', ');
      }
    }
  }

  @override
  void dispose() {
    _subcategoriaController.dispose();
    _outraOcasiaoController.dispose();
    super.dispose();
  }

  void _selecionarCor(String? cor) {
    setState(() {
      _corPrincipal = cor;
      // Só sugere: o usuário pode trocar a tonalidade logo em seguida.
      final sugerida = tonalidadeSugeridaPara(cor);
      if (sugerida != null) _tonalidadeCor = sugerida;
    });
  }

  void _selecionarCategoria(String? categoria) {
    setState(() {
      _categoria = categoria;
      // Modelagem escolhida para outra categoria deixa de valer.
      if (_modelagem != null && !modelagensDe(categoria).contains(_modelagem)) {
        _modelagem = null;
      }
    });
  }

  List<String> _ocasioesParaEnviar() {
    final lista = ocasioesFixas.where(_ocasioes.contains).toList();
    final outra = _outraOcasiaoController.text.trim();
    if (_outraOcasiao && outra.isNotEmpty) lista.add(outra);
    return lista;
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(pecaFormProvider.notifier).enviar(
          pecaId: widget.pecaExistente?.id,
          imagemUrl: widget.imagemUrl,
          categoria: _categoria!,
          subcategoria: _subcategoriaController.text.trim().isEmpty
              ? null
              : _subcategoriaController.text.trim(),
          corPrincipal: _corPrincipal,
          tonalidadeCor: _tonalidadeCor,
          estacao: _estacao,
          estilo: _estilo,
          modelagem: _modelagem,
          ocasioes: _ocasioesParaEnviar(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.pecaExistente != null;
    final EnvioState envioState = ref.watch(pecaFormProvider);

    ref.listen<EnvioState>(pecaFormProvider, (previous, next) {
      if (next is EnvioSucesso) {
        if (editando) {
          // Diferente da criação: já estamos dentro da pilha do HomeShell
          // (armário -> detalhe -> este formulário), só volta pra ele —
          // reconstruí-lo do zero não faz sentido aqui.
          ref.invalidate(pecaListProvider);
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // Só chega aqui depois do backend confirmar o salvamento. Invalida a
          // lista para o armário buscar a peça nova em vez de reaproveitar o
          // cache do `HomeShell` anterior (que ainda está sendo descartado).
          ref.invalidate(pecaListProvider);
          // Substitui a pilha pelo armário: impede reabrir esta tela (ou a
          // de resultado do processamento) pelo botão "voltar" do navegador
          // e reenviar a mesma peça duas vezes.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const HomeShell()),
            (route) => false,
          );
        }
      } else if (next is EnvioErro) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.mensagem)));
      }
    });

    final enviando = envioState is Enviando;

    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar peça' : 'Detalhes da peça')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    AppConstants.resolveMediaUrl(widget.imagemUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 64),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoria *'),
                  items: comValorAtual(categoriasFixas, _categoria)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: enviando ? null : _selecionarCategoria,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecione uma categoria'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subcategoriaController,
                  enabled: !enviando,
                  decoration: const InputDecoration(labelText: 'Subcategoria'),
                ),
                const SizedBox(height: 24),
                _GrupoDeChips(
                  rotulo: 'Cor',
                  opcoes: comValorAtual(coresFixas.map((c) => c.nome).toList(), _corPrincipal),
                  selecionado: _corPrincipal,
                  amostra: (nome) {
                    for (final c in coresFixas) {
                      if (c.nome == nome) return c.cor;
                    }
                    return null;
                  },
                  onSelecionar: enviando ? null : _selecionarCor,
                ),
                _GrupoDeChips(
                  rotulo: 'Tonalidade da cor',
                  opcoes: comValorAtual(tonalidadesFixas, _tonalidadeCor),
                  selecionado: _tonalidadeCor,
                  onSelecionar:
                      enviando ? null : (valor) => setState(() => _tonalidadeCor = valor),
                ),
                _GrupoDeChips(
                  rotulo: 'Estação',
                  opcoes: comValorAtual(estacoesFixas, _estacao),
                  selecionado: _estacao,
                  onSelecionar: enviando ? null : (valor) => setState(() => _estacao = valor),
                ),
                _GrupoDeChips(
                  rotulo: 'Estilo',
                  opcoes: comValorAtual(estilosFixos, _estilo),
                  selecionado: _estilo,
                  onSelecionar: enviando ? null : (valor) => setState(() => _estilo = valor),
                ),
                if (modelagensDe(_categoria).isNotEmpty || _modelagem != null)
                  _GrupoDeChips(
                    rotulo: 'Modelagem',
                    opcoes: comValorAtual(modelagensDe(_categoria), _modelagem),
                    selecionado: _modelagem,
                    onSelecionar:
                        enviando ? null : (valor) => setState(() => _modelagem = valor),
                  ),
                _SecaoOcasioes(
                  selecionadas: _ocasioes,
                  outraAtiva: _outraOcasiao,
                  outraController: _outraOcasiaoController,
                  habilitado: !enviando,
                  onAlternar: (ocasiao, marcada) => setState(() {
                    marcada ? _ocasioes.add(ocasiao) : _ocasioes.remove(ocasiao);
                  }),
                  onAlternarOutra: (ativa) => setState(() => _outraOcasiao = ativa),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: editando ? 'Salvar alterações' : 'Salvar peça',
                  onPressed: _confirmar,
                  loading: enviando,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seleção única por chips; tocar no chip já selecionado desmarca (campos
/// opcionais). `onSelecionar == null` desabilita (durante o envio).
class _GrupoDeChips extends StatelessWidget {
  const _GrupoDeChips({
    required this.rotulo,
    required this.opcoes,
    required this.selecionado,
    required this.onSelecionar,
    this.amostra,
  });

  final String rotulo;
  final List<String> opcoes;
  final String? selecionado;
  final ValueChanged<String?>? onSelecionar;
  final Color? Function(String opcao)? amostra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final opcao in opcoes)
                ChoiceChip(
                  label: Text(opcao),
                  avatar: amostra?.call(opcao) == null
                      ? null
                      : CircleAvatar(backgroundColor: amostra!(opcao), radius: 8),
                  selected: selecionado == opcao,
                  onSelected: onSelecionar == null
                      ? null
                      : (marcado) => onSelecionar!(marcado ? opcao : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ocasiões de uso (múltipla escolha) + "Outros" com texto livre.
class _SecaoOcasioes extends StatelessWidget {
  const _SecaoOcasioes({
    required this.selecionadas,
    required this.outraAtiva,
    required this.outraController,
    required this.habilitado,
    required this.onAlternar,
    required this.onAlternarOutra,
  });

  final Set<String> selecionadas;
  final bool outraAtiva;
  final TextEditingController outraController;
  final bool habilitado;
  final void Function(String ocasiao, bool marcada) onAlternar;
  final ValueChanged<bool> onAlternarOutra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ocasiões', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final ocasiao in ocasioesFixas)
              FilterChip(
                label: Text(ocasiao),
                selected: selecionadas.contains(ocasiao),
                onSelected: habilitado ? (marcada) => onAlternar(ocasiao, marcada) : null,
              ),
            FilterChip(
              label: const Text(ocasiaoOutros),
              selected: outraAtiva,
              onSelected: habilitado ? onAlternarOutra : null,
            ),
          ],
        ),
        if (outraAtiva) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: outraController,
            enabled: habilitado,
            decoration: const InputDecoration(labelText: 'Qual ocasião?'),
            validator: (value) => outraAtiva && (value == null || value.trim().isEmpty)
                ? 'Informe a ocasião'
                : null,
          ),
        ],
      ],
    );
  }
}
