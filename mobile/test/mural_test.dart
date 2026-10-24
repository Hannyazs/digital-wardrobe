// Mural de referências (E8.F1.2 a E8.F2.2): estados da aba, adicionar da galeria
// (com o seletor nativo trocado por um falso), detalhe, nota, exclusão, coleções
// ligação a um look salvo (E8.F3.1) e etiquetas das peças sugeridas pela IA (E8.F4.1).

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guarda_roupa_app/models/colecao.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/referencia.dart';
import 'package:guarda_roupa_app/services/colecao_service.dart';
import 'package:guarda_roupa_app/services/referencia_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/references/references_controller.dart';
import 'package:guarda_roupa_app/views/references/references_view.dart';
import 'package:guarda_roupa_app/views/references/widgets/grade_de_referencias.dart';
import 'package:image_picker/image_picker.dart';

import 'support/look_service_sem_historico.dart';

Referencia _ref(
  String id, {
  String? nota,
  String? colecaoId,
  ReferenciaLook? look,
  List<String> etiquetas = const [],
}) =>
    Referencia(
      id: id,
      imagemUrl: '/uploads/$id.jpg',
      nota: nota,
      colecaoId: colecaoId,
      look: look,
      etiquetas: etiquetas,
      criadoEm: DateTime(2026, 10, 23),
    );

class _ServicoFalso extends ReferenciaService {
  _ServicoFalso(
      {List<Referencia> iniciais = const [],
      this.falhaAoCriar,
      this.falhaAoMudar})
      : banco = [...iniciais];

  final List<Referencia> banco;
  final DioException? falhaAoCriar;

  /// Falha de `atualizarNota` e `excluir`.
  final DioException? falhaAoMudar;
  int listagens = 0;

  /// Se não for nulo, `criar` espera por ele (simula a análise da IA).
  Completer<void>? segurarCriacao;

  /// Etiquetas que a "IA" devolve para a referência nova.
  List<String> etiquetasDaIa = const [];
  String? notaEnviada;
  String? colecaoEnviada;

  @override
  Future<List<Referencia>> listar() async {
    listagens++;
    return [...banco];
  }

  @override
  Future<Referencia> atualizarNota(String id, String? nota) async {
    if (falhaAoMudar != null) throw falhaAoMudar!;
    final i = banco.indexWhere((r) => r.id == id);
    banco[i] = _ref(id, nota: nota, colecaoId: banco[i].colecaoId, look: banco[i].look, etiquetas: banco[i].etiquetas);
    return banco[i];
  }

  @override
  Future<Referencia> mover(String id, String? colecaoId) async {
    if (falhaAoMudar != null) throw falhaAoMudar!;
    final i = banco.indexWhere((r) => r.id == id);
    banco[i] = _ref(id, nota: banco[i].nota, colecaoId: colecaoId, look: banco[i].look, etiquetas: banco[i].etiquetas);
    return banco[i];
  }

  @override
  Future<Referencia> atualizarEtiquetas(String id, List<String> etiquetas) async {
    if (falhaAoMudar != null) throw falhaAoMudar!;
    final i = banco.indexWhere((r) => r.id == id);
    banco[i] = _ref(id, nota: banco[i].nota, colecaoId: banco[i].colecaoId, look: banco[i].look, etiquetas: etiquetas);
    return banco[i];
  }

  @override
  Future<Referencia> ligarLook(String id, String? lookId) async {
    if (falhaAoMudar != null) throw falhaAoMudar!;
    final i = banco.indexWhere((r) => r.id == id);
    final look = lookId == null ? null : ReferenciaLook(id: lookId, nome: _nomesDosLooks[lookId]!);
    banco[i] = _ref(id, nota: banco[i].nota, colecaoId: banco[i].colecaoId, look: look, etiquetas: banco[i].etiquetas);
    return banco[i];
  }

  @override
  Future<void> excluir(String id) async {
    if (falhaAoMudar != null) throw falhaAoMudar!;
    banco.removeWhere((r) => r.id == id);
  }

