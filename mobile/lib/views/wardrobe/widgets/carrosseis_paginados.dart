import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/peca_opcoes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/category_section.dart';
import '../../../models/peca.dart';
import '../wardrobe_controller.dart';
import 'filtros_de_pecas.dart';

/// Um carrossel da lista: o título e o recorte do armário que ele mostra
/// (sem filtro; o filtro da tela é acrescentado por [ListaDeCarrosseis]).
class GrupoDePecas {
  const GrupoDePecas(this.titulo, this.base);

  final String titulo;
  final ConsultaPecas base;
}

/// Um carrossel por gaveta (a tela do armário), "Outras" por último.
final List<GrupoDePecas> gruposPorGaveta = [
  for (final gaveta in [...gavetasDoArmario, gavetaOutras])
    GrupoDePecas(gaveta.nome, ConsultaPecas.daGaveta(gaveta)),
];

/// Um carrossel por categoria, na ordem de [categoriasFixas] e "Outras" por
/// último (montar look, editar peças do look e escolher par de peças).
final List<GrupoDePecas> gruposPorCategoria = [
  for (final categoria in [...categoriasFixas, 'Outras'])
    GrupoDePecas(categoria, ConsultaPecas.daCategoria(categoria)),
];

/// Peças carregadas até agora nos [grupos] com o [filtro]: base das opções de
/// filtro (cores, estações e ocasiões livres que aparecem nas peças).
List<Peca> pecasCarregadas(
    WidgetRef ref, List<GrupoDePecas> grupos, FiltroPecas filtro) {
  return [
    for (final grupo in grupos)
      ...?ref
          .watch(pecasPaginadasProvider(grupo.base.comFiltro(filtro)))
          .valueOrNull
          ?.itens,
  ];
}

/// Lista vertical de carrosséis paginados (E11.F1.2). Cada carrossel carrega
/// as próprias peças e pede a página seguinte quando a rolagem chega ao fim.
///
/// Decide entre carregando, erro geral, armário vazio, "nenhum resultado para
/// o filtro" e a lista; erro de um carrossel só aparece nele, com "tentar de novo".
class ListaDeCarrosseis extends ConsumerWidget {
  const ListaDeCarrosseis({
    super.key,
    required this.grupos,
    required this.filtro,
    required this.itemBuilder,
    required this.aoLimparFiltro,
    required this.vazio,
    this.listKey,
    this.aoAbrirGrupo,
    this.mostrarContagem = false,
    this.padding = const EdgeInsets.only(top: 4, bottom: 16),
  });

  final List<GrupoDePecas> grupos;
  final FiltroPecas filtro;
  final Widget Function(BuildContext context, Peca peca) itemBuilder;
  final VoidCallback aoLimparFiltro;

  /// Mostrado quando não há nenhuma peça e nenhum filtro ativo.
  final Widget vazio;
  final Key? listKey;
  final void Function(GrupoDePecas grupo)? aoAbrirGrupo;
  final bool mostrarContagem;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultas = [for (final g in grupos) g.base.comFiltro(filtro)];
    final estados = [
      for (final c in consultas) ref.watch(pecasPaginadasProvider(c))
    ];

    final algumaPeca =
        estados.any((e) => (e.valueOrNull?.itens ?? const []).isNotEmpty);
    final carregando =
        estados.where((e) => e.isLoading && !e.hasValue && !e.hasError).length;
    final comErro = estados.where((e) => e.hasError && !e.hasValue).length;

    if (!algumaPeca) {
      if (carregando > 0) {
        return const Center(child: CircularProgressIndicator());
      }
      if (comErro == estados.length) {
        final erro = estados.first.error!;
        return _Erro(
          mensagem: mensagemDeErroArmario(erro),
          aoTentarNovamente: () => _recarregar(ref, consultas),
        );
      }
      if (comErro == 0) {
        return filtro.ativo
            ? SemResultadoFiltro(onLimpar: aoLimparFiltro)
            : vazio;
      }
    }

    return ListView(
      key: listKey,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        for (var i = 0; i < grupos.length; i++)
          _Carrossel(
            titulo: grupos[i].titulo,
            consulta: consultas[i],
            itemBuilder: itemBuilder,
            mostrarContagem: mostrarContagem,
            aoAbrir:
                aoAbrirGrupo == null ? null : () => aoAbrirGrupo!(grupos[i]),
          ),
      ],
    );
  }

  void _recarregar(WidgetRef ref, List<ConsultaPecas> consultas) {
    for (final c in consultas) {
      ref.invalidate(pecasPaginadasProvider(c));
    }
  }
}

