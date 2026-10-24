// Testes da tela de preferências e das combinações de cores (E4.F1.2).
// PreferenciaService falso, nunca bate numa API real.
// Ver docs/PBIs/E4-F1-cores-favoritas/E4.F1.2-tela-de-preferencias-e-cores-favoritas.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/preferencia.dart';
import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart';
import 'package:guarda_roupa_app/views/home/home_view.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_view.dart';
import 'package:guarda_roupa_app/views/preferences/widgets/secao_cores_favoritas.dart';
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_view.dart';

import 'support/preferencia_service_sem_evitadas.dart';

/// Fake com estado: `atualizar` aplica os campos como o backend faria e
/// registra as chamadas, na ordem em que chegam.
class _PreferenciaServiceFake extends PreferenciaServiceSemEvitadas {
  _PreferenciaServiceFake({
    this.estado = const Preferencia(),
    this.falharAoObter = false,
    this.falhasAoAtualizar = 0,
    this.atraso = Duration.zero,
  });

  Preferencia estado;
  bool falharAoObter;

  /// Quantas das próximas chamadas a `atualizar` devem falhar.
  int falhasAoAtualizar;
  final Duration atraso;
  final patches = <Map<String, dynamic>>[];

  DioException _erroDeRede(String caminho) => DioException(
        requestOptions: RequestOptions(path: caminho),
        type: DioExceptionType.connectionError,
      );

  @override
  Future<Preferencia> obter() async {
    if (falharAoObter) throw _erroDeRede('/preferencias');
    return estado;
  }

  @override
  Future<Preferencia> atualizar(Map<String, dynamic> campos) async {
    if (atraso > Duration.zero) await Future<void>.delayed(atraso);
    if (falhasAoAtualizar > 0) {
      falhasAoAtualizar--;
      throw _erroDeRede('/preferencias');
    }
    patches.add(campos);
    estado = Preferencia.fromJson({
      'estilos': campos['estilos'] ?? estado.estilos,
      'sobreposicoes': campos['sobreposicoes'] ?? estado.sobreposicoes,
      'combinacoes_cores': campos['combinacoes_cores'] ??
          estado.combinacoesCores.map((par) => par.toJson()).toList(),
      'criatividade': campos['criatividade'] ?? estado.criatividade,
    });
    return estado;
  }
}

Future<void> _abrirTela(WidgetTester tester, _PreferenciaServiceFake service) async {
  // O sheet de cores (duas fileiras de chips) e os botões precisam de altura.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferenciaServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: PreferencesView()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cor(String fileira, String nome) => find.descendant(
      of: find.byKey(Key(fileira)),
      matching: find.widgetWithText(ChoiceChip, nome),
    );

Future<void> _escolherPar(WidgetTester tester, String corA, String corB) async {
  await tester.tap(find.text('Adicionar combinação'));
  await tester.pumpAndSettle();
  await tester.tap(_cor('cores-a', corA));
  await tester.pump();
  await tester.tap(_cor('cores-b', corB));
  await tester.pump();
}

ElevatedButton _botaoAdicionar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Adicionar'));

