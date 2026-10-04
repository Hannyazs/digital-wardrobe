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
  final _corPrincipalController = TextEditingController();
  final _estacaoController = TextEditingController();
  String? _categoria;
  String? _ocasiao;

  @override
  void initState() {
    super.initState();
    final existente = widget.pecaExistente;
    if (existente != null) {
      _categoria = existente.categoria;
      _subcategoriaController.text = existente.subcategoria ?? '';
      _corPrincipalController.text = existente.corPrincipal ?? '';
      _estacaoController.text = existente.estacao ?? '';
      _ocasiao = existente.ocasiao;
    }
  }

  @override
  void dispose() {
    _subcategoriaController.dispose();
    _corPrincipalController.dispose();
    _estacaoController.dispose();
    super.dispose();
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
          corPrincipal: _corPrincipalController.text.trim().isEmpty
              ? null
              : _corPrincipalController.text.trim(),
          estacao: _estacaoController.text.trim().isEmpty
              ? null
              : _estacaoController.text.trim(),
          ocasiao: _ocasiao,
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
                  items: categoriasFixas
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: enviando
                      ? null
                      : (value) => setState(() => _categoria = value),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _corPrincipalController,
                  enabled: !enviando,
                  decoration: const InputDecoration(labelText: 'Cor principal'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estacaoController,
                  enabled: !enviando,
                  decoration: const InputDecoration(labelText: 'Estação'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _ocasiao,
                  decoration: const InputDecoration(labelText: 'Ocasião'),
                  items: ocasioesFixas
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: enviando
                      ? null
                      : (value) => setState(() => _ocasiao = value),
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
