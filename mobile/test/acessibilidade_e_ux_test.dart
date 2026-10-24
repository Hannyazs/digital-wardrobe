// Ajustes de UX e acessibilidade (docs/redesign-visual.md, Etapa 8): leitor de
// tela, área de toque, fonte grande do sistema, formulário e montagem.
// Serviços falsos, nunca bate numa API real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/constants/peca_opcoes.dart' show gavetasDoArmario;
import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/looks/montar_look_view.dart';
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart'
    show sugestaoServiceProvider;
import 'package:guarda_roupa_app/views/upload/peca_form_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_controller.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_view.dart';

import 'support/look_service_sem_historico.dart';
import 'support/sugestao_service_sem_look_do_dia.dart';

final _pecas = [
  Peca(id: 'c1', imagemUrl: '/c1.png', categoria: 'Camisetas', corPrincipal: 'Branco'),
  Peca(
    id: 'p1',
    imagemUrl: '/p1.png',
    categoria: 'Calças',
    subcategoria: 'Jeans',
    corPrincipal: 'Preto',
  ),
  Peca(id: 'v1', imagemUrl: '/v1.png', categoria: 'Vestidos', subcategoria: 'Midi'),
  Peca(id: 'v2', imagemUrl: '/v2.png', categoria: 'Vestidos', subcategoria: 'midi '),
];

class _PecaServiceFake extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => _pecas;
}

class _LookServiceComUmLook extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [
        Look(id: 'l1', nome: 'Look de sexta', criadoEm: DateTime(2026), pecas: _pecas.take(2).toList()),
      ];
}

List<Override> _overrides() => [
      pecaServiceProvider.overrideWithValue(_PecaServiceFake()),
      lookServiceProvider.overrideWithValue(_LookServiceComUmLook()),
      sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
    ];

Future<void> _abrir(WidgetTester tester, Widget home, {double escalaTexto = 1}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escalaTexto)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Leitor de tela', () {
    testWidgets('Cards do armário dizem que peça é', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester, const WardrobeView());

      expect(find.bySemanticsLabel('Calças, Jeans, preto'), findsOneWidget);
      expect(find.bySemanticsLabel('Camisetas, branco'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('Na montagem, o card anuncia se a peça está selecionada', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester, const MontarLookView());

      final card = find.bySemanticsLabel('Camisetas, branco');
      expect(tester.getSemantics(card), isSemantics(isSelected: false, isButton: true));
      await tester.tap(find.byType(ClothingCard).first);
      await tester.pump();
      expect(tester.getSemantics(card), isSemantics(isSelected: true));
      semantica.dispose();
    });

    testWidgets('Botão de filtros tem texto e anuncia quantos estão marcados', (tester) async {
      await _abrir(tester, const WardrobeView());

      expect(find.text('Filtros'), findsOneWidget);
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver 1 peça'));
      await tester.pumpAndSettle();
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Filtros, 1 marcados'), findsOneWidget);
      semantica.dispose();
    });
  });

  testWidgets('Título da gaveta tem área de toque de pelo menos 48 px e "Ver tudo"', (tester) async {
    await _abrir(tester, const WardrobeView());

    expect(find.text('Ver tudo'), findsWidgets);
    final area = find.ancestor(of: find.text('Partes de baixo (1)'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(area).height, greaterThanOrEqualTo(48));
  });

  testWidgets('Subcategorias "Midi" e "midi " viram uma seção só na gaveta', (tester) async {
    final vestidos = gavetasDoArmario.firstWhere((g) => g.nome == 'Vestidos');
    expect(secoesDaGaveta(vestidos, _pecas).keys.toList(), ['Midi']);
    expect(secoesDaGaveta(vestidos, _pecas)['Midi'], hasLength(2));
  });

  group('Fonte grande do sistema (2×) não quebra as telas', () {
    for (final (nome, tela) in [
      ('Casa, Armário e Montar (barra inferior)', const HomeShell()),
      ('Montagem', const MontarLookView()),
      ('Looks salvos', const LooksView()),
    ]) {
      testWidgets(nome, (tester) async {
        await _abrir(tester, tela, escalaTexto: 2);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Cadastro de peça', () {
    testWidgets('Salvar sem categoria avisa e mostra o campo', (tester) async {
      await _abrir(tester, const PecaFormView(imagemUrl: '/nova.png'));

      await tester.ensureVisible(find.text('Salvar peça'));
      await tester.tap(find.text('Salvar peça'));
      await tester.pumpAndSettle();

      expect(find.text('Revise o campo destacado.'), findsOneWidget);
      expect(find.text('Selecione uma categoria'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Selecione uma categoria')).dy, lessThan(2400));
    });

    testWidgets('Rótulos explicam cor principal e o que ajuda nas sugestões', (tester) async {
      await _abrir(tester, const PecaFormView(imagemUrl: '/nova.png'));

      expect(find.text('Cor principal'), findsOneWidget);
      expect(find.text('A cor que mais aparece na peça.'), findsOneWidget);
      expect(find.text('Cor, ocasião e estilo ajudam nas sugestões de looks.'), findsOneWidget);
      // Estações e ocasiões aceitam várias marcações.
      expect(find.text('Pode marcar várias.'), findsNWidgets(2));
    });

    testWidgets('Subcategorias já usadas na categoria viram atalhos', (tester) async {
      await _abrir(tester, const PecaFormView(imagemUrl: '/nova.png'));

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vestidos').last);
      await tester.pumpAndSettle();

      expect(find.text('Já usadas:'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Midi'), findsOneWidget); // "midi " não repete
      await tester.tap(find.widgetWithText(ActionChip, 'Midi'));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Midi'), findsOneWidget);
    });
  });

  group('Montagem', () {
    testWidgets('Explica por que "Salvar look" está desabilitado e mostra as escolhidas', (tester) async {
      await _abrir(tester, const MontarLookView());

      expect(find.text('Escolha as peças e dê um nome ao look.'), findsOneWidget);

      await tester.tap(find.byType(ClothingCard).first);
      await tester.pump();
      expect(find.text('Dê um nome ao look (campo no topo).'), findsOneWidget);
      // Fileira de miniaturas das escolhidas, acima do botão.
      final semantica = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Peças: Camisetas, branco'), findsOneWidget);
      semantica.dispose();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look novo');
      await tester.pump();
      expect(find.textContaining('Dê um nome'), findsNothing);
    });
  });

  testWidgets('Tocar no card de look abre o menu de ações', (tester) async {
    await _abrir(tester, const LooksView());

    await tester.tap(find.text('Look de sexta'));
    await tester.pumpAndSettle();

    expect(find.text('Usei hoje'), findsOneWidget);
    expect(find.text('Editar peças'), findsOneWidget);
  });

  testWidgets('Aba de montagem se chama "Montar" e os títulos estão em português', (tester) async {
    await _abrir(tester, const HomeShell());

    expect(find.text('Montar'), findsOneWidget);
    expect(find.text('Olá!'), findsOneWidget);
    await tester.tap(find.text('Sugestões'));
    await tester.pumpAndSettle();
    expect(find.text('Suas sugestões'), findsOneWidget);
    await tester.tap(find.text('Referências'));
    await tester.pumpAndSettle();
    expect(find.text('Inspirações'), findsOneWidget);
    expect(find.text('Seu mural de referências'), findsOneWidget);
  });
}
