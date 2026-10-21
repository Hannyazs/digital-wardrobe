// Testes da listagem dos looks salvos (E3.F1.3).
// Mesmo padrão dos demais: LookService falso, nunca bate numa API real.
// Ver docs/PBIs/E3-F1-montagem-manual-looks/E3.F1.3-listagem-dos-looks-salvos.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/look_service.dart';
import 'support/look_service_sem_historico.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_controller.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

Peca _peca(String id) => Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: 'Camisetas');

Look _look(String id, String nome, List<String> pecaIds, {bool favorito = false}) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      pecas: pecaIds.map(_peca).toList(),
      favorito: favorito,
    );

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _LookServiceLento extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return [];
  }
}

class _LookServiceVazio extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];
}

class _LookServiceComDados extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [
        _look('1', 'Look de sexta', ['1', '2']),
        _look('2', 'Look da faculdade', ['3']),
      ];
}

class _LookServiceComErro extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async {
    throw DioException(
      requestOptions: RequestOptions(path: '/looks'),
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
  ocasiaoTests();
  filtroOcasiaoTests();
  usoTests();

  testWidgets('Mostra indicador de carregamento enquanto busca os looks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceLento()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Mostra orientação para montar o primeiro look quando não há nenhum', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Você ainda não tem nenhum look salvo'), findsOneWidget);
    expect(find.text('Toque em "Montar look" para criar o primeiro'), findsOneWidget);
  });

