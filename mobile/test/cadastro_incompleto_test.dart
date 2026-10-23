// Testes do aviso de cadastro incompleto (E5.F4.1). Serviços falsos, nunca bate numa API real.
// Ver docs/PBIs/E5-F4-cadastro-incompleto/E5.F4.1-aviso-de-cadastro-incompleto.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_view.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/peca_detail_view.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_view.dart';

import 'support/preferencia_service_sem_evitadas.dart';

Peca _peca(
  String id, {
  String categoria = 'Camisetas',
  String? cor = 'Azul',
  List<String> ocasioes = const ['Trabalho'],
  String? estilo = 'Casual',
  String? estacao,
}) =>
    Peca(
      id: id,
      imagemUrl: '/uploads/$id.png',
      categoria: categoria,
      corPrincipal: cor,
      ocasioes: ocasioes,
      estilos: estilo == null ? const [] : [estilo],
      estacoes: estacao == null ? const [] : [estacao],
    );

/// Fake com estado: `atualizarPeca` muda o que `listarPecas` devolve.
class _PecaServiceArmario extends PecaService {
  _PecaServiceArmario(this.pecas);

  List<Peca> pecas;

  @override
  Future<List<Peca>> listarPecas() async => List.of(pecas);

  @override
  Future<Peca> atualizarPeca({
    required String id,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    List<String> coresSecundarias = const [],
    List<String> estacoes = const [],
    List<String> estilos = const [],
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    final nova = Peca(
      id: id,
      imagemUrl: '/uploads/$id.png',
      categoria: categoria,
      corPrincipal: corPrincipal,
      estacoes: estacoes,
      estilos: estilos,
      ocasioes: ocasioes,
    );
    pecas = [for (final p in pecas) p.id == id ? nova : p];
    return nova;
  }
}

final _selo = find.byKey(const ValueKey('selo-cadastro-incompleto'));
final _faixa = find.byKey(const ValueKey('faixa-cadastro-incompleto'));

Future<void> _abrir(WidgetTester tester, PecaService service, Widget home) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pecaServiceProvider.overrideWithValue(service),
        preferenciaServiceProvider.overrideWithValue(PreferenciaServiceSemEvitadas()),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('camposIncompletos', () {
    test('peça completa não tem pendência; estação vazia não conta', () {
      expect(camposIncompletos(_peca('1')), isEmpty);
      expect(camposIncompletos(_peca('1', estacao: null)), isEmpty);
    });

    test('lista cor, ocasião e estilo nessa ordem quando faltam', () {
      expect(camposIncompletos(_peca('1', cor: null, ocasioes: const [], estilo: null)),
          ['cor', 'ocasião', 'estilo']);
      expect(camposIncompletos(_peca('1', estilo: '  ')), ['estilo']);
      expect(camposIncompletos(_peca('1', ocasioes: const [])), ['ocasião']);
    });

    test('cor fora da lista fixa conta como "sem cor", como no motor de sugestões', () {
      expect(camposIncompletos(_peca('1', cor: 'Azul petróleo')), ['cor']);
      expect(camposIncompletos(_peca('1', cor: '')), ['cor']);
    });
  });

  testWidgets('Armário: só a peça incompleta tem selo', (tester) async {
    await _abrir(
      tester,
      _PecaServiceArmario([_peca('completa'), _peca('sem-estilo', categoria: 'Calças', estilo: null)]),
      const WardrobeView(),
    );

    expect(_selo, findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('armario-lista-categorias')), matching: _selo),
        findsOneWidget);
  });

  testWidgets('Selo também aparece dentro da gaveta', (tester) async {
    await _abrir(tester, _PecaServiceArmario([_peca('1', cor: null)]), const WardrobeView());

    await tester.tap(find.text('Partes de cima (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gaveta-secoes')), findsOneWidget);
    expect(_selo, findsOneWidget);
  });

  testWidgets('Peça só sem estação: sem selo e sem faixa', (tester) async {
    final peca = _peca('1', estacao: null);
    await _abrir(tester, _PecaServiceArmario([peca]), const WardrobeView());
    expect(_selo, findsNothing);

    await tester.tap(find.byType(ClothingCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Detalhe da peça'), findsOneWidget);
    expect(_faixa, findsNothing);
  });

  testWidgets('Montagem de look não mostra o selo', (tester) async {
    await _abrir(tester, _PecaServiceArmario([_peca('1', estilo: null)]), const MontarLookView());
    expect(_selo, findsNothing);
  });

  testWidgets('Detalhe mostra a faixa com os campos que faltam', (tester) async {
    await _abrir(
      tester,
      _PecaServiceArmario(const []),
      PecaDetailView(peca: _peca('1', cor: null, estilo: null)),
    );

    expect(_faixa, findsOneWidget);
    expect(find.text('Cadastro incompleto: sem cor, estilo'), findsOneWidget);
  });

  testWidgets('"Editar" na faixa abre a edição; salvar completo tira selo e faixa', (tester) async {
    final service = _PecaServiceArmario([_peca('1', estilo: null)]);
    await _abrir(tester, service, const WardrobeView());
    expect(_selo, findsOneWidget);

    // Armário → detalhe → "Editar" da faixa.
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Cadastro incompleto: sem estilo'), findsOneWidget);
    await tester.tap(find.descendant(of: _faixa, matching: find.text('Editar')));
    await tester.pumpAndSettle();
    expect(find.text('Editar peça'), findsOneWidget); // formulário de edição

    // Preenche o estilo e salva: o formulário volta ao armário, já recarregado.
    await tester.tap(find.widgetWithText(FilterChip, 'Casual').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(service.pecas.single.estilos, ['Casual']);
    expect(find.text('Meu Armário'), findsOneWidget);
    expect(_selo, findsNothing);

    // Reabrindo o detalhe, a faixa sumiu.
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pumpAndSettle();
    expect(_faixa, findsNothing);
  });
}
