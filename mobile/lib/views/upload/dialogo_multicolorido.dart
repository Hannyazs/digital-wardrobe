import 'package:flutter/material.dart';

import '../../core/constants/peca_opcoes.dart';

/// Resultado do diálogo: a cor predominante e as demais; [demais] vazio
/// significa peça de uma cor só.
typedef CoresMulticolor = ({String predominante, List<String> demais});

/// Diálogo do botão "Multicolorido: cores principais". Pede a cor predominante
/// e, havendo mais de uma cor, as demais. Devolve `null` se cancelado.
Future<CoresMulticolor?> escolherCoresMulticolor(
  BuildContext context, {
  String? predominante,
  List<String> demais = const [],
}) {
  return showDialog<CoresMulticolor>(
    context: context,
    builder: (_) => _DialogoMulticolorido(predominante: predominante, demais: demais),
  );
}

class _DialogoMulticolorido extends StatefulWidget {
  const _DialogoMulticolorido({required this.predominante, required this.demais});

  final String? predominante;
  final List<String> demais;

  @override
  State<_DialogoMulticolorido> createState() => _DialogoMulticoloridoState();
}

class _DialogoMulticoloridoState extends State<_DialogoMulticolorido> {
  String? _predominante;
  late final Set<String> _demais = {...widget.demais};

  @override
  void initState() {
    super.initState();
    _predominante = widget.predominante;
  }

  Widget _chip(CorOpcao cor, {required bool selecionada, required VoidCallback onTap}) {
    return FilterChip(
      label: Text(cor.nome),
      avatar: CircleAvatar(backgroundColor: cor.cor, radius: 8),
      selected: selecionada,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Peça multicolorida'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecione a cor predominante', style: estilo.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cor in coresFixas)
                  _chip(
                    cor,
                    selecionada: _predominante == cor.nome,
                    onTap: () => setState(() {
                      _predominante = cor.nome;
                      _demais.remove(cor.nome);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Se houver mais de uma cor, selecione as demais', style: estilo.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cor in coresFixas.where((c) => c.nome != _predominante))
                  _chip(
                    cor,
                    selecionada: _demais.contains(cor.nome),
                    onTap: () => setState(() {
                      if (!_demais.remove(cor.nome)) _demais.add(cor.nome);
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _predominante == null
              ? null
              : () => Navigator.of(context).pop((
                    predominante: _predominante!,
                    demais: [
                      for (final c in coresFixas)
                        if (_demais.contains(c.nome)) c.nome,
                    ],
                  )),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
