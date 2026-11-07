// Paginação do armário (Épico 11): provider paginado, armário, gaveta, montar
// look, editar peças do look e escolher par. O servidor é falso (`PaginaDaLista`),
// nunca bate numa API real. Ver docs/PBIs/E11-paginacao-do-armario/.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/constants/peca_opcoes.dart';
import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/editar_pecas_look_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_view.dart';
import 'package:guarda_roupa_app/views/preferences/escolher_par_view.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart';
import 'package:guarda_roupa_app/views/upload/peca_form_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/gaveta_view.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_controller.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_view.dart';
import 'package:guarda_roupa_app/models/evitadas.dart';
import 'package:guarda_roupa_app/services/preferencia_service.dart';

import 'support/look_service_sem_historico.dart';
import 'support/pagina_da_lista.dart';

Peca _camiseta(int n, {String? cor}) => Peca(
      id: 'c${n.toString().padLeft(2, '0')}',
      imagemUrl: '/uploads/c${n.toString().padLeft(2, '0')}.png',
      categoria: 'Camisetas',
      corPrincipal: cor,
    );

/// Armário em memória, do mais novo para o mais antigo (como o servidor).
class _Armario extends PecaService with PaginaDaLista {
  _Armario(this.pecas);

  List<Peca> pecas;

  /// Se devolver `true`, a página pedida falha (erro de rede).
  bool Function(ConsultaPecas consulta, int deslocamento)? falharQuando;

  @override
  Future<List<Peca>> listarPecas() async => pecas;

  @override
  Future<PaginaDePecas> listarPagina(
    ConsultaPecas consulta, {
    required int limite,
    int deslocamento = 0,
  }) async {
    if (falharQuando?.call(consulta, deslocamento) ?? false) {
      throw DioException(
        requestOptions: RequestOptions(path: '/pecas'),
        type: DioExceptionType.connectionError,
      );
    }
    return super.listarPagina(consulta, limite: limite, deslocamento: deslocamento);
  }

  /// Páginas pedidas de uma categoria, pelo deslocamento.
  List<int> deslocamentosDe(String categoria) => [
        for (final p in paginasPedidas)
          if (p.consulta.categorias.contains(categoria) && p.limite > 1) p.deslocamento,
      ];
}

List<Peca> _armarioGrande() => [
      for (var n = 45; n >= 1; n--) _camiseta(n),
      Peca(id: 'k1', imagemUrl: '/uploads/k1.png', categoria: 'Calças', corPrincipal: 'Preto'),
      Peca(id: 's1', imagemUrl: '/uploads/s1.png', categoria: 'Sapatos'),
    ];

Future<void> _tela(WidgetTester tester, Widget tela, _Armario servidor,
    {List<Override> extras = const []}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pecaServiceProvider.overrideWithValue(servidor), ...extras],
      child: MaterialApp(home: tela),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _carta(String id) => find.byWidgetPredicate(
      (w) => w is ClothingCard && w.imagemUrl == '/uploads/$id.png',
    );

