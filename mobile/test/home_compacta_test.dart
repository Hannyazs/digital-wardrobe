// Casa reorganizada: hierarquia (cabeçalho, ações, look do dia, calendário),
// acesso discreto às preferências, card compacto e calendário recolhido.
// Serviços falsos, nunca bate numa API real.

import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/models/uso_look.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart';
import 'package:guarda_roupa_app/views/home/home_view.dart';
import 'package:guarda_roupa_app/views/looks/calendario_de_looks.dart';
import 'package:guarda_roupa_app/views/looks/looks_controller.dart' show rotuloDoMes;
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/looks/montar_look_view.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/preferences/preferences_view.dart';
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart'
    show sugestaoServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_view.dart';
import 'support/look_service_sem_historico.dart';
import 'support/preferencia_service_sem_evitadas.dart';

Peca _peca(String id) => Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: 'Camisetas');

class _SugestaoServiceFake extends SugestaoService {
  _SugestaoServiceFake({this.explicacoes = const ['Primeira razão.'], this.avisos = const [], this.pecas = 2});

  final List<String> explicacoes;
  final List<String> avisos;
  final int pecas;

  @override
  Future<LookDoDia> lookDoDia({
    required DateTime data,
    String? ocasiao,
    List<List<String>> descartados = const [],
  }) async =>
      LookDoDia(
        ocasiao: 'Casual',
        look: Sugestao(
          pecas: [for (var i = 0; i < pecas; i++) _peca('p$i')],
          explicacoes: explicacoes,
          avisos: avisos,
        ),
        temMais: true,
      );
}

class _LookServiceComHistorico extends LookServiceSemHistorico {
  _LookServiceComHistorico({this.usos = const [], this.falhar = false});

  final List<UsoLook> usos;
  final bool falhar;

  @override
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/historico'),
        type: DioExceptionType.connectionError,
      );
    }
    return usos;
  }
}

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

UsoLook _uso(String id) => UsoLook(
      id: id,
      lookId: 'look-$id',
      usadoEm: DateTime.now(),
      look: Look(id: 'look-$id', nome: 'Look $id', criadoEm: DateTime(2026), pecas: [_peca('x')]),
    );