  @override
  Future<Referencia> criar(XFile imagem,
      {String? nota, String? colecaoId}) async {
    if (falhaAoCriar != null) throw falhaAoCriar!;
    await segurarCriacao?.future;
    notaEnviada = nota;
    colecaoEnviada = colecaoId;
    final nova = _ref('nova-${banco.length}', nota: nota, colecaoId: colecaoId, etiquetas: etiquetasDaIa);
    banco.insert(0, nova);
    return nova;
  }
}

/// Coleções em memória; a quantidade vem das referências do serviço falso.
class _ColecaoFalso extends ColecaoService {
  _ColecaoFalso({List<String> nomes = const [], this.referencias}) {
    for (final nome in nomes) {
      colecoes.add(Colecao(
          id: 'c${colecoes.length}',
          nome: nome,
          criadoEm: DateTime(2026, 10, 23)));
    }
  }

  final _ServicoFalso? referencias;
  final List<Colecao> colecoes = [];

  Colecao _com(Colecao c, {String? nome}) => Colecao(
        id: c.id,
        nome: nome ?? c.nome,
        criadoEm: c.criadoEm,
        quantidade:
            referencias?.banco.where((r) => r.colecaoId == c.id).length ?? 0,
      );

  @override
  Future<List<Colecao>> listar() async => [for (final c in colecoes) _com(c)];

  DioException _nomeRepetido() => DioException(
        requestOptions: RequestOptions(path: '/colecoes'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/colecoes'),
          statusCode: 409,
          data: {'detail': 'Já existe uma coleção com esse nome.'},
        ),
      );

  bool _existe(String nome) =>
      colecoes.any((c) => c.nome.toLowerCase() == nome.toLowerCase());

  @override
  Future<Colecao> criar(String nome) async {
    if (_existe(nome)) throw _nomeRepetido();
    final nova = Colecao(
        id: 'c${colecoes.length}',
        nome: nome,
        criadoEm: DateTime(2026, 10, 23));
    colecoes.add(nova);
    return _com(nova);
  }

  @override
  Future<Colecao> renomear(String id, String nome) async {
    if (_existe(nome)) throw _nomeRepetido();
    final i = colecoes.indexWhere((c) => c.id == id);
    colecoes[i] = _com(colecoes[i], nome: nome);
    return _com(colecoes[i]);
  }

  @override
  Future<void> excluir(String id) async {
    colecoes.removeWhere((c) => c.id == id);
    final banco = referencias?.banco;
    if (banco != null) {
      for (var i = 0; i < banco.length; i++) {
        if (banco[i].colecaoId == id) {
          banco[i] = _ref(banco[i].id, nota: banco[i].nota, etiquetas: banco[i].etiquetas);
        }
      }
    }
  }
}

const _nomesDosLooks = {'look-1': 'Look de sexta', 'look-2': 'Look de festa'};

/// Lista de looks salvos do app (a que o seletor da referência usa).
class _LookServiceFalso extends LookServiceSemHistorico {
  _LookServiceFalso({this.vazio = false});

  final bool vazio;

  @override
  Future<List<Look>> listarLooks() async => vazio
      ? []
      : [
          for (final e in _nomesDosLooks.entries)
            Look(
              id: e.key,
              nome: e.value,
              criadoEm: DateTime(2026, 10, 20),
              pecas: [Peca(id: 'p-${e.key}', imagemUrl: '/p.png', categoria: 'Camisetas')],
            ),
        ];
}

class _ServicoQueFalhaAoListar extends ReferenciaService {
  @override
  Future<List<Referencia>> listar() async => throw DioException(
        requestOptions: RequestOptions(path: '/referencias'),
        type: DioExceptionType.connectionError,
      );
}

Future<void> _abrir(
  WidgetTester tester,
  ReferenciaService servico, {
  XFile? foto,
  ColecaoService? colecoes,
  LookServiceSemHistorico? looks,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        referenciaServiceProvider.overrideWithValue(servico),
        colecaoServiceProvider.overrideWithValue(colecoes ?? _ColecaoFalso()),
        lookServiceProvider.overrideWithValue(looks ?? _LookServiceFalso()),
        galeriaProvider.overrideWithValue(() async => foto),
      ],
      child: const MaterialApp(home: ReferencesView()),
    ),
  );
  await tester.pumpAndSettle();
}