/// Rola o carrossel horizontal da seção [titulo] até a peça [id] aparecer.
Future<void> _rolarAte(WidgetTester tester, String titulo, String id) async {
  final carrossel = find.descendant(
    of: find.ancestor(of: find.textContaining(titulo), matching: find.byType(Column)).first,
    matching: find.byType(ListView),
  );
  await tester.dragUntilVisible(_carta(id), carrossel.first, const Offset(-300, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('PecasPaginadasNotifier (E11.F1.2)', () {
    late _Armario servidor;
    late ProviderContainer container;
    const consulta = ConsultaPecas(categorias: {'Camisetas'});

    setUp(() {
      servidor = _Armario(_armarioGrande());
      container = ProviderContainer(
        overrides: [pecaServiceProvider.overrideWithValue(servidor)],
      );
      addTearDown(container.dispose);
    });

    PecasPaginadas? estado() => container.read(pecasPaginadasProvider(consulta)).valueOrNull;
    Future<void> carregarMais() =>
        container.read(pecasPaginadasProvider(consulta).notifier).carregarMais();

    test('traz 20 por vez, informa o total e para na última página sem pedir mais', () async {
      await container.read(pecasPaginadasProvider(consulta).future);
      expect(estado()!.itens, hasLength(20));
      expect(estado()!.total, 45);
      expect(estado()!.temMais, isTrue);

      await carregarMais();
      await carregarMais();
      expect(estado()!.itens, hasLength(45));
      expect(estado()!.temMais, isFalse);

      await carregarMais(); // não há mais: não pede nada
      expect(servidor.deslocamentosDe('Camisetas'), [0, 20, 40]);
    });

    test('dois pedidos ao mesmo tempo viram uma página só', () async {
      await container.read(pecasPaginadasProvider(consulta).future);

      await Future.wait([carregarMais(), carregarMais(), carregarMais()]);

      expect(servidor.deslocamentosDe('Camisetas'), [0, 20]);
      expect(estado()!.itens.map((p) => p.id).toSet(), hasLength(40));
    });

    test('peça nova entre as páginas repete um item na resposta, mas a tela não', () async {
      await container.read(pecasPaginadasProvider(consulta).future);
      // Chegou uma peça por cima: tudo desce uma posição e a c26 vem de novo.
      servidor.pecas = [_camiseta(46), ...servidor.pecas];

      await carregarMais();

      final ids = estado()!.itens.map((p) => p.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'nenhum id repetido');
      expect(ids, hasLength(20 + 20 - 1));
      expect(estado()!.recebidas, 40, reason: 'o deslocamento conta o que o servidor mandou');
    });

    test('erro na página seguinte mantém o que já veio e tentar de novo continua dali', () async {
      await container.read(pecasPaginadasProvider(consulta).future);
      servidor.falharQuando = (_, deslocamento) => deslocamento == 20;

      await carregarMais();

      expect(estado()!.itens, hasLength(20));
      expect(estado()!.erroProximaPagina, isNotNull);
      expect(estado()!.carregandoMais, isFalse);

      servidor.falharQuando = null;
      await carregarMais();

      expect(estado()!.itens, hasLength(40));
      expect(estado()!.erroProximaPagina, isNull);
    });

    test('filtro mudado é outra consulta: recomeça do zero com o total filtrado', () async {
      servidor.pecas = [
        for (var n = 30; n >= 1; n--) _camiseta(n, cor: n.isEven ? 'Preto' : 'Azul'),
      ];
      final azuis = consulta.comFiltro(const FiltroPecas(cores: {'Azul'}));

      final dados = await container.read(pecasPaginadasProvider(azuis).future);

      expect(dados.total, 15);
      expect(dados.itens, hasLength(15));
      expect(dados.temMais, isFalse);
    });
  });

  group('Armário (E11.F1.2)', () {
    testWidgets('cada gaveta carrega só a primeira página e mostra o total', (tester) async {
      final servidor = _Armario(_armarioGrande());
      await _tela(tester, const WardrobeView(), servidor);

      expect(find.text('Partes de cima (45)'), findsOneWidget);
      expect(find.text('Partes de baixo (1)'), findsOneWidget);
      expect(find.text('Sapatos (1)'), findsOneWidget);
      expect(servidor.deslocamentosDe('Camisetas'), [0]);
      expect(find.text('47 peças'), findsOneWidget);
    });

    testWidgets('rolar o carrossel até o fim pede a página seguinte', (tester) async {
      final servidor = _Armario(_armarioGrande());
      await _tela(tester, const WardrobeView(), servidor);

      await _rolarAte(tester, 'Partes de cima', 'c25');

      expect(servidor.deslocamentosDe('Camisetas'), contains(20));
      expect(_carta('c25'), findsOneWidget);
    });

    testWidgets('gaveta que falha mostra o erro só nela, com "tentar novamente"', (tester) async {
      final servidor = _Armario(_armarioGrande())
        ..falharQuando = (consulta, _) => consulta.categorias.contains('Sapatos');
      await _tela(tester, const WardrobeView(), servidor);

      expect(find.text('Partes de cima (45)'), findsOneWidget);
      expect(find.text('Não foi possível carregar Sapatos.'), findsOneWidget);

      servidor.falharQuando = null;
      await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Sapatos (1)'), findsOneWidget);
      expect(find.textContaining('Não foi possível carregar'), findsNothing);
    });

    testWidgets('sem nenhuma peça mostra a orientação do armário vazio', (tester) async {
      await _tela(tester, const WardrobeView(), _Armario([]));

      expect(find.text('Seu armário está vazio'), findsOneWidget);
    });
  });

  group('Gaveta com rolagem infinita (E11.F1.3)', () {
    testWidgets('carrega as páginas até o fim e não pede mais depois da última', (tester) async {
      final servidor = _Armario(_armarioGrande());
      await _tela(tester, GavetaView(gaveta: gavetasDoArmario.first), servidor);

      expect(servidor.deslocamentosDe('Camisetas'), [0, 20, 40]);
      expect(find.text('45 peças'), findsOneWidget);
      expect(find.text('Camisetas (45)'), findsOneWidget);
    });

    testWidgets('erro na página seguinte mantém as peças e oferece tentar de novo', (tester) async {
      final servidor = _Armario(_armarioGrande())
        ..falharQuando = (_, deslocamento) => deslocamento == 20;
      await _tela(tester, GavetaView(gaveta: gavetasDoArmario.first), servidor);

      expect(find.text('Camisetas (20)'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);

      servidor.falharQuando = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Camisetas (45)'), findsOneWidget);
    });

    testWidgets('filtro ativo pagina só as peças filtradas e o rótulo mostra "de M"', (tester) async {
      final servidor = _Armario([
        for (var n = 30; n >= 1; n--) _camiseta(n, cor: n.isEven ? 'Preto' : 'Azul'),
      ]);
      await _tela(
        tester,
        GavetaView(gaveta: gavetasDoArmario.first),
        servidor,
        extras: [
          filtroArmarioProvider.overrideWith((ref) => const FiltroPecas(cores: {'Azul'})),
        ],
      );

      expect(find.text('15 peças de 30'), findsOneWidget);
      expect(find.text('Camisetas (15)'), findsOneWidget);
    });
  });

  group('Montar look com peças paginadas (E11.F2.1)', () {
    late _LookServiceCriando looks;

    setUp(() => looks = _LookServiceCriando());

    Future<void> abrir(WidgetTester tester, _Armario servidor) => _tela(
          tester,
          const MontarLookView(),
          servidor,
          extras: [lookServiceProvider.overrideWithValue(looks)],
        );

    testWidgets('escolhe peça de uma página posterior e salva exatamente as escolhidas', (
      tester,
    ) async {
      await abrir(tester, _Armario(_armarioGrande()));

      await tester.tap(_carta('c45'));
      await _rolarAte(tester, 'Camisetas', 'c25');
      await tester.tap(_carta('c25'));
      await tester.pump();
      expect(find.text('2 peças selecionadas'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Look misto');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
      await tester.pumpAndSettle();

      expect(looks.criados.single.$2, unorderedEquals(['c45', 'c25']));
    });

    testWidgets('a seleção continua ao rolar de volta e ao aplicar um filtro', (tester) async {
      await abrir(tester, _Armario(_armarioGrande()));
      await _rolarAte(tester, 'Camisetas', 'c25');
      await tester.tap(_carta('c25'));
      await tester.pump();

      await tester.dragUntilVisible(
        _carta('c45'),
        find.descendant(
          of: find.ancestor(of: find.textContaining('Camisetas'), matching: find.byType(Column)).first,
          matching: find.byType(ListView),
        ).first,
        const Offset(300, 0),
      );
      expect(find.text('1 peça selecionada'), findsOneWidget);

      // Um filtro que esconde a peça escolhida (ela não tem a cor) não a desmarca.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(RegExp(r'^Ver ')));
      await tester.pumpAndSettle();

      expect(find.text('1 peça selecionada'), findsOneWidget);
    });
  });

  group('Editar peças do look com peças paginadas (E11.F2.1)', () {
    testWidgets('as peças do look vêm marcadas mesmo sem estarem na primeira página', (
      tester,
    ) async {
      final servidor = _Armario(_armarioGrande());
      final look = Look(
        id: 'l1',
        nome: 'Look antigo',
        criadoEm: DateTime(2026),
        pecas: [_camiseta(30)], // fica na segunda página
      );
      await _tela(tester, EditarPecasLookView(look: look), servidor);

      expect(find.text('1 peça selecionada'), findsOneWidget);
      expect(_carta('c30'), findsNothing, reason: 'ainda não foi carregada');
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar')).onPressed,
        isNull,
        reason: 'nada mudou',
      );

      await _rolarAte(tester, 'Camisetas', 'c30');

      expect(tester.widget<ClothingCard>(_carta('c30')).selecionada, isTrue);
      expect(find.text('1 peça selecionada'), findsOneWidget);
    });
  });

  group('Formulário: subcategorias já usadas (E11.F2.3)', () {
    testWidgets('sugere as subcategorias da categoria escolhida, vindas da lista paginada', (
      tester,
    ) async {
      final servidor = _Armario([
        Peca(id: 'v1', imagemUrl: '/v1.png', categoria: 'Vestidos', subcategoria: 'Midi'),
        Peca(id: 'v2', imagemUrl: '/v2.png', categoria: 'Vestidos', subcategoria: 'midi'),
        Peca(id: 'v3', imagemUrl: '/v3.png', categoria: 'Vestidos', subcategoria: 'Longo'),
        Peca(id: 'k1', imagemUrl: '/k1.png', categoria: 'Calças', subcategoria: 'Jeans'),
      ]);
      await _tela(
        tester,
        const PecaFormView(imagemUrl: 'http://localhost:8000/uploads/f.png'),
        servidor,
      );
      expect(find.text('Já usadas:'), findsNothing, reason: 'sem categoria, sem sugestões');

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vestidos').last);
      await tester.pumpAndSettle();

      expect(find.text('Já usadas:'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Longo'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Midi'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Jeans'), findsNothing, reason: 'é de outra categoria');
      // Pediu só as peças da categoria escolhida, não o armário inteiro.
      expect(
        servidor.paginasPedidas.every((p) => p.consulta.categorias.contains('Vestidos')),
        isTrue,
      );
    });
  });

  group('Escolher par com peças paginadas (E11.F2.2)', () {
    testWidgets('permite peças de páginas diferentes e só habilita com exatamente duas', (
      tester,
    ) async {
      final preferencias = _PreferenciaServicePar();
      await _tela(
        tester,
        const EscolherParView(),
        _Armario(_armarioGrande()),
        extras: [preferenciaServiceProvider.overrideWithValue(preferencias)],
      );

      ElevatedButton botao() => tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));
      expect(botao().onPressed, isNull);

      await tester.tap(_carta('c45'));
      await _rolarAte(tester, 'Camisetas', 'c25');
      await tester.tap(_carta('c25'));
      await tester.pump();
      expect(find.textContaining('(2 de 2)'), findsOneWidget);
      expect(botao().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));
      await tester.pumpAndSettle();

      expect(preferencias.pedidos.single, ('c45', 'c25'));
    });

    testWidgets('armário com menos de 2 peças mostra a orientação', (tester) async {
      await _tela(tester, const EscolherParView(), _Armario([_camiseta(1)]));

      expect(find.textContaining('Cadastre pelo menos duas peças'), findsOneWidget);
    });
  });
}

class _LookServiceCriando extends LookServiceSemHistorico {
  final criados = <(String, List<String>)>[];

  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    criados.add((nome, pecaIds));
    return Look(id: 'novo', nome: nome, criadoEm: DateTime(2026), pecas: const []);
  }
}

class _PreferenciaServicePar extends PreferenciaService {
  final pedidos = <(String, String)>[];

  @override
  Future<Evitadas> listarEvitadas() async => const Evitadas();

  @override
  Future<({CombinacaoEvitada par, bool jaExistia})> evitarCombinacao(
    String pecaAId,
    String pecaBId,
  ) async {
    pedidos.add((pecaAId, pecaBId));
    return (
      par: CombinacaoEvitada(id: 'par1', pecas: [_camiseta(1), _camiseta(25)]),
      jaExistia: false,
    );
  }
}
