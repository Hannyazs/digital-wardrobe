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
import 'dialogo_multicolorido.dart';
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
    this.sugestao,
  });

  final String imagemUrl;
  final bool semRemocaoDeFundo;
  final Peca? pecaExistente;

  /// Metadados sugeridos pela IA (E7.F1.2); só vale no cadastro novo.
  final Map<String, dynamic>? sugestao;

  @override
  ConsumerState<PecaFormView> createState() => _PecaFormViewState();
}

class _PecaFormViewState extends ConsumerState<PecaFormView> {
  final _formKey = GlobalKey<FormState>();
  // Campos obrigatórios: o formulário rola até eles quando faltam.
  final _categoriaKey = GlobalKey();
  final _outraOcasiaoKey = GlobalKey();
  final _subcategoriaController = TextEditingController();
  final _outraOcasiaoController = TextEditingController();
  String? _categoria;
  String? _corPrincipal;
  String? _tonalidadeCor;
  List<String> _coresSecundarias = [];
  final Set<String> _estacoes = {};
  final Set<String> _estilos = {};
  String? _modelagem;
  final Set<String> _ocasioes = {};
  bool _outraOcasiao = false;
  bool _preenchidoPelaIa = false;

  @override
  void initState() {
    super.initState();
    final existente = widget.pecaExistente;
    if (existente != null) {
      _categoria = existente.categoria;
      _subcategoriaController.text = existente.subcategoria ?? '';
      _corPrincipal = existente.corPrincipal;
      _tonalidadeCor = existente.tonalidadeCor;
      _coresSecundarias = [...existente.coresSecundarias];
      _estacoes.addAll(existente.estacoes);
      _estilos.addAll(existente.estilos);
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
    } else if (widget.sugestao != null) {
      _aplicarSugestao(widget.sugestao!);
    }
  }

  /// Valor fora das listas fixas ou vazio conta como "sem sugestão".
  static String? _daLista(Object? valor, List<String> permitidos) =>
      valor is String && permitidos.contains(valor) ? valor : null;

  void _aplicarSugestao(Map<String, dynamic> sugestao) {
    _categoria = _daLista(sugestao['categoria'], categoriasFixas);
    _corPrincipal = _daLista(sugestao['cor_principal'], coresFixas.map((c) => c.nome).toList());
    _tonalidadeCor = _daLista(sugestao['tonalidade_cor'], tonalidadesFixas) ??
        tonalidadeSugeridaPara(_corPrincipal);
    final subcategoria = sugestao['subcategoria'];
    if (subcategoria is String && subcategoria.trim().isNotEmpty) {
      _subcategoriaController.text = subcategoria.trim();
    }
    _preenchidoPelaIa = _categoria != null ||
        _corPrincipal != null ||
        _subcategoriaController.text.isNotEmpty;
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
      _coresSecundarias = _coresSecundarias.where((c) => c != cor).toList();
      // Só sugere: o usuário pode trocar a tonalidade logo em seguida.
      final sugerida = tonalidadeSugeridaPara(cor);
      if (sugerida != null) _tonalidadeCor = sugerida;
    });
  }

  void _alternarEstacao(String estacao, bool marcada) {
    setState(() {
      if (!marcada) {
        _estacoes.remove(estacao);
      } else if (estacao == _todasAsEstacoes) {
        // "Todas" já cobre as outras: marcar uma exclui a outra.
        _estacoes
          ..clear()
          ..add(estacao);
      } else {
        _estacoes
          ..remove(_todasAsEstacoes)
          ..add(estacao);
      }
    });
  }

  Future<void> _abrirMulticolorido() async {
    final resultado = await escolherCoresMulticolor(
      context,
      predominante: _corPrincipal,
      demais: _coresSecundarias,
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _corPrincipal = resultado.predominante;
      _coresSecundarias = resultado.demais;
      final sugerida = tonalidadeSugeridaPara(resultado.predominante);
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
    if (!_formKey.currentState!.validate()) {
      // O botão fica no fim de um formulário longo: sem rolar, o erro (no
      // topo) não aparece e o toque parece não ter feito nada.
      final alvo = _categoria == null ? _categoriaKey : _outraOcasiaoKey;
      final contexto = alvo.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(contexto, duration: const Duration(milliseconds: 300));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise o campo destacado.')),
      );
      return;
    }
    ref.read(pecaFormProvider.notifier).enviar(
          pecaId: widget.pecaExistente?.id,
          imagemUrl: widget.imagemUrl,
          categoria: _categoria!,
          subcategoria: _subcategoriaController.text.trim().isEmpty
              ? null
              : _subcategoriaController.text.trim(),
          corPrincipal: _corPrincipal,
          tonalidadeCor: _tonalidadeCor,
          coresSecundarias: _coresSecundarias,
          estacoes: [
            ...estacoesFixas.where(_estacoes.contains),
            ..._estacoes.where((e) => !estacoesFixas.contains(e)),
          ],
          estilos: [
            ...estilosFixos.where(_estilos.contains),
            ..._estilos.where((e) => !estilosFixos.contains(e)),
          ],
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
      appBar: AppBar(title: Text(editando ? 'Editar peça' : 'Dados da peça')),
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
                if (_preenchidoPelaIa) ...[
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sugerido pela IA — revise antes de salvar',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  key: _categoriaKey,
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
                  decoration: const InputDecoration(
                    labelText: 'Subcategoria',
                    hintText: 'Ex.: jeans, midi, social',
                  ),
                ),
                _SubcategoriasUsadas(
                  opcoes: subcategoriasUsadas(
                    ref.watch(pecaListProvider).valueOrNull ?? const [],
                    _categoria,
                    atual: _subcategoriaController.text,
                  ),
                  onEscolher: enviando
                      ? null
                      : (valor) => setState(() => _subcategoriaController.text = valor),
                ),
                const SizedBox(height: 24),
                // O selo de "cadastro incompleto" (E5.F4.1) vem destes campos:
                // melhor avisar aqui do que o usuário descobrir depois.
                Text(
                  'Cor, ocasião e estilo ajudam nas sugestões de looks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _GrupoDeChips(
                  rotulo: 'Cor principal',
                  dica: 'A cor que mais aparece na peça.',
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
                _BotaoMulticolorido(
                  predominante: _corPrincipal,
                  demais: _coresSecundarias,
                  habilitado: !enviando,
                  onPressed: _abrirMulticolorido,
                  onRemover: () => setState(() => _coresSecundarias = []),
                ),
                _GrupoDeChips(
                  rotulo: 'Tonalidade da cor',
                  dica: 'Sugerida pela cor; você pode trocar.',
                  opcoes: comValorAtual(tonalidadesFixas, _tonalidadeCor),
                  selecionado: _tonalidadeCor,
                  onSelecionar:
                      enviando ? null : (valor) => setState(() => _tonalidadeCor = valor),
                ),
                Text('Estações', style: Theme.of(context).textTheme.labelLarge),
                Text('Pode marcar várias.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final estacao in [
                        ...estacoesFixas,
                        ..._estacoes.where((e) => !estacoesFixas.contains(e)),
                      ])
                        FilterChip(
                          label: Text(estacao),
                          selected: _estacoes.contains(estacao),
                          onSelected:
                              enviando ? null : (marcada) => _alternarEstacao(estacao, marcada),
                        ),
                    ],
                  ),
                ),
                Text('Estilos', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  'Pode marcar vários: uma peça de festa também pode ser casual.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final estilo in [
                        ...estilosFixos,
                        ..._estilos.where((e) => !estilosFixos.contains(e)),
                      ])
                        FilterChip(
                          label: Text(estilo),
                          selected: _estilos.contains(estilo),
                          onSelected: enviando
                              ? null
                              : (marcado) => setState(() {
                                    marcado ? _estilos.add(estilo) : _estilos.remove(estilo);
                                  }),
                        ),
                    ],
                  ),
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
                  outraKey: _outraOcasiaoKey,
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