Future<void> _abrir(
  WidgetTester tester, {
  SugestaoService? sugestoes,
  LookServiceSemHistorico? looks,
  Size tamanho = const Size(400, 900),
  double fonte = 1,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sugestaoServiceProvider.overrideWithValue(sugestoes ?? _SugestaoServiceFake()),
        lookServiceProvider.overrideWithValue(looks ?? _LookServiceComHistorico()),
        pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
        preferenciaServiceProvider.overrideWithValue(PreferenciaServiceSemEvitadas()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fonte)),
          child: child!,
        ),
        home: const HomeView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _topo(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  group('hierarquia e ações principais', () {
    testWidgets('a ordem é saudação, ações, look do dia e calendário', (tester) async {
      await _abrir(tester);

      expect(find.text('Olá!'), findsOneWidget);
      expect(find.text('Vamos escolher o que vestir.'), findsOneWidget);
      final saudacao = _topo(tester, find.text('Olá!'));
      final acoes = _topo(tester, find.text('Adicionar peça'));
      final look = _topo(tester, find.text('Look do dia'));
      final calendario = _topo(tester, find.text('Calendário de looks'));
      expect(saudacao < acoes, isTrue);
      expect(acoes < look, isTrue);
      expect(look < calendario, isTrue);
    });

    testWidgets('"Adicionar peça" e "Montar um look" ficam lado a lado, com a mesma altura', (tester) async {
      await _abrir(tester);

      final adicionar = tester.getRect(find.widgetWithText(ElevatedButton, 'Adicionar peça'));
      final montar = tester.getRect(find.widgetWithText(OutlinedButton, 'Montar um look'));
      expect(adicionar.top, montar.top);
      expect(adicionar.height, montar.height);
      expect(adicionar.right < montar.left, isTrue);
      expect(adicionar.height >= 48, isTrue); // alvo de toque confortável
    });

    testWidgets('as ações levam às telas de sempre', (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Adicionar peça'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadView), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Montar um look'));
      await tester.pumpAndSettle();
      expect(find.byType(MontarLookView), findsOneWidget);
    });

    testWidgets('as preferências saíram da lista de botões e estão num ícone do cabeçalho', (tester) async {
      await _abrir(tester, tamanho: const Size(800, 1200));

      expect(find.text('Preferências de estilo'), findsNothing); // sem botão grande
      final icone = find.byTooltip('Preferências de estilo');
      expect(icone, findsOneWidget);
      final botao = tester.getSize(find.ancestor(of: find.byIcon(Icons.tune), matching: find.byType(IconButton)));
      debugPrint('Ícone de preferências: $botao');
      expect(botao.height >= 40 && botao.width >= 40, isTrue);
      expect(_topo(tester, icone) < _topo(tester, find.text('Adicionar peça')), isTrue);

      await tester.tap(icone);
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesView), findsOneWidget);
    });
  });

  group('card "Look do dia" compacto', () {
    testWidgets('mostra só a primeira justificativa; as demais abrem em "Detalhes"', (tester) async {
      await _abrir(
        tester,
        sugestoes: _SugestaoServiceFake(
          explicacoes: ['Primeira razão.', 'Segunda razão.', 'Terceira razão.'],
          avisos: ['Camisetas: cadastro incompleto (sem cor).'],
        ),
      );

      expect(find.text('Primeira razão.'), findsOneWidget);
      expect(find.text('Segunda razão.'), findsNothing);
      expect(find.text('Detalhes'), findsOneWidget);

      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Por que este look'), findsOneWidget);
      expect(find.text('• Segunda razão.'), findsOneWidget);
      expect(find.text('• Terceira razão.'), findsOneWidget);
      expect(find.text('Camisetas: cadastro incompleto (sem cor).'), findsOneWidget);
    });

    testWidgets('com uma só justificativa e sem avisos não há "Detalhes"', (tester) async {
      await _abrir(tester);

      expect(find.text('Primeira razão.'), findsOneWidget);
      expect(find.text('Detalhes'), findsNothing);
    });

    testWidgets('mantém a ocasião e as três ações', (tester) async {
      await _abrir(tester);

      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Outra sugestão'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Usei hoje'), findsOneWidget);
    });

    testWidgets('as peças ficam numa única linha, dentro do card, sem cortes', (tester) async {
      await _abrir(
        tester,
        sugestoes: _SugestaoServiceFake(pecas: 5),
        tamanho: const Size(360, 800),
      );

      final card = tester.getRect(find.byKey(const ValueKey('card-look-do-dia')));
      final imagens = [for (final e in find.byType(Image).evaluate()) tester.getRect(find.byWidget(e.widget))];
      expect(imagens, hasLength(5));
      for (final r in imagens) {
        expect(r.width, closeTo(r.height, 0.01)); // quadradas: sem deformar
        expect(r.top, imagens.first.top); // mesma linha
        expect(r.right <= card.right, isTrue);
        expect(r.width >= 40, isTrue);
      }
    });

    testWidgets('texto longo não aumenta o card: a justificativa é cortada em 2 linhas', (tester) async {
      await _abrir(tester, sugestoes: _SugestaoServiceFake());
      final curto = tester.getSize(find.byKey(const ValueKey('card-look-do-dia'))).height;

      await _abrir(
        tester,
        sugestoes: _SugestaoServiceFake(explicacoes: [List.filled(40, 'razão muito longa').join(' ')]),
      );
      final longo = tester.getSize(find.byKey(const ValueKey('card-look-do-dia'))).height;

      expect(longo - curto < 30, isTrue, reason: 'curto=$curto longo=$longo');
    });

    for (final tamanho in const [Size(360, 800), Size(400, 900)]) {
      testWidgets('ações, look do dia e calendário cabem sem rolar em ${tamanho.width.toInt()}×${tamanho.height.toInt()}', (
        tester,
      ) async {
        await _abrir(
          tester,
          tamanho: tamanho,
          sugestoes: _SugestaoServiceFake(
            explicacoes: ['Primeira.', 'Segunda.', 'Terceira.'],
            avisos: ['Aviso um.'],
            pecas: 4,
          ),
        );

        final card = tester.getRect(find.byKey(const ValueKey('card-look-do-dia')));
        final calendario = tester.getRect(find.text('Calendário de looks'));
        final acoes = tester.getRect(find.text('Adicionar peça'));
        debugPrint('${tamanho.width.toInt()}×${tamanho.height.toInt()}: ações em y=${acoes.top}, '
            'card de ${card.height}px até y=${card.bottom}, calendário em y=${calendario.top}');
        // As ações e o look do dia aparecem sem rolagem, na metade de cima da tela...
        expect(acoes.bottom < tamanho.height / 3, isTrue, reason: 'ações em y=${acoes.bottom}');
        expect(card.bottom < tamanho.height * 0.7, isTrue, reason: 'card até y=${card.bottom}');
        // ...e o calendário recolhido também já está visível.
        expect(calendario.bottom <= tamanho.height, isTrue, reason: 'calendário em y=${calendario.bottom}');
      });
    }
  });

  group('calendário recolhido', () {
    testWidgets('nasce recolhido: título, mês e ano, sem grade nem navegação de mês', (tester) async {
      await _abrir(tester);

      expect(find.text('Calendário de looks'), findsOneWidget);
      expect(find.textContaining(rotuloDoMes(DateTime.now())), findsOneWidget);
      expect(find.byType(CalendarioDeLooks), findsNothing);
      expect(find.byTooltip('Mês anterior'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('mostra o total de usos do mês quando o histórico chegou', (tester) async {
      await _abrir(tester, looks: _LookServiceComHistorico(usos: [_uso('1'), _uso('2')]));
      expect(find.textContaining('2 usos registrados neste mês'), findsOneWidget);
    });

    testWidgets('singular e zero', (tester) async {
      await _abrir(tester, looks: _LookServiceComHistorico(usos: [_uso('1')]));
      expect(find.textContaining('1 uso registrado neste mês'), findsOneWidget);

      await _abrir(tester, looks: _LookServiceComHistorico());
      expect(find.textContaining('Nenhum uso registrado neste mês'), findsOneWidget);
    });

    testWidgets('se o histórico falha, não inventa número: só o mês e o ano', (tester) async {
      await _abrir(tester, looks: _LookServiceComHistorico(falhar: true));

      expect(find.textContaining('uso'), findsNothing);
      expect(find.text(rotuloDoMes(DateTime.now())), findsOneWidget);
    });

    testWidgets('tocar abre o calendário completo e tocar de novo recolhe', (tester) async {
      await _abrir(tester, looks: _LookServiceComHistorico(usos: [_uso('1')]));

      await tester.tap(find.text('Calendário de looks'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarioDeLooks), findsOneWidget);
      expect(find.byTooltip('Mês anterior'), findsOneWidget);
      expect(find.byTooltip('Próximo mês'), findsOneWidget);
      // O dia de hoje tem uso registrado e fica marcado.
      expect(find.byKey(ValueKey('marca-${DateTime.now().day}')), findsOneWidget);
      // A seta virou (180°).
      expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.5);

      await tester.tap(find.text('Calendário de looks'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarioDeLooks), findsNothing);
      expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0);
    });

    testWidgets('com o calendário aberto, navegar de mês continua funcionando', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Calendário de looks'));
      await tester.pumpAndSettle();

      final agora = DateTime.now();
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(find.text(rotuloDoMes(DateTime(agora.year, agora.month - 1))), findsOneWidget);
    });

    testWidgets('é um botão para leitores de tela, com o estado aberto/fechado', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester);

      final no = tester.getSemantics(find.bySemanticsLabel(RegExp('^Calendário de looks, ')));
      expect(no.label, 'Calendário de looks, ${rotuloDoMes(DateTime.now())}');
      expect(no.hint, 'Toque para expandir');
      expect(no.flagsCollection.isButton, isTrue);
      expect(no.flagsCollection.isExpanded, Tristate.isFalse);

      await tester.tap(find.text('Calendário de looks'));
      await tester.pumpAndSettle();
      final aberto = tester.getSemantics(find.bySemanticsLabel(RegExp('^Calendário de looks, ')));
      expect(aberto.hint, 'Toque para recolher');
      expect(aberto.flagsCollection.isExpanded, Tristate.isTrue);
      semantica.dispose();
    });
  });

  group('responsividade', () {
    for (final tamanho in const [Size(320, 568), Size(360, 640), Size(414, 896)]) {
      testWidgets('sem estouro em ${tamanho.width.toInt()}×${tamanho.height.toInt()}, mesmo com fonte 1,6×', (
        tester,
      ) async {
        await _abrir(
          tester,
          tamanho: tamanho,
          fonte: 1.6,
          sugestoes: _SugestaoServiceFake(
            explicacoes: ['Uma razão bem comprida para o look do dia, com várias palavras.', 'Outra.'],
            avisos: ['Algo precisa de atenção.'],
            pecas: 4,
          ),
        );
        // A tela rola: o calendário continua acessível em telas pequenas.
        final rolagem = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('Calendário de looks'), 200, scrollable: rolagem);
        await tester.ensureVisible(find.text('Calendário de looks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calendário de looks'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byTooltip('Próximo mês'), 200, scrollable: rolagem);
        await tester.ensureVisible(find.byTooltip('Próximo mês'));
        await tester.pumpAndSettle();
        // Ao alcance do toque, dentro da tela.
        final botao = tester.getRect(find.byTooltip('Próximo mês'));
        expect(botao.bottom <= tamanho.height && botao.top >= 0, isTrue);

        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Próximo mês'), findsOneWidget);
      });
    }
  });
}