XFile _foto() =>
    XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'look.jpg');

void main() {
  testWidgets('Mural vazio mostra a mensagem e o botão Adicionar',
      (tester) async {
    await _abrir(tester, _ServicoFalso());

    expect(find.text('Inspirações'), findsOneWidget);
    expect(find.text('Salve aqui looks que te inspiram.'), findsOneWidget);
    expect(find.text('Adicionar'),
        findsNWidgets(2)); // botão da tela + botão flutuante
  });

  testWidgets(
      'Mostra as referências na grade, com a descrição para leitores de tela',
      (tester) async {
    await _abrir(
        tester,
        _ServicoFalso(
            iniciais: [_ref('a', nota: 'cores lindas'), _ref('b'), _ref('c')]));

    expect(find.bySemanticsLabel('Referência: cores lindas'), findsOneWidget);
    expect(find.bySemanticsLabel('Referência'), findsNWidgets(2));
    expect(find.text('Salve aqui looks que te inspiram.'), findsNothing);
  });

  testWidgets('Foto da galeria com nota entra no topo da grade',
      (tester) async {
    final servico = _ServicoFalso(iniciais: [_ref('antiga')]);
    await _abrir(tester, servico, foto: _foto());

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova referência'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  gostei da jaqueta ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(servico.notaEnviada, 'gostei da jaqueta');
    expect(
        find.bySemanticsLabel('Referência: gostei da jaqueta'), findsOneWidget);
    expect(find.bySemanticsLabel('Referência'),
        findsOneWidget); // a antiga continua
  });

  testWidgets('Cancelar a galeria ou a nota não envia nada', (tester) async {
    final semFoto = _ServicoFalso();
    await _abrir(tester, semFoto, foto: null);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova referência'), findsNothing);
    expect(semFoto.banco, isEmpty);

    final cancelaNota = _ServicoFalso();
    await _abrir(tester, cancelaNota, foto: _foto());
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cancelaNota.banco, isEmpty);
  });

  testWidgets('Erro no envio mostra a mensagem e a lista não muda',
      (tester) async {
    final servico = _ServicoFalso(
      iniciais: [_ref('antiga')],
      falhaAoCriar: DioException(
        requestOptions: RequestOptions(path: '/referencias'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/referencias'),
          statusCode: 422,
          data: {'detail': 'O arquivo não é uma imagem válida.'},
        ),
      ),
    );
    await _abrir(tester, servico, foto: _foto());

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('O arquivo não é uma imagem válida.'), findsOneWidget);
    expect(find.bySemanticsLabel('Referência'), findsOneWidget);
    // O botão volta a funcionar depois do erro.
    expect(find.text('Adicionar'), findsOneWidget);
  });

  testWidgets('Falha ao carregar mostra "Tentar de novo"', (tester) async {
    await _abrir(tester, _ServicoQueFalhaAoListar());

    expect(find.text('Não foi possível carregar suas referências.'),
        findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('Tocar numa imagem abre a visualização e dá para voltar',
      (tester) async {
    await _abrir(
        tester, _ServicoFalso(iniciais: [_ref('a', nota: 'minha nota')]));

    await tester.tap(find.byType(CartaoDeReferencia));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('minha nota'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  group('detalhe: nota e exclusão (E8.F1.3)', () {
    final erroDeRede = DioException(
      requestOptions: RequestOptions(path: '/referencias/a'),
      type: DioExceptionType.connectionError,
    );

    Future<void> abrirDetalhe(
        WidgetTester tester, _ServicoFalso servico) async {
      await _abrir(tester, servico);
      await tester.tap(find.byType(CartaoDeReferencia));
      await tester.pumpAndSettle();
    }

    testWidgets('editar a nota atualiza o detalhe e a grade', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', nota: 'antiga')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Editar nota'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'antiga'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  nota nova ');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('nota nova'), findsOneWidget);
      expect(servico.banco.single.nota, 'nota nova');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Referência: nota nova'), findsOneWidget);
    });

    testWidgets('nota vazia vira "Sem nota"', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', nota: 'antiga')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Sem nota'), findsOneWidget);
      expect(find.text('Adicionar nota'), findsOneWidget);
      expect(servico.banco.single.nota, isNull);
    });

    testWidgets('cancelar a edição não muda a nota', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', nota: 'antiga')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'outra');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('antiga'), findsOneWidget);
      expect(servico.banco.single.nota, 'antiga');
    });

    testWidgets('erro ao salvar a nota mantém a nota e avisa', (tester) async {
      final servico = _ServicoFalso(
          iniciais: [_ref('a', nota: 'antiga')], falhaAoMudar: erroDeRede);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nova');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
      expect(find.text('antiga'), findsOneWidget);
    });

    testWidgets('excluir confirmado tira a imagem da grade e volta',
        (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a'), _ref('b')]);
      await _abrir(tester, servico);
      await tester.tap(find.byType(CartaoDeReferencia).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Excluir referência'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir esta referência?'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(servico.banco.map((r) => r.id), ['b']);
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(CartaoDeReferencia), findsOneWidget);
    });

    testWidgets('cancelar a exclusão não apaga nada', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.byTooltip('Excluir referência'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(servico.banco, hasLength(1));
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('erro ao excluir mantém a imagem e avisa', (tester) async {
      final servico =
          _ServicoFalso(iniciais: [_ref('a')], falhaAoMudar: erroDeRede);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.byTooltip('Excluir referência'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(servico.banco, hasLength(1));
    });
  });

  group('coleções (E8.F2.2)', () {
    Future<void> irParaColecoes(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(Tab, 'Coleções'));
      await tester.pumpAndSettle();
    }

    Future<void> digitarENomear(WidgetTester tester, String nome) async {
      await tester.enterText(find.byType(TextField), nome);
      await tester.pump(); // o botão só habilita depois de reconstruir
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'sem coleções mostra a orientação, "Nova coleção" e "Sem coleção"',
        (tester) async {
      await _abrir(tester, _ServicoFalso());
      await irParaColecoes(tester);

      expect(find.textContaining('Crie coleções'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Nova coleção'),
          findsNothing); // é botão secundário
      expect(
          find.widgetWithText(OutlinedButton, 'Nova coleção'), findsOneWidget);
      expect(find.text('Sem coleção'), findsOneWidget);
      // O botão flutuante "Adicionar" é só da aba "Todas".
      expect(
          find.widgetWithText(FloatingActionButton, 'Adicionar'), findsNothing);
    });

    testWidgets('criar uma coleção a coloca na lista com 0 referências',
        (tester) async {
      await _abrir(tester, _ServicoFalso());
      await irParaColecoes(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Nova coleção'));
      await tester.pumpAndSettle();
      await digitarENomear(tester, '  Festa ');

      expect(find.text('Festa'), findsOneWidget);
      expect(
          find.text('0 referências'), findsNWidgets(2)); // Festa e Sem coleção
    });

    testWidgets('nome repetido mostra o aviso do servidor e não cria outra',
        (tester) async {
      final refs = _ServicoFalso();
      await _abrir(tester, refs,
          colecoes: _ColecaoFalso(nomes: ['Festa'], referencias: refs));
      await irParaColecoes(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Nova coleção'));
      await tester.pumpAndSettle();
      await digitarENomear(tester, 'festa');

      expect(find.text('Já existe uma coleção com esse nome.'), findsOneWidget);
      expect(find.text('Festa'), findsOneWidget);
    });

    testWidgets(
        'adicionar de dentro de uma coleção já a escolhe e atualiza a contagem',
        (tester) async {
      final refs = _ServicoFalso();
      await _abrir(
        tester,
        refs,
        foto: _foto(),
        colecoes:
            _ColecaoFalso(nomes: ['Festa', 'Trabalho'], referencias: refs),
      );
      await irParaColecoes(tester);

      await tester.tap(find.text('Trabalho'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma referência aqui ainda.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
      await tester.pumpAndSettle();
      // A coleção da grade já vem escolhida no diálogo.
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Trabalho')),
          findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(refs.colecaoEnviada, 'c1');
      expect(find.byType(CartaoDeReferencia), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 referência'), findsOneWidget);
      expect(
          find.text('0 referências'), findsNWidgets(2)); // Festa e Sem coleção
    });

    testWidgets('mover no detalhe troca a coleção e as contagens',
        (tester) async {
      final refs = _ServicoFalso(iniciais: [_ref('a')]);
      await _abrir(tester, refs,
          colecoes: _ColecaoFalso(nomes: ['Festa'], referencias: refs));

      await tester.tap(find.byType(CartaoDeReferencia));
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String?>, 'Sem coleção'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Festa').last);
      await tester.pumpAndSettle();

      expect(refs.banco.single.colecaoId, 'c0');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await irParaColecoes(tester);
      expect(find.text('1 referência'), findsNWidgets(1)); // Festa
      expect(find.text('0 referências'), findsOneWidget); // Sem coleção
    });

    testWidgets('"Sem coleção" lista só as referências soltas', (tester) async {
      final refs =
          _ServicoFalso(iniciais: [_ref('a'), _ref('b', colecaoId: 'c0')]);
      await _abrir(tester, refs,
          colecoes: _ColecaoFalso(nomes: ['Festa'], referencias: refs));
      await irParaColecoes(tester);

      await tester.tap(find.text('Sem coleção'));
      await tester.pumpAndSettle();

      expect(find.byType(CartaoDeReferencia), findsOneWidget);
    });

    testWidgets('renomear a coleção atualiza a lista', (tester) async {
      final refs = _ServicoFalso();
      await _abrir(tester, refs,
          colecoes: _ColecaoFalso(nomes: ['Festa'], referencias: refs));
      await irParaColecoes(tester);

      await tester.tap(find.byTooltip('Opções da coleção Festa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Festa'), findsOneWidget);
      await digitarENomear(tester, 'Balada');

      expect(find.text('Balada'), findsOneWidget);
      expect(find.text('Festa'), findsNothing);
    });

    testWidgets('excluir a coleção mantém as referências, agora sem coleção',
        (tester) async {
      final refs = _ServicoFalso(iniciais: [_ref('a', colecaoId: 'c0')]);
      await _abrir(tester, refs,
          colecoes: _ColecaoFalso(nomes: ['Festa'], referencias: refs));
      await irParaColecoes(tester);

      await tester.tap(find.byTooltip('Opções da coleção Festa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('As referências dela não serão apagadas'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Festa'), findsNothing);
      expect(
          find.text('1 referência'), findsOneWidget); // agora em "Sem coleção"
      expect(refs.banco, hasLength(1));
      await tester.tap(find.widgetWithText(Tab, 'Todas'));
      await tester.pumpAndSettle();
      expect(find.byType(CartaoDeReferencia), findsOneWidget);
    });

    testWidgets('cancelar a exclusão não apaga a coleção', (tester) async {
      final refs = _ServicoFalso();
      final colecoes = _ColecaoFalso(nomes: ['Festa'], referencias: refs);
      await _abrir(tester, refs, colecoes: colecoes);
      await irParaColecoes(tester);

      await tester.tap(find.byTooltip('Opções da coleção Festa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(colecoes.colecoes, hasLength(1));
      expect(find.text('Festa'), findsOneWidget);
    });
  });

  group('look ligado (E8.F3.1)', () {
    final ligadaAoLook1 = ReferenciaLook(id: 'look-1', nome: 'Look de sexta');

    Future<void> abrirDetalhe(WidgetTester tester, _ServicoFalso servico, {LookServiceSemHistorico? looks}) async {
      await _abrir(tester, servico, looks: looks);
      await tester.tap(find.byType(CartaoDeReferencia));
      await tester.pumpAndSettle();
    }

    testWidgets('sem look mostra "Ligar a um look"', (tester) async {
      await abrirDetalhe(tester, _ServicoFalso(iniciais: [_ref('a')]));

      expect(find.text('Ligar a um look'), findsOneWidget);
      expect(find.text('Look ligado'), findsNothing);
    });

    testWidgets('ligar mostra o look (nome e peças) e o selo na grade', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      // Primeiro a forma de ligar (E8.F5.3): manual, como antes.
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      expect(find.text('Ligar a qual look?'), findsOneWidget);
      await tester.tap(find.text('Look de sexta'));
      await tester.pumpAndSettle();

      expect(servico.banco.single.look?.id, 'look-1');
      expect(find.text('Look ligado'), findsOneWidget);
      expect(find.text('Look de sexta'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Peças: ')), findsOneWidget);
      expect(find.text('Trocar look'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.checkroom), findsOneWidget); // o selo
      expect(find.bySemanticsLabel('Referência, ligada ao look Look de sexta'), findsOneWidget);
    });

    testWidgets('referência sem look não tem selo', (tester) async {
      await _abrir(tester, _ServicoFalso(iniciais: [_ref('a')]));

      expect(find.byIcon(Icons.checkroom), findsNothing);
    });

    testWidgets('desligar volta a referência para sem look', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', look: ligadaAoLook1)]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Desligar'));
      await tester.pumpAndSettle();

      expect(servico.banco.single.look, isNull);
      expect(find.text('Ligar a um look'), findsOneWidget);
      expect(find.text('Look ligado'), findsNothing);
    });

    testWidgets('trocar o look liga o outro', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', look: ligadaAoLook1)]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Trocar look'));
      await tester.pumpAndSettle();
      // Primeiro a forma de ligar (E8.F5.3): manual, como antes.
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look de festa'));
      await tester.pumpAndSettle();

      expect(servico.banco.single.look?.id, 'look-2');
      expect(find.text('Look de festa'), findsOneWidget);
    });

    testWidgets('cancelar a escolha não liga nada', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a')]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // fora do diálogo
      await tester.pumpAndSettle();

      expect(servico.banco.single.look, isNull);
    });

    testWidgets('sem looks salvos explica onde montar um', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a')]);
      await abrirDetalhe(tester, servico, looks: _LookServiceFalso(vazio: true));

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      // Primeiro a forma de ligar (E8.F5.3): manual, como antes.
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum look salvo'), findsOneWidget);
      expect(find.textContaining('aba Montar'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(servico.banco.single.look, isNull);
    });

    testWidgets('erro ao ligar mantém sem look e avisa', (tester) async {
      final servico = _ServicoFalso(
        iniciais: [_ref('a')],
        falhaAoMudar: DioException(
          requestOptions: RequestOptions(path: '/referencias/a'),
          type: DioExceptionType.connectionError,
        ),
      );
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      // Primeiro a forma de ligar (E8.F5.3): manual, como antes.
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Look de sexta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
      expect(find.text('Ligar a um look'), findsOneWidget);
    });
  });

  group('etiquetas das peças (E8.F4.1)', () {
    Future<void> abrirDetalhe(WidgetTester tester, _ServicoFalso servico) async {
      await _abrir(tester, servico);
      await tester.tap(find.byType(CartaoDeReferencia));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra as etiquetas sugeridas e o aviso da IA', (tester) async {
      await abrirDetalhe(
        tester,
        _ServicoFalso(iniciais: [_ref('a', etiquetas: ['camiseta branca', 'calça jeans'])]),
      );

      expect(find.text('Peças na imagem'), findsOneWidget);
      expect(find.text('camiseta branca'), findsOneWidget);
      expect(find.text('calça jeans'), findsOneWidget);
      expect(find.text('Sugeridas pela IA — revise'), findsOneWidget);
    });

    testWidgets('sem etiquetas não mostra o aviso da IA, só "Adicionar etiqueta"', (tester) async {
      await abrirDetalhe(tester, _ServicoFalso(iniciais: [_ref('a')]));

      expect(find.text('Sugeridas pela IA — revise'), findsNothing);
      expect(find.text('Adicionar etiqueta'), findsOneWidget);
    });

    testWidgets('remover uma etiqueta grava a lista sem ela', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', etiquetas: ['camiseta branca', 'calça jeans'])]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.byTooltip('Remover etiqueta camiseta branca'));
      await tester.pumpAndSettle();

      expect(servico.banco.single.etiquetas, ['calça jeans']);
      expect(find.text('camiseta branca'), findsNothing);
    });

    testWidgets('tocar numa etiqueta edita o texto', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', etiquetas: ['camiseta branca', 'calça jeans'])]);
      await abrirDetalhe(tester, servico);

      await tester.tap(find.text('camiseta branca'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'camiseta branca'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  camiseta azul ');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(servico.banco.single.etiquetas, ['camiseta azul', 'calça jeans']);
    });

    testWidgets('adicionar acrescenta ao fim e ignora repetida', (tester) async {
      final servico = _ServicoFalso(iniciais: [_ref('a', etiquetas: ['camiseta branca'])]);
      await abrirDetalhe(tester, servico);

      Future<void> adicionar(String texto) async {
        await tester.tap(find.text('Adicionar etiqueta'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), texto);
        await tester.pump();
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
      }

      await adicionar('bolsa preta');
      expect(servico.banco.single.etiquetas, ['camiseta branca', 'bolsa preta']);

      await adicionar('CAMISETA BRANCA'); // já existe (sem diferenciar caixa)
      expect(servico.banco.single.etiquetas, ['camiseta branca', 'bolsa preta']);
    });

    testWidgets('texto vazio não deixa salvar a etiqueta', (tester) async {
      await abrirDetalhe(tester, _ServicoFalso(iniciais: [_ref('a')]));

      await tester.tap(find.text('Adicionar etiqueta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('no limite de 10 etiquetas o botão de adicionar fica desabilitado', (tester) async {
      final dez = [for (var i = 0; i < 10; i++) 'peça $i'];
      await abrirDetalhe(tester, _ServicoFalso(iniciais: [_ref('a', etiquetas: dez)]));
      await tester.scrollUntilVisible(find.text('Limite de etiquetas atingido'), 100);

      expect(find.text('Adicionar etiqueta'), findsNothing);
      expect(find.text('Limite de etiquetas atingido'), findsOneWidget);
    });

    testWidgets('erro ao salvar mantém as etiquetas e avisa', (tester) async {
      final servico = _ServicoFalso(
        iniciais: [_ref('a', etiquetas: ['camiseta branca'])],
        falhaAoMudar: DioException(
          requestOptions: RequestOptions(path: '/referencias/a'),
          type: DioExceptionType.connectionError,
        ),
      );
      await abrirDetalhe(tester, servico);

      await tester.tap(find.byTooltip('Remover etiqueta camiseta branca'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
      expect(find.text('camiseta branca'), findsOneWidget);
    });

    testWidgets('adicionar uma foto mostra "Analisando…" e depois as etiquetas da IA', (tester) async {
      final servico = _ServicoFalso()
        ..segurarCriacao = Completer<void>()
        ..etiquetasDaIa = ['saia plissada', 'bota preta'];
      await _abrir(tester, servico, foto: _foto());

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Analisando a referência…'), findsOneWidget);
      expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNull);

      servico.segurarCriacao!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Adicionar'), findsOneWidget);

      await tester.tap(find.byType(CartaoDeReferencia));
      await tester.pumpAndSettle();
      expect(find.text('saia plissada'), findsOneWidget);
      expect(find.text('bota preta'), findsOneWidget);
      expect(find.text('Sugeridas pela IA — revise'), findsOneWidget);
    });
  });

  testWidgets('A lista não é buscada de novo quando a tela é recriada',
      (tester) async {
    final servico = _ServicoFalso(iniciais: [_ref('a')]);
    final overrides = [referenciaServiceProvider.overrideWithValue(servico)];
    Widget app(Widget home) =>
        ProviderScope(overrides: overrides, child: MaterialApp(home: home));

    await tester.pumpWidget(app(const ReferencesView()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const Scaffold(body: Text('outra aba'))));
    await tester.pumpWidget(app(const ReferencesView()));
    await tester.pumpAndSettle();

    expect(servico.listagens, 1);
    expect(find.bySemanticsLabel('Referência'), findsOneWidget);
  });
}