const _todasAsEstacoes = 'Todas as estações';

/// Botão "Multicolorido: cores principais" abaixo das cores. Com a peça já
/// multicolorida, mostra as cores escolhidas e permite remover.
class _BotaoMulticolorido extends StatelessWidget {
  const _BotaoMulticolorido({
    required this.predominante,
    required this.demais,
    required this.habilitado,
    required this.onPressed,
    required this.onRemover,
  });

  final String? predominante;
  final List<String> demais;
  final bool habilitado;
  final VoidCallback onPressed;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final ativo = demais.isNotEmpty && predominante != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            avatar: const Icon(Icons.palette_outlined, size: 18),
            label: Text(
              ativo
                  ? 'Multicolorido: $predominante + ${demais.join(', ')}'
                  : 'Multicolorido: cores principais',
            ),
            onPressed: habilitado ? onPressed : null,
          ),
          if (ativo)
            TextButton(onPressed: habilitado ? onRemover : null, child: const Text('Remover')),
        ],
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
    this.dica,
  });

  final String rotulo;

  /// Linha de ajuda abaixo do rótulo.
  final String? dica;
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
          if (dica != null) Text(dica!, style: Theme.of(context).textTheme.bodySmall),
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
    required this.outraKey,
    required this.selecionadas,
    required this.outraAtiva,
    required this.outraController,
    required this.habilitado,
    required this.onAlternar,
    required this.onAlternarOutra,
  });

  final GlobalKey outraKey;
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
        Text('Pode marcar várias.', style: Theme.of(context).textTheme.bodySmall),
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
            key: outraKey,
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

/// Subcategorias já usadas na mesma categoria, como atalhos: evita "Midi" e
/// "midi" virarem duas seções na gaveta.
class _SubcategoriasUsadas extends StatelessWidget {
  const _SubcategoriasUsadas({required this.opcoes, required this.onEscolher});

  final List<String> opcoes;
  final ValueChanged<String>? onEscolher;

  @override
  Widget build(BuildContext context) {
    if (opcoes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Já usadas:', style: Theme.of(context).textTheme.bodySmall),
          for (final opcao in opcoes)
            ActionChip(
              label: Text(opcao),
              onPressed: onEscolher == null ? null : () => onEscolher!(opcao),
            ),
        ],
      ),
    );
  }
}
