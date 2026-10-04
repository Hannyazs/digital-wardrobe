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
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

Peca _peca(String id) => Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: 'Camisetas');

Look _look(String id, String nome, List<String> pecaIds) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      pecas: pecaIds.map(_peca).toList(),
    );

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _LookServiceLento extends LookService {
  @override
  Future<List<Look>> listarLooks() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return [];
  }
}

class _LookServiceVazio extends LookService {
  @override
  Future<List<Look>> listarLooks() async => [];
}

class _LookServiceComDados extends LookService {
  @override
  Future<List<Look>> listarLooks() async => [
        _look('1', 'Look de sexta', ['1', '2']),
        _look('2', 'Look da faculdade', ['3']),
      ];
}

class _LookServiceComErro extends LookService {
  @override
  Future<List<Look>> listarLooks() async {
    throw DioException(
      requestOptions: RequestOptions(path: '/looks'),
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
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
}
