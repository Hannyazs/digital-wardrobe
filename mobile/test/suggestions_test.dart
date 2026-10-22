// Testes da tela de sugestões (E5.F2.1) e das sugestões a partir de uma peça
// (E5.F2.2). Serviços falsos: nunca bate numa API real.
// Ver docs/PBIs/E5-F2-sugestoes-no-app/.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_view.dart';
import 'package:guarda_roupa_app/views/wardrobe/peca_detail_view.dart';
import 'support/look_service_sem_historico.dart';
import 'support/preferencia_service_sem_evitadas.dart';

Peca _peca(String id) => Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: 'Camisetas');

Sugestao _sugestao(int n) => Sugestao(
      pecas: [_peca('cima$n'), _peca('baixo$n')],
      explicacoes: ['Explicação do look $n.'],
      avisos: n == 1 ? ['Calças: cadastro incompleto (sem cor).'] : const [],
    );

const _avisoEvitada = 'Você marcou esta peça como evitada.';

/// 5 looks no total, 3 por página, respeitando os descartes recebidos.
/// Com peça-base (E5.F2.2): todos os looks a contêm; ocasião "Festa" conflita
/// com ela; `baseEvitada` imita o aviso que o backend põe nos looks.
class _SugestaoServiceFake extends SugestaoService {
  final chamadas = <({
    FiltroSugestoes filtros,
    String? pecaBaseId,
    int pagina,
    List<List<String>> descartados,
  })>[];
  Object? erro;
  bool vazio = false;
  bool baseEvitada = false;

  /// Chaves dos looks salvos: como no backend (E5.F1.3), não voltam.
  final salvos = <String>{};

  @override
  Future<PaginaSugestoes> sugerir({
    FiltroSugestoes filtros = const FiltroSugestoes(),
    String? pecaBaseId,
    int pagina = 1,
    List<List<String>> descartados = const [],
  }) async {
    chamadas.add((filtros: filtros, pecaBaseId: pecaBaseId, pagina: pagina, descartados: descartados));
    if (erro != null) throw erro!;
    if (vazio) return const PaginaSugestoes(motivo: 'Seu armário ainda não tem peças cadastradas.');
    if (pecaBaseId != null && filtros.ocasiao == 'Festa') {
      return const PaginaSugestoes(conflitos: [
        ConflitoSugestao(
          filtro: 'ocasiao',
          valorFiltro: 'Festa',
          valorPeca: 'Trabalho',
          mensagem: 'Esta peça não está marcada para Festa (ocasiões: Trabalho).',
        ),
      ]);
    }
    final chavesDescartadas = descartados.map((ids) => ([...ids]..sort()).join(',')).toSet();
    final restantes = [
      for (var n = 1; n <= 5; n++)
        if (pecaBaseId == null)
          _sugestao(n)
        else
          Sugestao(
            pecas: [_peca(pecaBaseId), _peca('baixo$n')],
            explicacoes: ['Look $n com a peça-base.'],
            avisos: baseEvitada ? const [_avisoEvitada] : const [],
          ),
    ].where((s) => !chavesDescartadas.contains(s.chave) && !salvos.contains(s.chave)).toList();
    final inicio = (pagina - 1) * 3;
    final looks = restantes.skip(inicio).take(3).toList();
    return PaginaSugestoes(looks: looks, pagina: pagina, temMais: restantes.length > inicio + 3);
  }
}

class _LookServiceFake extends LookServiceSemHistorico {
  _LookServiceFake([this.sugestoes]);

  /// Quando informado, o look criado passa a contar como salvo nas sugestões.
  final _SugestaoServiceFake? sugestoes;
  final criados = <({String nome, List<String> pecaIds})>[];
  bool falhar = false;

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks'),
        type: DioExceptionType.connectionError,
      );
    }
    criados.add((nome: nome, pecaIds: pecaIds));
    sugestoes?.salvos.add(([...pecaIds]..sort()).join(','));
    return Look(id: 'novo', nome: nome, criadoEm: DateTime(2026), pecas: pecaIds.map(_peca).toList());
  }
}