void main() {
  sobreposicoesTests();
  estilosTests();
  criatividadeTests();

  testWidgets('A Home leva à tela de preferências', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferenciaServiceProvider.overrideWithValue(_PreferenciaServiceFake())],
        child: const MaterialApp(home: HomeView()),
      ),
    );

    await tester.tap(find.byTooltip('Preferências de estilo'));
    await tester.pumpAndSettle();

    expect(find.byType(PreferencesView), findsOneWidget);
    expect(find.text('Cores que combinam'), findsOneWidget);
  });

  testWidgets('Mostra carregamento enquanto busca', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenciaServiceProvider.overrideWithValue(_PreferenciaServiceLenta()),
        ],
        child: const MaterialApp(home: PreferencesView()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Erro ao carregar mostra mensagem e "Tentar novamente" refaz a busca', (
    tester,
  ) async {
    final service = _PreferenciaServiceFake(falharAoObter: true);
    await _abrirTela(tester, service);

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );

    service.falharAoObter = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Cores que combinam'), findsOneWidget);
  });

  testWidgets('Sem combinações, a seção orienta a adicionar a primeira', (tester) async {
    await _abrirTela(tester, _PreferenciaServiceFake());

    expect(find.text('Nenhuma combinação ainda. Adicione a primeira.'), findsOneWidget);
  });

  testWidgets('Adicionar duas cores diferentes salva o par e ele persiste', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirTela(tester, service);

    await _escolherPar(tester, 'Azul', 'Branco');
    expect(_botaoAdicionar(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Azul + Branco'), findsOneWidget);
    expect(service.patches, [
      {
        'combinacoes_cores': [
          {'cor_a': 'Azul', 'cor_b': 'Branco'},
        ],
      },
    ]);

    // Reabrir a tela (novo ProviderScope) busca do servidor e mostra o par.
    await _abrirTela(tester, service);
    expect(find.text('Azul + Branco'), findsOneWidget);
  });

  testWidgets('Mesma cor nos dois lados bloqueia o botão', (tester) async {
    await _abrirTela(tester, _PreferenciaServiceFake());

    await _escolherPar(tester, 'Azul', 'Azul');

    expect(find.text('Escolha duas cores diferentes.'), findsOneWidget);
    expect(_botaoAdicionar(tester).onPressed, isNull);
  });

  testWidgets('Par já existente, mesmo na ordem inversa, bloqueia o botão', (tester) async {
    final service = _PreferenciaServiceFake(
      estado: const Preferencia(combinacoesCores: [CombinacaoCores('Azul', 'Branco')]),
    );
    await _abrirTela(tester, service);

    await _escolherPar(tester, 'Branco', 'Azul');

    expect(find.text('Essa combinação já existe.'), findsOneWidget);
    expect(_botaoAdicionar(tester).onPressed, isNull);
  });

  testWidgets('Remover um par o tira da lista e persiste', (tester) async {
    final service = _PreferenciaServiceFake(
      estado: const Preferencia(
        combinacoesCores: [CombinacaoCores('Azul', 'Branco'), CombinacaoCores('Preto', 'Rosa')],
      ),
    );
    await _abrirTela(tester, service);

    await tester.tap(find.byTooltip('Remover Azul + Branco'));
    await tester.pumpAndSettle();

    expect(find.text('Azul + Branco'), findsNothing);
    expect(find.text('Preto + Rosa'), findsOneWidget);
    expect(service.patches.single['combinacoes_cores'], [
      {'cor_a': 'Preto', 'cor_b': 'Rosa'},
    ]);
  });

  testWidgets('Falha no PATCH ao adicionar desfaz a mudança e avisa', (tester) async {
    final service = _PreferenciaServiceFake(falhasAoAtualizar: 1);
    await _abrirTela(tester, service);

    await _escolherPar(tester, 'Azul', 'Branco');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a preferência.'),
      findsOneWidget,
    );
    expect(find.text('Azul + Branco'), findsNothing);
    expect(find.text('Nenhuma combinação ainda. Adicione a primeira.'), findsOneWidget);
  });

  testWidgets('Falha no PATCH ao remover mantém o par', (tester) async {
    final service = _PreferenciaServiceFake(
      estado: const Preferencia(combinacoesCores: [CombinacaoCores('Azul', 'Branco')]),
      falhasAoAtualizar: 1,
    );
    await _abrirTela(tester, service);

    await tester.tap(find.byTooltip('Remover Azul + Branco'));
    await tester.pumpAndSettle();

    expect(find.text('Azul + Branco'), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a preferência.'),
      findsOneWidget,
    );
  });

  testWidgets('No limite de pares o botão "Adicionar combinação" fica desabilitado', (
    tester,
  ) async {
    final pares = [for (var i = 0; i < maxCombinacoesCores; i++) CombinacaoCores('C$i', 'D$i')];
    await _abrirTela(tester, _PreferenciaServiceFake(estado: Preferencia(combinacoesCores: pares)));

    final botao = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Adicionar combinação'),
    );
    expect(botao.onPressed, isNull);
    expect(find.textContaining('Limite de $maxCombinacoesCores combinações'), findsOneWidget);
  });

  group('PreferenciasController', () {
    test('mudanças seguidas vão ao servidor em ordem e a segunda parte do estado já atualizado',
        () async {
      final service = _PreferenciaServiceFake(atraso: const Duration(milliseconds: 20));
      final container = ProviderContainer(
        overrides: [preferenciaServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(preferenciasProvider, (_, __) {});
      await container.read(preferenciasProvider.future);
      final controller = container.read(preferenciasProvider.notifier);

      final primeira = controller.atualizar(
        {'estilos': ['Casual']},
        (atual) => atual.copyWith(estilos: ['Casual']),
      );
      // Antes de a primeira terminar, a tela já mostra a mudança otimista.
      expect(container.read(preferenciasProvider).value!.estilos, ['Casual']);
      final segunda = controller.atualizar(
        {'criatividade': 5},
        (atual) => atual.copyWith(criatividade: 5),
      );
      // A segunda parte do estado já atualizado (não perde o estilo).
      expect(container.read(preferenciasProvider).value!.estilos, ['Casual']);
      expect(container.read(preferenciasProvider).value!.criatividade, 5);

      expect(await primeira, isNull);
      expect(await segunda, isNull);
      expect(service.patches, [
        {'estilos': ['Casual']},
        {'criatividade': 5},
      ]);
      final final_ = container.read(preferenciasProvider).value!;
      expect(final_.estilos, ['Casual']);
      expect(final_.criatividade, 5);
    });

    test('uma falha na primeira não sobrescreve a segunda mudança bem-sucedida', () async {
      final service = _PreferenciaServiceFake(
        atraso: const Duration(milliseconds: 20),
        falhasAoAtualizar: 1,
      );
      final container = ProviderContainer(
        overrides: [preferenciaServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.listen(preferenciasProvider, (_, __) {});
      await container.read(preferenciasProvider.future);
      final controller = container.read(preferenciasProvider.notifier);

      final primeira = controller.atualizar(
        {'estilos': ['Casual']},
        (atual) => atual.copyWith(estilos: ['Casual']),
      );
      final segunda = controller.atualizar(
        {'criatividade': 5},
        (atual) => atual.copyWith(criatividade: 5),
      );

      expect(await primeira, isNotNull); // a primeira falhou
      expect(await segunda, isNull); // a segunda deu certo
      final final_ = container.read(preferenciasProvider).value!;
      expect(final_.criatividade, 5); // a segunda mudança vale
      expect(final_.estilos, isEmpty); // a primeira foi desfeita
      expect(service.estado.estilos, isEmpty);
      expect(service.estado.criatividade, 5);
    });
  });
}

class _PreferenciaServiceLenta extends PreferenciaServiceSemEvitadas {
  @override
  Future<Preferencia> obter() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return const Preferencia();
  }
}

// --- E4.F2.1: sobreposições preferidas ---

FilterChip _chip(WidgetTester tester, String texto) =>
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, texto));

