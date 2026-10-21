// Testes da categorização por opções predefinidas no formulário da peça
// (cor + tonalidade, estilo, modelagem, ocasiões múltiplas com "Outros") e da
// atualização automática do armário depois do cadastro.
// PecaService falso, nunca bate numa API real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/constants/peca_opcoes.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'support/look_service_sem_historico.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/peca_form_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

/// Guarda o que o formulário enviou e mantém um "banco" em memória, para
/// provar que o armário passa a mostrar a peça recém-criada.
class _PecaServiceFalso extends PecaService {
  _PecaServiceFalso([List<Peca>? iniciais]) : pecas = [...?iniciais];

  final List<Peca> pecas;
  Map<String, Object?>? ultimoEnvio;

  void _registrar(Map<String, Object?> envio) => ultimoEnvio = envio;

  @override
  Future<List<Peca>> listarPecas() async => [...pecas];

  @override
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    _registrar({
      'categoria': categoria,
      'cor': corPrincipal,
      'tonalidade': tonalidadeCor,
      'estacao': estacao,
      'estilo': estilo,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    });
    final peca = Peca(
      id: 'nova-${pecas.length}',
      imagemUrl: imagemUrl,
      categoria: categoria,
      corPrincipal: corPrincipal,
      tonalidadeCor: tonalidadeCor,
      ocasioes: ocasioes,
    );
    pecas.insert(0, peca);
    return peca;
  }

  @override
  Future<Peca> atualizarPeca({
    required String id,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    _registrar({
      'categoria': categoria,
      'cor': corPrincipal,
      'tonalidade': tonalidadeCor,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    });
    return Peca(id: id, imagemUrl: '/x.png', categoria: categoria, ocasioes: ocasioes);
  }
}

class _LookServiceVazio extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];
}

void _telaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrirForm(WidgetTester tester, PecaService service, {Peca? existente}) async {
  _telaAlta(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pecaServiceProvider.overrideWithValue(service),
        lookServiceProvider.overrideWithValue(_LookServiceVazio()),
      ],
      child: MaterialApp(
        home: PecaFormView(imagemUrl: 'http://localhost:8000/uploads/f.png', pecaExistente: existente),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _escolherCategoria(WidgetTester tester, String categoria) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(categoria).last);
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Type tipo, String texto) async {
  await tester.tap(find.byWidgetPredicate(
    (w) => w.runtimeType == tipo && (w as dynamic).label is Text && ((w as dynamic).label as Text).data == texto,
  ));
  await tester.pumpAndSettle();
}

bool _selecionado(WidgetTester tester, Type tipo, String texto) {
  final chip = tester.widget(find.byWidgetPredicate(
    (w) => w.runtimeType == tipo && (w as dynamic).label is Text && ((w as dynamic).label as Text).data == texto,
  ));
  return (chip as dynamic).selected as bool;
}

