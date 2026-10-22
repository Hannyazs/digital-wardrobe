// Testes de trocar as peças de um look salvo (E3.F5.2). Serviços falsos, nunca bate numa API real.
// Ver docs/PBIs/E3-F5-edicao-exclusao-looks/E3.F5.2-trocar-pecas-do-look.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'support/look_service_sem_historico.dart';

final _camiseta =
    Peca(id: 'camiseta', imagemUrl: '/c.png', categoria: 'Camisetas', corPrincipal: 'Branco');
final _calca = Peca(id: 'calca', imagemUrl: '/p.png', categoria: 'Calças', corPrincipal: 'Preto');
final _saia = Peca(id: 'saia', imagemUrl: '/s.png', categoria: 'Saias', corPrincipal: 'Azul');

class _PecaServiceFake extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [_camiseta, _calca, _saia];
}

/// Fake com estado: `peca_ids` troca as peças do look devolvido por `listarLooks`.
class _LookServiceEditar extends LookServiceSemHistorico {
  Look look = Look(id: 'l1', nome: 'Look de sexta', criadoEm: DateTime(2026), pecas: [_camiseta, _calca]);
  bool falhar = false;
  final patches = <Map<String, dynamic>>[];

  @override
  Future<List<Look>> listarLooks() async => [look];

  @override
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    if (falhar) {
      throw DioException(
        requestOptions: RequestOptions(path: '/looks/$id'),
        type: DioExceptionType.connectionError,
      );
    }
    patches.add(campos);
    final ids = (campos['peca_ids'] as List).cast<String>();
    look = Look(
      id: id,
      nome: look.nome,
      criadoEm: look.criadoEm,
      pecas: [_camiseta, _calca, _saia].where((p) => ids.contains(p.id)).toList(),
    );
    return look;
  }
}

Future<void> _abrirEdicao(WidgetTester tester, _LookServiceEditar service) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lookServiceProvider.overrideWithValue(service),
        pecaServiceProvider.overrideWithValue(_PecaServiceFake()),
      ],
      child: const MaterialApp(home: LooksView()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Editar peças'));
  await tester.pumpAndSettle();
}

/// Card selecionável da tela de edição de uma peça (por categoria).
Finder _card(String categoria) => find.descendant(
      of: find.ancestor(of: find.text(categoria), matching: find.byType(Column)).first,
      matching: find.byType(ClothingCard),
    );

List<String> _selecionadas(WidgetTester tester) => tester
    .widgetList<ClothingCard>(find.byType(ClothingCard))
    .where((c) => c.selecionavel && c.selecionada)
    .map((c) => c.imagemUrl)
    .toList();

ElevatedButton _salvar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar'));

void main() {
  testWidgets('Abre com as peças do look marcadas e "Salvar" desabilitado', (tester) async {
    await _abrirEdicao(tester, _LookServiceEditar());

    expect(find.text('Editar peças · Look de sexta'), findsOneWidget);
    expect(_selecionadas(tester), unorderedEquals(['/c.png', '/p.png']));
    expect(find.text('2 peças selecionadas'), findsOneWidget);
    expect(_salvar(tester).onPressed, isNull); // nada mudou ainda
  });

  testWidgets('Trocar a calça pela saia e salvar envia as peças novas e atualiza o card', (
    tester,
  ) async {
    final service = _LookServiceEditar();
    await _abrirEdicao(tester, service);

    await tester.tap(_card('Calças'));
    await tester.tap(_card('Saias'));
    await tester.pump();
    expect(_selecionadas(tester), unorderedEquals(['/c.png', '/s.png']));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect((service.patches.single['peca_ids'] as List), unorderedEquals(['camiseta', 'saia']));
    expect(find.text('Peças de "Look de sexta" atualizadas.'), findsOneWidget);
    // De volta à lista, o card mostra as peças novas.
    expect(find.text('Editar peças · Look de sexta'), findsNothing);
    final imagens = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => (i.image as NetworkImage).url)
        .toList();
    expect(imagens.any((u) => u.endsWith('/s.png')), isTrue);
    expect(imagens.any((u) => u.endsWith('/p.png')), isFalse);
  });

  testWidgets('Voltar sem salvar não chama a API', (tester) async {
    final service = _LookServiceEditar();
    await _abrirEdicao(tester, service);

    await tester.tap(_card('Saias'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(service.patches, isEmpty);
    expect(find.text('Look de sexta'), findsOneWidget);
  });

  testWidgets('Sem nenhuma peça, "Salvar" fica desabilitado', (tester) async {
    await _abrirEdicao(tester, _LookServiceEditar());

    await tester.tap(_card('Camisetas'));
    await tester.tap(_card('Calças'));
    await tester.pump();

    expect(find.text('Escolha pelo menos uma peça'), findsOneWidget);
    expect(_salvar(tester).onPressed, isNull);
  });

  testWidgets('Falha mostra mensagem e mantém a tela com a seleção', (tester) async {
    final service = _LookServiceEditar()..falhar = true;
    await _abrirEdicao(tester, service);

    await tester.tap(_card('Saias'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão com o servidor. Não foi possível salvar o look.'), findsOneWidget);
    expect(find.text('Editar peças · Look de sexta'), findsOneWidget);
    expect(_selecionadas(tester), unorderedEquals(['/c.png', '/p.png', '/s.png']));
  });

  testWidgets('Filtro da tela esconde peças sem perder a seleção', (tester) async {
    await _abrirEdicao(tester, _LookServiceEditar());

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver 1 peça'));
    await tester.pumpAndSettle();

    expect(find.text('Calças'), findsNothing);
    expect(find.text('Saias'), findsOneWidget);
    expect(find.text('2 peças selecionadas'), findsOneWidget);
  });
}
