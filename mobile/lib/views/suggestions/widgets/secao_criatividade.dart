import 'package:flutter/material.dart';

import '../../../core/constants/peca_opcoes.dart';

/// Seção "Criatividade das combinações" (E4.F5.1): `Slider` de 1 a 5. Mora na aba
/// Sugestões, junto dos filtros, porque é lá que os looks são gerados; o valor é a
/// mesma preferência salva do usuário (`preferencias.criatividade`).
///
///
/// Durante o arrasto o valor fica só aqui (o rótulo acompanha o dedo, sem
/// chamar o servidor); ao soltar, [onSalvar] recebe o nível e diz se gravou.
/// Quando o valor vindo de fora muda, a seção volta a refleti-lo; se o
/// salvamento falhar, ela volta ao nível de antes de soltar — mesmo que a
/// mudança otimista e a reversão tenham acontecido antes de um novo quadro (o
/// widget nunca chegou a ver o valor mudar, então `didUpdateWidget` não basta).
class SecaoCriatividade extends StatefulWidget {
  const SecaoCriatividade({super.key, required this.nivel, required this.onSalvar});

  /// Nível atual (1 a 5) segundo o controller de preferências.
  final int nivel;

  /// Grava o nível; devolve `true` se deu certo.
  final Future<bool> Function(int nivel) onSalvar;

  @override
  State<SecaoCriatividade> createState() => _SecaoCriatividadeState();
}

class _SecaoCriatividadeState extends State<SecaoCriatividade> {
  late double _valor = widget.nivel.toDouble();

  @override
  void didUpdateWidget(covariant SecaoCriatividade antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.nivel != widget.nivel) _valor = widget.nivel.toDouble();
  }

  String get _rotulo => niveisDeCriatividade[_valor.round() - 1];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Criatividade das combinações', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'O quanto as sugestões podem sair do óbvio.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: _valor,
              label: _rotulo,
              onChanged: (valor) => setState(() => _valor = valor),
              onChangeEnd: (valor) async {
                final nivel = valor.round();
                final anterior = widget.nivel;
                if (nivel == anterior) return;
                final gravou = await widget.onSalvar(nivel);
                if (!gravou && mounted) setState(() => _valor = anterior.toDouble());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(niveisDeCriatividade.first, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  _rotulo,
                  key: const Key('rotulo-criatividade'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(niveisDeCriatividade.last, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