/// Recarrega os [grupos] com o [filtro] e espera terminar (puxar para atualizar).
Future<void> recarregarGrupos(
    WidgetRef ref, List<GrupoDePecas> grupos, FiltroPecas filtro) async {
  invalidarPecas(ref);
  await Future.wait([
    for (final g in grupos)
      ref
          .read(pecasPaginadasProvider(g.base.comFiltro(filtro)).future)
          .then<void>((_) {}, onError: (_) {}),
  ]);
}

class _Carrossel extends ConsumerWidget {
  const _Carrossel({
    required this.titulo,
    required this.consulta,
    required this.itemBuilder,
    required this.mostrarContagem,
    required this.aoAbrir,
  });

  final String titulo;
  final ConsultaPecas consulta;
  final Widget Function(BuildContext context, Peca peca) itemBuilder;
  final bool mostrarContagem;
  final VoidCallback? aoAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(pecasPaginadasProvider(consulta));
    final dados = estado.valueOrNull;
    if (dados == null) {
      if (!estado.hasError) return const SizedBox.shrink();
      return _ErroDoCarrossel(
        titulo: titulo,
        aoTentarNovamente: () =>
            ref.invalidate(pecasPaginadasProvider(consulta)),
      );
    }
    if (dados.itens.isEmpty) return const SizedBox.shrink();

    return CategorySection(
      titulo: titulo,
      contagem: mostrarContagem ? (dados.total ?? dados.itens.length) : null,
      itemCount: dados.itens.length,
      onTap: aoAbrir,
      itemBuilder: (context, index) => itemBuilder(context, dados.itens[index]),
      rodape: rodapeDePaginacao(ref, consulta, dados, largura: 110),
    );
  }
}

/// Rodapé de uma lista paginada: some quando não há mais páginas; mostra o
/// indicador de carregamento (que **dispara** a próxima página ao ser
/// construído, isto é, quando a rolagem chega perto dele) ou, se a página
/// falhou, o botão de tentar de novo — sem tirar o que já foi carregado.
Widget? rodapeDePaginacao(
  WidgetRef ref,
  ConsultaPecas consulta,
  PecasPaginadas dados, {
  double? largura,
}) {
  void carregar() =>
      ref.read(pecasPaginadasProvider(consulta).notifier).carregarMais();

  if (dados.erroProximaPagina != null) {
    return SizedBox(
      width: largura,
      child: Center(
        child: TextButton.icon(
          onPressed: carregar,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      ),
    );
  }
  if (!dados.temMais) return null;
  return _GatilhoDeProximaPagina(
    // Uma instância nova por página, para o gatilho disparar de novo.
    key: ValueKey('gatilho-${dados.recebidas}'),
    largura: largura,
    aoConstruir: carregar,
  );
}

class _GatilhoDeProximaPagina extends StatefulWidget {
  const _GatilhoDeProximaPagina(
      {super.key, required this.aoConstruir, this.largura});

  final VoidCallback aoConstruir;
  final double? largura;

  @override
  State<_GatilhoDeProximaPagina> createState() =>
      _GatilhoDeProximaPaginaState();
}

class _GatilhoDeProximaPaginaState extends State<_GatilhoDeProximaPagina> {
  @override
  void initState() {
    super.initState();
    // Fora da construção: o provider não pode mudar durante o build.
    Future.microtask(() {
      if (mounted) widget.aoConstruir();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.largura,
      height: 48,
      child: const Center(
        child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

/// Mensagem de erro de carregamento do armário (usada por todas as telas
/// que listam peças).
String mensagemDeErroArmario(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return 'Sessão expirada ou inválida. Não foi possível carregar seu armário.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível carregar seu armário. Tente novamente.';
    }
  }
  return 'Não foi possível carregar seu armário. Tente novamente.';
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.aoTentarNovamente});

  final String mensagem;
  final VoidCallback aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text(mensagem, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AppButton(
                    label: 'Tentar novamente', onPressed: aoTentarNovamente),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErroDoCarrossel extends StatelessWidget {
  const _ErroDoCarrossel(
      {required this.titulo, required this.aoTentarNovamente});

  final String titulo;
  final VoidCallback aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Não foi possível carregar $titulo.')),
          TextButton(
              onPressed: aoTentarNovamente,
              child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