void sobreposicoesTests() {
  group('alternarNaLista', () {
    const ordem = ['Jaqueta', 'Cardigan', 'Camisa aberta', 'Blazer', 'Colete'];

    test('marca e desmarca, na ordem da lista fixa (não na dos toques)', () {
      final a = alternarNaLista(const [], 'Blazer', ordem);
      final b = alternarNaLista(a, 'Jaqueta', ordem);
      expect(b, ['Jaqueta', 'Blazer']);
      expect(alternarNaLista(b, 'Blazer', ordem), ['Jaqueta']);
      expect(alternarNaLista(const ['Jaqueta'], 'Jaqueta', ordem), isEmpty);
    });

    test('valores fora da lista fixa ficam no fim e só saem se desmarcados', () {
      expect(alternarNaLista(const ['Sobretudo'], 'Jaqueta', ordem), ['Jaqueta', 'Sobretudo']);
      expect(alternarNaLista(const ['Jaqueta', 'Sobretudo'], 'Sobretudo', ordem), ['Jaqueta']);
    });
  });

  testWidgets('Seção mostra os cinco tipos, nenhum marcado para quem nunca salvou', (tester) async {
    await _abrirTela(tester, _PreferenciaServiceFake());

    expect(find.text('Sobreposições'), findsOneWidget);
    for (final tipo in ['Jaqueta', 'Cardigan', 'Camisa aberta', 'Blazer', 'Colete']) {
      expect(_chip(tester, tipo).selected, isFalse, reason: tipo);
    }
  });

  testWidgets('Marcar persiste ao reabrir; desmarcar volta a lista vazia', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirTela(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Cardigan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Jaqueta'));
    await tester.pumpAndSettle();

    expect(service.patches.last, {
      'sobreposicoes': ['Jaqueta', 'Cardigan'],
    });

    await _abrirTela(tester, service);
    expect(_chip(tester, 'Jaqueta').selected, isTrue);
    expect(_chip(tester, 'Cardigan').selected, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Jaqueta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Cardigan'));
    await tester.pumpAndSettle();
    expect(service.patches.last, {'sobreposicoes': <String>[]});
    expect(service.estado.sobreposicoes, isEmpty);
  });

  testWidgets('Dois toques seguidos, sem rebuild entre eles, gravam os dois tipos', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirTela(tester, service);

    // Sem `pump()` entre os toques: o segundo não pode partir da lista antiga.
    await tester.tap(find.widgetWithText(FilterChip, 'Blazer'));
    await tester.tap(find.widgetWithText(FilterChip, 'Colete'));
    await tester.pumpAndSettle();

    expect(service.estado.sobreposicoes, ['Blazer', 'Colete']);
    expect(_chip(tester, 'Blazer').selected, isTrue);
    expect(_chip(tester, 'Colete').selected, isTrue);
  });

  testWidgets('Valor salvo fora da lista fixa aparece marcado e continua salvo', (tester) async {
    final service = _PreferenciaServiceFake(
      estado: const Preferencia(sobreposicoes: ['Sobretudo']),
    );
    await _abrirTela(tester, service);

    expect(_chip(tester, 'Sobretudo').selected, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Jaqueta'));
    await tester.pumpAndSettle();
    expect(service.estado.sobreposicoes, ['Jaqueta', 'Sobretudo']);
  });

  testWidgets('Falha no PATCH desfaz a marcação e avisa', (tester) async {
    final service = _PreferenciaServiceFake(falhasAoAtualizar: 1);
    await _abrirTela(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Jaqueta'));
    await tester.pumpAndSettle();

    expect(_chip(tester, 'Jaqueta').selected, isFalse);
    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a preferência.'),
      findsOneWidget,
    );
    expect(service.estado.sobreposicoes, isEmpty);
  });
}

// --- E4.F3.1: estilos preferidos ---

void estilosTests() {
  const estilos = ['Casual', 'Formal', 'Esportivo', 'Elegante', 'Streetwear', 'Minimalista'];

  testWidgets('Seção mostra os seis estilos, nenhum marcado para quem nunca salvou', (tester) async {
    await _abrirTela(tester, _PreferenciaServiceFake());

    expect(find.text('Estilos preferidos'), findsOneWidget);
    for (final estilo in estilos) {
      expect(_chip(tester, estilo).selected, isFalse, reason: estilo);
    }
  });

  testWidgets('Marcar vários persiste ao reabrir, na ordem da lista fixa; desmarcar remove', (
    tester,
  ) async {
    final service = _PreferenciaServiceFake();
    await _abrirTela(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Minimalista'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Casual'));
    await tester.pumpAndSettle();

    // Só o campo de estilos vai no PATCH; a ordem é a de `estilosFixos`.
    expect(service.patches.last, {
      'estilos': ['Casual', 'Minimalista'],
    });

    await _abrirTela(tester, service);
    expect(_chip(tester, 'Casual').selected, isTrue);
    expect(_chip(tester, 'Minimalista').selected, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Casual'));
    await tester.pumpAndSettle();
    expect(service.estado.estilos, ['Minimalista']);
    expect(_chip(tester, 'Casual').selected, isFalse);
  });

  testWidgets('Estilos e sobreposições são independentes', (tester) async {
    final service = _PreferenciaServiceFake(
      estado: const Preferencia(sobreposicoes: ['Jaqueta']),
    );
    await _abrirTela(tester, service);

    // Dois toques seguidos em seções diferentes, sem rebuild entre eles.
    await tester.tap(find.widgetWithText(FilterChip, 'Elegante'));
    await tester.tap(find.widgetWithText(FilterChip, 'Blazer'));
    await tester.pumpAndSettle();

    expect(service.estado.estilos, ['Elegante']);
    expect(service.estado.sobreposicoes, ['Jaqueta', 'Blazer']);
    expect(service.patches, [
      {
        'estilos': ['Elegante'],
      },
      {
        'sobreposicoes': ['Jaqueta', 'Blazer'],
      },
    ]);
  });

  testWidgets('Estilo salvo fora da lista fixa aparece marcado e continua salvo', (tester) async {
    final service = _PreferenciaServiceFake(estado: const Preferencia(estilos: ['Boho']));
    await _abrirTela(tester, service);

    expect(_chip(tester, 'Boho').selected, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Streetwear'));
    await tester.pumpAndSettle();
    expect(service.estado.estilos, ['Streetwear', 'Boho']);
  });

  testWidgets('Falha no PATCH desfaz a marcação do estilo e avisa', (tester) async {
    final service = _PreferenciaServiceFake(falhasAoAtualizar: 1);
    await _abrirTela(tester, service);

    await tester.tap(find.widgetWithText(FilterChip, 'Esportivo'));
    await tester.pumpAndSettle();

    expect(_chip(tester, 'Esportivo').selected, isFalse);
    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a preferência.'),
      findsOneWidget,
    );
    expect(service.estado.estilos, isEmpty);
  });
}

// --- E4.F5.1: nível de criatividade (o controle mora na aba Sugestões) ---

/// `SugestaoService` falso que anota o nível de criatividade **salvo** no
/// momento em que a geração é pedida: é o que o backend leria.
class _SugestaoServiceQueAnotaONivel extends SugestaoService {
  _SugestaoServiceQueAnotaONivel(this.preferencias);

  final _PreferenciaServiceFake preferencias;
  final niveisNaGeracao = <int>[];

  @override
  Future<PaginaSugestoes> sugerir({
    FiltroSugestoes filtros = const FiltroSugestoes(),
    String? pecaBaseId,
    int pagina = 1,
    List<List<String>> descartados = const [],
  }) async {
    niveisNaGeracao.add(preferencias.estado.criatividade);
    return const PaginaSugestoes(motivo: 'Seu armário ainda não tem peças cadastradas.');
  }
}

Future<_SugestaoServiceQueAnotaONivel> _abrirSugestoes(
  WidgetTester tester,
  _PreferenciaServiceFake service,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final sugestoes = _SugestaoServiceQueAnotaONivel(service);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenciaServiceProvider.overrideWithValue(service),
        sugestaoServiceProvider.overrideWithValue(sugestoes),
      ],
      child: const MaterialApp(home: SuggestionsView()),
    ),
  );
  await tester.pumpAndSettle();
  return sugestoes;
}