  testWidgets('Mostra os looks salvos com nome e miniaturas das peças', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceComDados()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Look de sexta'), findsOneWidget);
    expect(find.text('Look da faculdade'), findsOneWidget);
    // 2 peças no primeiro look + 1 no segundo = 3 miniaturas.
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('Mostra erro com "Tentar novamente" quando a busca falha', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceComErro()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('Tocar no coração favorita o look e o ícone fica preenchido', (
    WidgetTester tester,
  ) async {
    final service = _LookServiceFavoritos([
      _look('1', 'Look de sexta', ['1']),
    ]);
    await _abrir(tester, service);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(service.patches.map((p) => '${p.$1}:${p.$2}'), [
      '1:{favorito: true}',
    ]);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('Tocar no coração de um favorito remove o favorito', (
    WidgetTester tester,
  ) async {
    final service = _LookServiceFavoritos([
      _look('1', 'Look de sexta', ['1'], favorito: true),
    ]);
    await _abrir(tester, service);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(service.patches.map((p) => '${p.$1}:${p.$2}'), [
      '1:{favorito: false}',
    ]);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('Filtro "Favoritos" restringe a lista e desativar restaura', (
    WidgetTester tester,
  ) async {
    final service = _LookServiceFavoritos([
      _look('1', 'Look de sexta', ['1'], favorito: true),
      _look('2', 'Look da faculdade', ['2']),
    ]);
    await _abrir(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Look de sexta'), findsOneWidget);
    expect(find.text('Look da faculdade'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Look da faculdade'), findsOneWidget);
  });

  testWidgets('Filtro ativo sem favoritos mostra vazio-por-filtro e "Limpar filtro" restaura', (
    WidgetTester tester,
  ) async {
    final service = _LookServiceFavoritos([
      _look('1', 'Look de sexta', ['1']),
    ]);
    await _abrir(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum look favorito ainda'), findsOneWidget);
    expect(find.text('Você ainda não tem nenhum look salvo'), findsNothing);

    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Look de sexta'), findsOneWidget);
  });

  testWidgets('Falha no PATCH mostra SnackBar e mantém o coração', (
    WidgetTester tester,
  ) async {
    final service = _LookServiceFavoritos([
      _look('1', 'Look de sexta', ['1']),
    ])..falhar = true;
    await _abrir(tester, service);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível atualizar o look.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });
}

/// Fake com estado: `atualizarLook` altera a lista devolvida por `listarLooks`,
/// como o backend faria.
class _LookServiceFavoritos extends LookServiceSemHistorico {
  _LookServiceFavoritos(this.looks);

  List<Look> looks;
  bool falhar = false;
  final patches = <(String, Map<String, dynamic>)>[];

  @override
  Future<List<Look>> listarLooks() async => List.of(looks);

  @override
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    patches.add((id, campos));
    final atual = looks.firstWhere((l) => l.id == id);
    final novo = _look(
      id,
      atual.nome,
      atual.pecas.map((p) => p.id).toList(),
      favorito: campos['favorito'] as bool,
    );
    looks = [for (final l in looks) l.id == id ? novo : l];
    return novo;
  }
}

Future<void> _abrir(WidgetTester tester, LookService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
        lookServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(home: LooksView()),
    ),
  );
  await tester.pumpAndSettle();
}

// --- E3.F3.2: ocasião no card e alteração pelo menu ---

Look _lookComOcasioes(String id, String nome, List<String> ocasioes) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      pecas: [_peca(id)],
      ocasioes: ocasioes,
    );

Look _lookComOcasiao(String id, String nome, String? ocasiao) =>
    _lookComOcasioes(id, nome, ocasiao == null ? const [] : [ocasiao]);

/// Fake com estado para `ocasioes`: o `PATCH` só altera a chave presente.
class _LookServiceOcasiao extends LookServiceSemHistorico {
  _LookServiceOcasiao(this.looks);

  List<Look> looks;
  bool falhar = false;
  final patches = <(String, Map<String, dynamic>)>[];

  @override
  Future<List<Look>> listarLooks() async => List.of(looks);

  @override
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    patches.add((id, campos));
    final atual = looks.firstWhere((l) => l.id == id);
    final novo = _lookComOcasioes(id, atual.nome, List<String>.from(campos['ocasioes'] as List));
    looks = [for (final l in looks) l.id == id ? novo : l];
    return novo;
  }
}

/// Abre "Alterar ocasião" (marcação múltipla), alterna as [alternar] (marca ou
/// desmarca), opcionalmente toca "Sem ocasião", e confirma em "Salvar".
Future<void> _alterarOcasioesPeloMenu(
  WidgetTester tester, {
  List<String> alternar = const [],
  bool semOcasiao = false,
}) async {
  // O sheet tem 10+ linhas e botões; a tela de teste padrão (800x600) não cabe.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alterar ocasião'));
  await tester.pumpAndSettle();
  for (final opcao in alternar) {
    await tester.tap(find.widgetWithText(CheckboxListTile, opcao));
    await tester.pump();
  }
  if (semOcasiao) {
    await tester.tap(find.text('Sem ocasião'));
    await tester.pump();
  }
  await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
  await tester.pumpAndSettle();
}

/// O painel com Favoritos + 10 ocasiões ocupa várias linhas; na tela de teste
/// padrão (800x600) a lista (`ListView.builder`) ficaria quase sem espaço.
void _telaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void filtroOcasiaoTests() {
  final trabalho = _lookComOcasiao('1', 'Look de trabalho', 'Trabalho');
  final festaFav = Look(
    id: '2',
    nome: 'Look de festa',
    criadoEm: DateTime(2026, 1, 1),
    pecas: [_peca('2')],
    favorito: true,
    ocasioes: const ['Festa', 'Casual'],
  );
  final sem = _lookComOcasiao('3', 'Look sem ocasião', null);
  final todos = [trabalho, festaFav, sem];

  test('filtrarLooks: ocasião sozinha, combinada, várias (OU) e look sem ocasião', () {
    List<String> nomes(FiltroLooks f) => filtrarLooks(todos, f).map((l) => l.nome).toList();

    expect(nomes(const FiltroLooks()), hasLength(3));
    expect(nomes(const FiltroLooks(ocasioes: {'Trabalho'})), ['Look de trabalho']);
    // Um look com várias ocasiões aparece por qualquer uma delas.
    expect(nomes(const FiltroLooks(ocasioes: {'Festa'})), ['Look de festa']);
    expect(nomes(const FiltroLooks(ocasioes: {'Casual'})), ['Look de festa']);
    // Várias ocasiões marcadas: OU entre elas.
    expect(
      nomes(const FiltroLooks(ocasioes: {'Trabalho', 'Festa'})),
      ['Look de trabalho', 'Look de festa'],
    );
    // E lógico com favoritos.
    expect(
      nomes(const FiltroLooks(ocasioes: {'Trabalho', 'Festa'}, somenteFavoritos: true)),
      ['Look de festa'],
    );
    expect(nomes(const FiltroLooks(ocasioes: {'Trabalho'}, somenteFavoritos: true)), isEmpty);
    // Look sem ocasião só aparece sem filtro de ocasião.
    expect(nomes(const FiltroLooks(ocasioes: {'Praia'})), isEmpty);
    expect(nomes(const FiltroLooks(somenteFavoritos: true)), ['Look de festa']);
  });

  test('FiltroLooks: alternarOcasiao marca e desmarca; ativo considera as ocasiões', () {
    const vazio = FiltroLooks();
    final com = vazio.alternarOcasiao('Festa').alternarOcasiao('Trabalho');
    expect(com.ocasioes, {'Festa', 'Trabalho'});
    expect(com.alternarOcasiao('Festa').ocasioes, {'Trabalho'});
    expect(com.alternarOcasiao('Festa').alternarOcasiao('Trabalho').ocasioes, isEmpty);
    expect(com.copyWith(somenteFavoritos: true).ocasioes, {'Festa', 'Trabalho'});
    expect(vazio.ativo, isFalse);
    expect(const FiltroLooks(ocasioes: {'Festa'}).ativo, isTrue);
  });

  testWidgets('Chips de ocasião filtram (várias de uma vez); tocar de novo desfaz', (tester) async {
    _telaGrande(tester);
    await _abrir(tester, _LookServiceOcasiao(todos));

    await tester.tap(find.widgetWithText(FilterChip, 'Trabalho'));
    await tester.pumpAndSettle();
    expect(find.text('Look de trabalho'), findsOneWidget);
    expect(find.text('Look de festa'), findsNothing);
    expect(find.text('Look sem ocasião'), findsNothing);

    // Segunda ocasião marcada sem desmarcar a primeira: OU entre elas.
    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pumpAndSettle();
    expect(find.text('Look de trabalho'), findsOneWidget);
    expect(find.text('Look de festa'), findsOneWidget);
    expect(find.text('Look sem ocasião'), findsNothing);

    // Desmarcar uma mantém a outra; desmarcar as duas restaura tudo.
    await tester.tap(find.widgetWithText(FilterChip, 'Trabalho'));
    await tester.pumpAndSettle();
    expect(find.text('Look de trabalho'), findsNothing);
    expect(find.text('Look de festa'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pumpAndSettle();
    expect(find.text('Look de trabalho'), findsOneWidget);
    expect(find.text('Look sem ocasião'), findsOneWidget);
  });

  testWidgets('Dois toques seguidos nos chips, sem rebuild entre eles, mantêm os dois filtros', (
    tester,
  ) async {
    _telaGrande(tester);
    await _abrir(tester, _LookServiceOcasiao(todos));

    // Sem `pump()` entre os toques: o segundo não pode partir do filtro antigo.
    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pumpAndSettle();

    expect(find.text('Look de festa'), findsOneWidget);
    expect(find.text('Look de trabalho'), findsNothing);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Favoritos')).selected, isTrue);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Festa')).selected, isTrue);
  });

  testWidgets('Favoritos + ocasiões sem correspondência mostra vazio e "Limpar filtros" restaura', (
    tester,
  ) async {
    _telaGrande(tester);
    await _abrir(tester, _LookServiceOcasiao(todos));

    await tester.tap(find.widgetWithText(FilterChip, 'Favoritos'));
    await tester.tap(find.widgetWithText(FilterChip, 'Trabalho'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum look favorito da ocasião "Trabalho"'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Praia'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum look favorito das ocasiões "Trabalho", "Praia"'), findsOneWidget);

    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Look de trabalho'), findsOneWidget);
    expect(find.text('Look de festa'), findsOneWidget);
    expect(find.text('Look sem ocasião'), findsOneWidget);
  });
}

void ocasiaoTests() {
  testWidgets('Card mostra um chip por ocasião e nenhum quando o look não tem', (tester) async {
    await _abrir(
      tester,
      _LookServiceOcasiao([
        _lookComOcasioes('1', 'Look de sexta', ['Trabalho', 'Faculdade']),
        _lookComOcasiao('2', 'Look da festa', null),
      ]),
    );

    expect(find.widgetWithText(Chip, 'Trabalho'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Faculdade'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(2));
  });

  testWidgets('"Alterar ocasião" marca mais de uma e os chips acompanham', (tester) async {
    final service = _LookServiceOcasiao([_lookComOcasiao('1', 'Look de sexta', 'Trabalho')]);
    await _abrir(tester, service);

    await _alterarOcasioesPeloMenu(tester, alternar: ['Festa', 'Casual']);

    // Ordem canônica de `ocasioesFixas` (Casual, Trabalho, ..., Festa), não a do toque.
    expect(service.patches.single.$2['ocasioes'], ['Casual', 'Trabalho', 'Festa']);
    expect(find.widgetWithText(Chip, 'Casual'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Trabalho'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Festa'), findsOneWidget);
  });

  testWidgets('O sheet abre com as ocasiões atuais marcadas e permite trocar uma por outra', (
    tester,
  ) async {
    final service = _LookServiceOcasiao([
      _lookComOcasioes('1', 'Look de sexta', ['Trabalho', 'Faculdade']),
    ]);
    await _abrir(tester, service);

    await _alterarOcasioesPeloMenu(tester, alternar: ['Trabalho', 'Festa']);

    expect(service.patches.single.$2['ocasioes'], ['Faculdade', 'Festa']);
    expect(find.widgetWithText(Chip, 'Trabalho'), findsNothing);
    expect(find.widgetWithText(Chip, 'Faculdade'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Festa'), findsOneWidget);
  });

  testWidgets('"Sem ocasião" envia lista vazia (não null) e os chips somem', (tester) async {
    final service = _LookServiceOcasiao([
      _lookComOcasioes('1', 'Look de sexta', ['Trabalho', 'Festa']),
    ]);
    await _abrir(tester, service);

    await _alterarOcasioesPeloMenu(tester, semOcasiao: true);

    expect(service.patches.single.$2.containsKey('ocasioes'), isTrue);
    expect(service.patches.single.$2['ocasioes'], isEmpty);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('Ocasião salva fora da lista fixa aparece marcada e é mantida', (tester) async {
    final service = _LookServiceOcasiao([
      _lookComOcasioes('1', 'Look de sexta', ['Sobretudo']),
    ]);
    await _abrir(tester, service);

    await _alterarOcasioesPeloMenu(tester, alternar: ['Festa']);

    expect(service.patches.single.$2['ocasioes'], ['Festa', 'Sobretudo']);
  });

  testWidgets('Fechar o sheet sem salvar não envia nada', (tester) async {
    final service = _LookServiceOcasiao([_lookComOcasiao('1', 'Look de sexta', 'Trabalho')]);
    await _abrir(tester, service);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alterar ocasião'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // toque fora do sheet: dispensa
    await tester.pumpAndSettle();

    expect(service.patches, isEmpty);
    expect(find.widgetWithText(Chip, 'Trabalho'), findsOneWidget);
  });

  testWidgets('Falha ao alterar as ocasiões mostra SnackBar e mantém os chips', (tester) async {
    final service = _LookServiceOcasiao([_lookComOcasiao('1', 'Look de sexta', 'Trabalho')])
      ..falhar = true;
    await _abrir(tester, service);

    await _alterarOcasioesPeloMenu(tester, alternar: ['Festa']);

    expect(
      find.text('Sem conexão com o servidor. Não foi possível atualizar o look.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(Chip, 'Trabalho'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Festa'), findsNothing);
  });
}

// --- E3.F4.2: registrar uso do look pelo menu do card ---

class _LookServiceUso extends LookServiceSemHistorico {
  _LookServiceUso(this.looks, {this.status});

  final List<Look> looks;

  /// Quando definido, `registrarUso` falha com esse status HTTP; `0` simula
  /// falta de conexão.
  final int? status;
  final usos = <(String, DateTime)>[];

  @override
  Future<List<Look>> listarLooks() async => looks;

  @override
  Future<void> registrarUso(String lookId, DateTime data) async {
    if (status != null) {
      final opts = RequestOptions(path: '/looks/$lookId/usos');
      throw status == 0
          ? DioException(requestOptions: opts, type: DioExceptionType.connectionError)
          : DioException(
              requestOptions: opts,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: opts, statusCode: status),
            );
    }
    usos.add((lookId, data));
  }
}

Future<void> _abrirMenuDoCard(WidgetTester tester, String item) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void usoTests() {
  final look = _lookComOcasiao('1', 'Look de sexta', null);
  bool mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  test('formatarDataApi usa só a data local, com zeros à esquerda', () {
    expect(formatarDataApi(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(formatarDataApi(DateTime(2026, 10, 18)), '2026-10-18');
  });

  testWidgets('"Usei hoje" registra o uso com a data de hoje e confirma', (tester) async {
    final service = _LookServiceUso([look]);
    await _abrir(tester, service);

    await _abrirMenuDoCard(tester, 'Usei hoje');

    expect(service.usos, hasLength(1));
    expect(service.usos.single.$1, '1');
    expect(mesmoDia(service.usos.single.$2, DateTime.now()), isTrue);
    expect(find.text('Uso de "Look de sexta" registrado para hoje.'), findsOneWidget);
  });

  testWidgets('"Usei em outra data…" registra a data escolhida no seletor', (tester) async {
    final service = _LookServiceUso([look]);
    await _abrir(tester, service);
    final hoje = DateTime.now();
    // Dia anterior no mesmo mês; no dia 1º não há "anterior" no mesmo mês, então
    // o próprio dia 1 (= hoje) é confirmado.
    final alvo = hoje.day > 1 ? hoje.day - 1 : hoje.day;

    await _abrirMenuDoCard(tester, 'Usei em outra data…');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('$alvo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(service.usos, hasLength(1));
    final enviada = service.usos.single.$2;
    expect(enviada.day, alvo);
    expect(enviada.month, hoje.month);
    expect(find.textContaining('Uso de "Look de sexta" registrado em '), findsOneWidget);
  });

  testWidgets('Cancelar o seletor de data não envia nada', (tester) async {
    final service = _LookServiceUso([look]);
    await _abrir(tester, service);

    await _abrirMenuDoCard(tester, 'Usei em outra data…');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.usos, isEmpty);
    expect(find.textContaining('registrado'), findsNothing);
  });

  for (final (status, mensagem) in [
    (0, 'Sem conexão com o servidor. Não foi possível registrar o uso.'),
    (401, 'Sessão expirada ou inválida. Não foi possível registrar o uso.'),
    (404, 'Look não encontrado. Atualize a lista e tente novamente.'),
    (500, 'Não foi possível registrar o uso. Tente novamente.'),
  ]) {
    testWidgets('Falha no POST ($status) mostra mensagem clara e a tela segue utilizável', (
      tester,
    ) async {
      await _abrir(tester, _LookServiceUso([look], status: status));

      await _abrirMenuDoCard(tester, 'Usei hoje');

      expect(find.text(mensagem), findsOneWidget);
      expect(find.text('Look de sexta'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  }
}