Future<void> _abrir(
  WidgetTester tester,
  _SugestaoServiceFake sugestoes, [
  _LookServiceFake? looks,
  Widget home = const SuggestionsView(),
]) async {
  // Tela alta: o `ListView` só constrói o que cabe na tela.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sugestaoServiceProvider.overrideWithValue(sugestoes),
        lookServiceProvider.overrideWithValue(looks ?? _LookServiceFake()),
        preferenciaServiceProvider.overrideWithValue(PreferenciaServiceSemEvitadas()),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

final _calca = Peca(
  id: 'calca-base',
  imagemUrl: '/uploads/calca-base.png',
  categoria: 'Calças',
  subcategoria: 'Jeans',
  ocasioes: ['Trabalho'],
);

Future<void> _escolherOcasiao(WidgetTester tester, String atual, String nova) async {
  await tester.tap(find.byKey(ValueKey('filtro-Ocasião-$atual')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nova).last);
  await tester.pumpAndSettle();
}

Future<void> _sugerir(WidgetTester tester) async {
  await tester.tap(find.text('Sugerir looks'));
  await tester.pumpAndSettle();
}

void main() {
  test('Nome padrão do look sugerido', () {
    expect(nomeLookSugerido(DateTime(2026, 3, 7)), 'Look sugerido – 07/03');
  });

  testWidgets('Ao abrir, orienta e não chama o servidor', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico);

    expect(find.textContaining('toque em "Sugerir looks"'), findsOneWidget);
    expect(servico.chamadas, isEmpty);
  });

  testWidgets('Sugerir mostra 3 looks com explicação e avisos, enviando os filtros', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico);

    await tester.tap(find.byKey(const ValueKey('filtro-Ocasião-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trabalho').last);
    await tester.pumpAndSettle();
    await _sugerir(tester);

    expect(servico.chamadas.single.filtros.ocasiao, 'Trabalho');
    expect(servico.chamadas.single.pagina, 1);
    expect(find.text('• Explicação do look 1.'), findsOneWidget);
    expect(find.text('• Explicação do look 3.'), findsOneWidget);
    expect(find.text('• Explicação do look 4.'), findsNothing);
    expect(find.text('Calças: cadastro incompleto (sem cor).'), findsOneWidget);
    expect(find.text('Ver outras'), findsOneWidget);
  });

  testWidgets('"Ver outras" mostra a próxima página; na última, avisa e some o botão', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico);
    await _sugerir(tester);

    await tester.tap(find.text('Ver outras'));
    await tester.pumpAndSettle();

    expect(servico.chamadas.last.pagina, 2);
    expect(find.text('• Explicação do look 4.'), findsOneWidget);
    expect(find.text('• Explicação do look 1.'), findsNothing);
    expect(find.text('Ver outras'), findsNothing);
    expect(find.text('Não há mais sugestões com esses filtros.'), findsOneWidget);
  });

  testWidgets('Descartar tira o look e não o traz de volta na sessão', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico);
    await _sugerir(tester);

    await tester.tap(find.text('Descartar').first);
    await tester.pumpAndSettle();

    expect(servico.chamadas.last.descartados, [
      ['cima1', 'baixo1'],
    ]);
    expect(find.text('• Explicação do look 1.'), findsNothing);
    expect(find.text('• Explicação do look 4.'), findsOneWidget); // página completada

    await tester.tap(find.text('Sugerir looks'));
    await tester.pumpAndSettle();
    expect(servico.chamadas.last.descartados, hasLength(1));
    expect(find.text('• Explicação do look 1.'), findsNothing);
  });

  testWidgets('Salvar cria o look com o nome padrão, tira o card e completa a página (E5.F1.3)', (
    tester,
  ) async {
    final servico = _SugestaoServiceFake();
    final looks = _LookServiceFake(servico);
    await _abrir(tester, servico, looks);
    await _sugerir(tester);

    await tester.tap(find.text('Salvar').first);
    await tester.pumpAndSettle();

    expect(looks.criados.single.nome, nomeLookSugerido(DateTime.now()));
    expect(looks.criados.single.pecaIds, ['cima1', 'baixo1']);
    expect(find.text('Look salvo em Armário › Looks.'), findsOneWidget);
    // Recarregou a mesma página: o salvo saiu e o 4º look entrou.
    expect(servico.chamadas.last.pagina, 1);
    expect(find.text('• Explicação do look 1.'), findsNothing);
    expect(find.text('• Explicação do look 4.'), findsOneWidget);

    // Nem "Ver outras" nem nova busca trazem o look salvo de volta.
    await tester.tap(find.text('Ver outras'));
    await tester.pumpAndSettle();
    expect(find.text('• Explicação do look 5.'), findsOneWidget);
    expect(find.text('• Explicação do look 1.'), findsNothing);
    await _sugerir(tester);
    expect(find.text('• Explicação do look 1.'), findsNothing);
  });

  testWidgets('Falha ao salvar mostra mensagem e mantém a sugestão', (tester) async {
    final looks = _LookServiceFake()..falhar = true;
    await _abrir(tester, _SugestaoServiceFake(), looks);
    await _sugerir(tester);

    await tester.tap(find.text('Salvar').first);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('• Explicação do look 1.'), findsOneWidget);
    expect(find.text('Salvo'), findsNothing);
  });

  testWidgets('Erro mostra "Tentar novamente", que refaz a busca', (tester) async {
    final servico = _SugestaoServiceFake()
      ..erro = DioException(
        requestOptions: RequestOptions(path: '/sugestoes'),
        response: Response(requestOptions: RequestOptions(path: '/sugestoes'), statusCode: 401),
        type: DioExceptionType.badResponse,
      );
    await _abrir(tester, servico);
    await _sugerir(tester);

    expect(find.textContaining('Sessão expirada'), findsOneWidget);
    servico.erro = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('• Explicação do look 1.'), findsOneWidget);
  });

  testWidgets('Lista vazia mostra o motivo do backend', (tester) async {
    await _abrir(tester, _SugestaoServiceFake()..vazio = true);
    await _sugerir(tester);

    expect(find.text('Seu armário ainda não tem peças cadastradas.'), findsOneWidget);
    expect(find.text('Ver outras'), findsNothing);
  });

  // --- E5.F2.2: sugestões a partir de uma peça ---

  testWidgets('"Montar looks com esta peça" abre as sugestões com a peça fixa', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico, null, PecaDetailView(peca: _calca));

    await tester.tap(find.text('Montar looks com esta peça'));
    await tester.pumpAndSettle();

    expect(find.text('Looks com esta peça'), findsOneWidget);
    expect(find.text('Todos os looks terão esta peça'), findsOneWidget);
    expect(find.text('Calças · Jeans'), findsOneWidget);
    // Busca sozinha ao abrir, já com a peça-base.
    expect(servico.chamadas.single.pecaBaseId, 'calca-base');
    expect(find.text('• Look 1 com a peça-base.'), findsOneWidget);
    expect(find.text('• Look 3 com a peça-base.'), findsOneWidget);

    await tester.tap(find.text('Ver outras'));
    await tester.pumpAndSettle();
    expect(servico.chamadas.map((c) => c.pecaBaseId), everyElement('calca-base'));
  });

  testWidgets('Acessório não mostra o botão de montar looks', (tester) async {
    final colar = Peca(id: 'colar', imagemUrl: '/uploads/colar.png', categoria: 'Acessórios');
    await _abrir(tester, _SugestaoServiceFake(), null, PecaDetailView(peca: colar));

    expect(find.text('Montar looks com esta peça'), findsNothing);
  });

  testWidgets('Peça-base evitada: os looks mostram o aviso', (tester) async {
    await _abrir(tester, _SugestaoServiceFake()..baseEvitada = true, null,
        SuggestionsView(pecaBase: _calca));

    expect(find.text(_avisoEvitada), findsNWidgets(3));
  });

  testWidgets('Conflito com filtro mostra a mensagem e "Remover filtro" refaz sem ele', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico, null, SuggestionsView(pecaBase: _calca));

    await _escolherOcasiao(tester, 'null', 'Festa');
    await _sugerir(tester);

    expect(find.text('Esta peça não está marcada para Festa (ocasiões: Trabalho).'), findsOneWidget);
    expect(find.text('• Look 1 com a peça-base.'), findsNothing);

    await tester.tap(find.text('Remover filtro de ocasião'));
    await tester.pumpAndSettle();

    expect(servico.chamadas.last.filtros.ocasiao, isNull);
    expect(servico.chamadas.last.pagina, 1);
    expect(find.byKey(const ValueKey('filtro-Ocasião-null')), findsOneWidget);
    expect(find.text('• Look 1 com a peça-base.'), findsOneWidget);
  });

  testWidgets('Voltar da tela empilhada não altera filtros nem looks da aba', (tester) async {
    final servico = _SugestaoServiceFake();
    await _abrir(tester, servico);

    await _escolherOcasiao(tester, 'null', 'Trabalho');
    await _sugerir(tester);
    expect(servico.chamadas.last.pecaBaseId, isNull);

    tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => SuggestionsView(pecaBase: _calca)),
        );
    await tester.pumpAndSettle();

    // A tela empilhada começa sem filtros (não herda os da aba)...
    expect(find.byKey(const ValueKey('filtro-Ocasião-null')), findsOneWidget);
    expect(servico.chamadas.last.filtros.ocasiao, isNull);
    // ...e mexer nela não afeta a aba.
    await _escolherOcasiao(tester, 'null', 'Festa');
    await _sugerir(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('filtro-Ocasião-Trabalho')), findsOneWidget);
    expect(find.text('• Explicação do look 1.'), findsOneWidget);
    expect(find.text('• Look 1 com a peça-base.'), findsNothing);
  });
}
