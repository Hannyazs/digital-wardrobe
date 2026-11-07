import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/clothing_card.dart';
import '../../models/peca.dart';
import '../wardrobe/wardrobe_controller.dart';
import '../wardrobe/widgets/carrosseis_paginados.dart';
import 'preferences_controller.dart';

/// Escolha de um par de peças do armário para evitar juntas (E4.F4.3).
/// Mesmo padrão de grade de `MontarLookView` (categorias + `ClothingCard`
/// selecionável), mas com seleção **local** e limitada a duas peças: a
/// seleção de um par não pode vazar para a montagem de look.
class EscolherParView extends ConsumerStatefulWidget {
  const EscolherParView({super.key});

  @override
  ConsumerState<EscolherParView> createState() => _EscolherParViewState();
}

class _EscolherParViewState extends ConsumerState<EscolherParView> {
  /// Ids na ordem em que foram tocados (no máximo dois).
  final _selecionadas = <String>[];
  bool _enviando = false;

  void _alternar(Peca peca) {
    setState(() {
      if (_selecionadas.contains(peca.id)) {
        _selecionadas.remove(peca.id);
      } else if (_selecionadas.length < 2) {
        _selecionadas.add(peca.id);
      } else {
        // Terceira peça: bloqueada com aviso (não troca a mais antiga em
        // silêncio — o usuário decide qual desmarcar).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Escolha só duas peças. Desmarque uma para trocar.'),
          ));
      }
    });
  }

  Future<void> _confirmar() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _enviando = true);
    try {
      final resultado = await ref
          .read(preferenciaServiceProvider)
          .evitarCombinacao(_selecionadas[0], _selecionadas[1]);
      ref.invalidate(evitadasProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(resultado.jaExistia
            ? 'Essa combinação já estava na lista.'
            : 'Combinação adicionada: essas peças não serão sugeridas juntas.'),
      ));
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _enviando = false);
      messenger.showSnackBar(
        SnackBar(content: Text(mensagemDeErroEvitadas(error, 'salvar a combinação'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAsync = ref.watch(totalDePecasProvider(const ConsultaPecas()));
    final completo = _selecionadas.length == 2;
    final poucasPecas =
        totalAsync.valueOrNull != null && totalAsync.valueOrNull! < 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Peças que não combinam')),
      body: totalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar seu armário.'),
              const SizedBox(height: 12),
              AppButton(
                label: 'Tentar novamente',
                onPressed: () => invalidarPecas(ref),
              ),
            ],
          ),
        ),
        data: (total) {
          if (total < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cadastre pelo menos duas peças para indicar uma combinação que você evita.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Selecione as duas peças que você não quer ver juntas '
                  '(${_selecionadas.length} de 2).',
                ),
              ),
              Expanded(
                child: ListaDeCarrosseis(
                  grupos: gruposPorCategoria,
                  filtro: const FiltroPecas(),
                  vazio: const SizedBox.shrink(),
                  aoLimparFiltro: () {},
                  padding: const EdgeInsets.only(top: 0, bottom: 16),
                  // A seleção é por id e vive na tela: continua marcada ao
                  // rolar, carregar outra página ou trocar de categoria.
                  itemBuilder: (context, peca) => ClothingCard(
                    imagemUrl: peca.imagemUrl,
                    rotulo: descricaoPeca(peca),
                    selecionavel: true,
                    selecionada: _selecionadas.contains(peca.id),
                    onTap: _enviando ? null : () => _alternar(peca),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: totalAsync.maybeWhen(
        data: (_) => poucasPecas
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: 'Evitar essa combinação',
                  onPressed: completo && !_enviando ? _confirmar : null,
                  loading: _enviando,
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}