Slider _slider(WidgetTester tester) => tester.widget<Slider>(find.byType(Slider));

String _rotuloCriatividade(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('rotulo-criatividade'))).data!;

void criatividadeTests() {
  testWidgets('A tela de Preferências não tem mais o controle de criatividade', (tester) async {
    await _abrirTela(tester, _PreferenciaServiceFake());

    expect(find.byType(Slider), findsNothing);
    expect(find.text('Criatividade das combinações'), findsNothing);
    // As demais preferências continuam lá.
    expect(find.text('Estilos preferidos'), findsOneWidget);
  });

  testWidgets('Sem preferência salva, o controle aparece na aba Sugestões no nível 3 "Cores vizinhas"', (
    tester,
  ) async {
    await _abrirSugestoes(tester, _PreferenciaServiceFake());

    expect(find.text('Criatividade das combinações'), findsOneWidget);
    expect(_slider(tester).value, 3);
    expect(_rotuloCriatividade(tester), 'Cores vizinhas');
  });

  testWidgets('A escala e os rótulos são os de antes (1 a 5)', (tester) async {
    await _abrirSugestoes(tester, _PreferenciaServiceFake());

    expect(_slider(tester).min, 1);
    expect(_slider(tester).max, 5);
    expect(_slider(tester).divisions, 4);
    expect(find.text('Neutros + uma cor'), findsOneWidget);
    expect(find.text('Cores opostas'), findsOneWidget);
  });

  testWidgets('Nível salvo aparece ao abrir', (tester) async {
    await _abrirSugestoes(
      tester,
      _PreferenciaServiceFake(estado: const Preferencia(criatividade: 5)),
    );

    expect(_slider(tester).value, 5);
    expect(_rotuloCriatividade(tester), 'Cores opostas');
  });

  testWidgets('Durante o arrasto o rótulo acompanha sem chamar o servidor; soltar salva uma vez', (
    tester,
  ) async {
    final service = _PreferenciaServiceFake();
    await _abrirSugestoes(tester, service);

    // Movimento intermediário (como um arrasto): só estado local.
    _slider(tester).onChanged!(4);
    await tester.pump();
    _slider(tester).onChanged!(1);
    await tester.pump();
    expect(_rotuloCriatividade(tester), 'Neutros + uma cor');
    expect(service.patches, isEmpty);

    // Soltar: uma única gravação, com o nível final.
    _slider(tester).onChangeEnd!(1);
    await tester.pumpAndSettle();
    expect(service.patches, [
      {'criatividade': 1},
    ]);
    expect(service.estado.criatividade, 1);
  });

  testWidgets('Arrasto real até o fim do controle grava o nível 5 uma única vez', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirSugestoes(tester, service);

    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(service.patches, [
      {'criatividade': 5},
    ]);
    expect(_rotuloCriatividade(tester), 'Cores opostas');
  });

  testWidgets('Soltar no mesmo nível em que estava não grava nada', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirSugestoes(tester, service);

    _slider(tester).onChanged!(4);
    await tester.pump();
    _slider(tester).onChanged!(3);
    await tester.pump();
    _slider(tester).onChangeEnd!(3);
    await tester.pumpAndSettle();

    expect(service.patches, isEmpty);
  });

  testWidgets('Nível persiste ao reabrir a aba', (tester) async {
    final service = _PreferenciaServiceFake();
    await _abrirSugestoes(tester, service);

    _slider(tester).onChanged!(4);
    _slider(tester).onChangeEnd!(4);
    await tester.pumpAndSettle();

    await _abrirSugestoes(tester, service);
    expect(_slider(tester).value, 4);
    expect(_rotuloCriatividade(tester), 'Cores contrastantes');
  });

  testWidgets('Falha no PATCH devolve o controle ao nível anterior e avisa', (tester) async {
    final service = _PreferenciaServiceFake(falhasAoAtualizar: 1);
    await _abrirSugestoes(tester, service);

    _slider(tester).onChanged!(5);
    await tester.pump();
    _slider(tester).onChangeEnd!(5);
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a preferência.'),
      findsOneWidget,
    );
    expect(_slider(tester).value, 3);
    expect(_rotuloCriatividade(tester), 'Cores vizinhas');
    expect(service.estado.criatividade, 3);
  });

  testWidgets('"Sugerir looks" gera com o nível escolhido, mesmo pedido logo após soltar o controle', (
    tester,
  ) async {
    // A gravação demora; a geração só pode sair depois dela (o backend lê o nível salvo).
    final service = _PreferenciaServiceFake(atraso: const Duration(milliseconds: 300));
    final sugestoes = await _abrirSugestoes(tester, service);

    _slider(tester).onChanged!(5);
    _slider(tester).onChangeEnd!(5);
    await tester.pump();
    await tester.tap(find.text('Sugerir looks'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sugestoes.niveisNaGeracao, isEmpty); // ainda esperando a gravação

    await tester.pumpAndSettle();
    expect(sugestoes.niveisNaGeracao, [5]);
  });

  testWidgets('Com looks na tela, mudar a régua refaz a lista com o novo nível', (tester) async {
    final service = _PreferenciaServiceFake();
    final sugestoes = await _abrirSugestoes(tester, service);

    await tester.tap(find.text('Sugerir looks'));
    await tester.pumpAndSettle();
    expect(sugestoes.niveisNaGeracao, [3]);

    _slider(tester).onChanged!(1);
    _slider(tester).onChangeEnd!(1);
    await tester.pumpAndSettle();

    // Uma nova geração, já com o nível 1 gravado.
    expect(sugestoes.niveisNaGeracao, [3, 1]);
  });

  testWidgets('Sem looks na tela, mudar a régua só grava: nada é gerado sozinho', (tester) async {
    final service = _PreferenciaServiceFake();
    final sugestoes = await _abrirSugestoes(tester, service);

    _slider(tester).onChanged!(5);
    _slider(tester).onChangeEnd!(5);
    await tester.pumpAndSettle();

    expect(service.patches, [
      {'criatividade': 5},
    ]);
    expect(sugestoes.niveisNaGeracao, isEmpty);
  });

  testWidgets('Se gravar o nível falha, a lista não é refeita', (tester) async {
    final service = _PreferenciaServiceFake();
    final sugestoes = await _abrirSugestoes(tester, service);
    await tester.tap(find.text('Sugerir looks'));
    await tester.pumpAndSettle();

    service.falhasAoAtualizar = 1;
    _slider(tester).onChanged!(5);
    _slider(tester).onChangeEnd!(5);
    await tester.pumpAndSettle();

    expect(sugestoes.niveisNaGeracao, [3]); // só a primeira geração
    expect(_slider(tester).value, 3);
  });

  testWidgets('Sem mexer no controle, "Sugerir looks" gera com o nível já salvo', (tester) async {
    final service = _PreferenciaServiceFake(estado: const Preferencia(criatividade: 2));
    final sugestoes = await _abrirSugestoes(tester, service);

    await tester.tap(find.text('Sugerir looks'));
    await tester.pumpAndSettle();

    expect(sugestoes.niveisNaGeracao, [2]);
    expect(service.patches, isEmpty);
  });

  testWidgets('Se as preferências não carregam, avisa e "Tentar de novo" refaz a busca', (tester) async {
    final service = _PreferenciaServiceFake(falharAoObter: true);
    await _abrirSugestoes(tester, service);

    expect(find.byType(Slider), findsNothing);
    expect(find.text('Tentar de novo'), findsOneWidget);

    service.falharAoObter = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
  });
}
