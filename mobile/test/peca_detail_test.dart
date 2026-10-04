// Testes do detalhe, edição e exclusão de peça (E1.F3.1).
// Mesmo padrão dos demais: PecaService falso, nunca bate numa API real.
// Ver docs/PBIs/E1-F3-edicao-exclusao-peca/E1.F3.1-edicao-e-exclusao-de-peca.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/peca_detail_view.dart';

final _peca = Peca(
  id: 'peca-1',
  imagemUrl: '/uploads/peca-1.png',
  categoria: 'Vestidos',
  subcategoria: 'Longo',
  corPrincipal: 'Azul',
  estacao: 'Verão',
  ocasiao: 'Festa',
);

class _PecaServiceComSucesso extends PecaService {
  @override
  Future<void> excluirPeca(String id) async {}

  @override
  Future<Peca> atualizarPeca({
    required String id,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? estacao,
    String? ocasiao,
  }) async =>
      Peca(id: id, imagemUrl: _peca.imagemUrl, categoria: categoria);

  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _PecaServiceExcluirNuncaDeveSerChamado extends PecaService {
  @override
  Future<void> excluirPeca(String id) async {
    fail('excluirPeca não deveria ser chamado quando o usuário cancela.');
  }
}

class _PecaServiceComErroAoExcluir extends PecaService {
  @override
  Future<void> excluirPeca(String id) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas/$id'),
      type: DioExceptionType.connectionError,
    );
  }
}

/// Primeira tela de uma pilha de navegação de teste — permite verificar
/// que, depois de excluir/editar, a navegação volta até aqui.
class _TelaInicialFake extends StatelessWidget {
  const _TelaInicialFake();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PecaDetailView(peca: _peca)),
          ),
          child: const Text('Abrir detalhe'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Mostra imagem e metadados da peça', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: PecaDetailView(peca: _peca)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vestidos'), findsOneWidget);
    expect(find.text('Longo'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('Verão'), findsOneWidget);
    expect(find.text('Festa'), findsOneWidget);
  });

  testWidgets('Cancelar no diálogo de exclusão não exclui nada', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceExcluirNuncaDeveSerChamado()),
        ],
        child: MaterialApp(home: PecaDetailView(peca: _peca)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Excluir peça?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir peça?'), findsNothing);
    expect(find.text('Detalhe da peça'), findsOneWidget);
  });

  testWidgets('Confirmar exclusão chama a API e volta para a tela anterior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso())],
        child: const MaterialApp(home: _TelaInicialFake()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir detalhe'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir detalhe'), findsOneWidget);
    expect(find.text('Detalhe da peça'), findsNothing);
  });

  testWidgets('Falha ao excluir mostra mensagem de erro e mantém o detalhe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComErroAoExcluir())],
        child: MaterialApp(home: PecaDetailView(peca: _peca)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível excluir a peça. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Detalhe da peça'), findsOneWidget);
  });

  testWidgets('Editar abre o formulário pré-preenchido com os dados da peça', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso())],
        child: MaterialApp(home: PecaDetailView(peca: _peca)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Editar peça'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
    expect(find.text('Vestidos'), findsOneWidget);
    expect(find.text('Longo'), findsOneWidget);
  });

  testWidgets('Salvar edição com sucesso volta até a tela anterior ao detalhe', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso())],
        child: const MaterialApp(home: _TelaInicialFake()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir detalhe'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    final botaoSalvar = find.byType(ElevatedButton).last;
    await tester.ensureVisible(botaoSalvar);
    await tester.tap(botaoSalvar);
    await tester.pumpAndSettle();

    expect(find.text('Abrir detalhe'), findsOneWidget);
    expect(find.text('Editar peça'), findsNothing);
    expect(find.text('Detalhe da peça'), findsNothing);
  });
}