void main() {
  test('Tonalidade sugerida é consistente com a cor escolhida', () {
    expect(tonalidadeSugeridaPara('Azul-marinho'), 'Escura');
    expect(tonalidadeSugeridaPara('Azul-claro'), 'Pastel');
    expect(tonalidadeSugeridaPara('Cor inventada'), isNull);
    for (final cor in coresFixas) {
      expect(tonalidadesFixas, contains(cor.tonalidadeSugerida));
    }
  });

  testWidgets('Escolher a cor sugere a tonalidade, que pode ser trocada e é salva à parte', (
    WidgetTester tester,
  ) async {
    final service = _PecaServiceFalso();
    await _abrirForm(tester, service);
    await _escolherCategoria(tester, 'Camisetas');

    await _tocar(tester, ChoiceChip, 'Azul-marinho');
    expect(_selecionado(tester, ChoiceChip, 'Escura'), isTrue);

    await _tocar(tester, ChoiceChip, 'Neutra');
    expect(_selecionado(tester, ChoiceChip, 'Neutra'), isTrue);
    expect(_selecionado(tester, ChoiceChip, 'Escura'), isFalse);

    await _tocar(tester, ChoiceChip, 'Casual');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(service.ultimoEnvio!['cor'], 'Azul-marinho');
    expect(service.ultimoEnvio!['tonalidade'], 'Neutra');
    expect(service.ultimoEnvio!['estilo'], 'Casual');
  });

  testWidgets('Modelagem só aparece para categorias compatíveis e é limpa ao trocar', (
    WidgetTester tester,
  ) async {
    await _abrirForm(tester, _PecaServiceFalso());

    // Sem categoria escolhida ainda: não pergunta modelagem.
    expect(find.text('Modelagem'), findsNothing);

    await _escolherCategoria(tester, 'Camisetas');
    expect(find.text('Modelagem'), findsOneWidget);
    await _tocar(tester, ChoiceChip, 'Oversized');
    expect(_selecionado(tester, ChoiceChip, 'Oversized'), isTrue);

    await _escolherCategoria(tester, 'Sapatos');
    expect(find.text('Modelagem'), findsNothing);
  });

  testWidgets('Ocasiões: várias predefinidas salvam sem texto manual', (
    WidgetTester tester,
  ) async {
    final service = _PecaServiceFalso();
    await _abrirForm(tester, service);
    await _escolherCategoria(tester, 'Vestidos');

    await _tocar(tester, FilterChip, 'Trabalho');
    await _tocar(tester, FilterChip, 'Academia');
    await _tocar(tester, FilterChip, 'Viagem');
    expect(find.widgetWithText(TextFormField, 'Qual ocasião?'), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(service.ultimoEnvio!['ocasioes'], ['Trabalho', 'Academia', 'Viagem']);
  });

  testWidgets('Ocasiões: "Outros" exige texto e salva junto das predefinidas', (
    WidgetTester tester,
  ) async {
    final service = _PecaServiceFalso();
    await _abrirForm(tester, service);
    await _escolherCategoria(tester, 'Vestidos');

    await _tocar(tester, FilterChip, 'Praia');
    await _tocar(tester, FilterChip, ocasiaoOutros);
    expect(find.widgetWithText(TextFormField, 'Qual ocasião?'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Informe a ocasião'), findsOneWidget);
    expect(service.ultimoEnvio, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Qual ocasião?'), 'Casamento na serra');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(service.ultimoEnvio!['ocasioes'], ['Praia', 'Casamento na serra']);
  });

  testWidgets('Editar peça antiga: texto livre vira "Outros" preenchido e nada se perde', (
    WidgetTester tester,
  ) async {
    final service = _PecaServiceFalso();
    final antiga = Peca(
      id: 'p1',
      imagemUrl: '/x.png',
      categoria: 'Calças',
      corPrincipal: 'Cor antiga livre',
      ocasioes: ['Festa', 'shopping'],
    );
    await _abrirForm(tester, service, existente: antiga);

    expect(_selecionado(tester, FilterChip, 'Festa'), isTrue);
    expect(_selecionado(tester, FilterChip, ocasiaoOutros), isTrue);
    expect(find.text('shopping'), findsOneWidget);
    // A cor antiga (fora da lista) segue visível e selecionada.
    expect(_selecionado(tester, ChoiceChip, 'Cor antiga livre'), isTrue);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(service.ultimoEnvio!['ocasioes'], ['Festa', 'shopping']);
    expect(service.ultimoEnvio!['cor'], 'Cor antiga livre');
  });

  testWidgets('Depois de cadastrar, a peça nova já aparece no armário (sem recarregar)', (
    WidgetTester tester,
  ) async {
    _telaAlta(tester);
    final service = _PecaServiceFalso([
      Peca(id: 'a', imagemUrl: '/a.png', categoria: 'Camisetas'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(service),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Armário aberto uma vez (carrega a lista com 1 peça, em cache).
    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();
    expect(find.text('Vestidos (1)'), findsNothing);

    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => const PecaFormView(imagemUrl: 'http://localhost:8000/uploads/n.png'),
      ),
    );
    await tester.pumpAndSettle();

    await _escolherCategoria(tester, 'Vestidos');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();
    expect(find.text('Vestidos (1)'), findsOneWidget);
    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(service.pecas, hasLength(2));
  });
}
