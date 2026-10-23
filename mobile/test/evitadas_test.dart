// Testes de marcar peça como evitada (E4.F4.2): ação no detalhe da peça e
// seção "Peças que evito" na tela de preferências. Serviços falsos, nunca
// batem numa API real.
// Ver docs/PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.2-marcar-peca-evitada-no-app.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/evitadas.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_view.dart';
import 'package:guarda_roupa_app/views/preferences/widgets/secao_pecas_evitadas.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/peca_detail_view.dart';

import 'support/preferencia_service_sem_evitadas.dart';

final _vestido = Peca(
  id: 'peca-1',
  imagemUrl: '/uploads/peca-1.png',
  categoria: 'Vestidos',
  subcategoria: 'Longo',
  corPrincipal: 'Azul',
);
final _calca = Peca(id: 'peca-2', imagemUrl: '/uploads/peca-2.png', categoria: 'Calças');

DioException _erro(String caminho, {int? status}) {
  final opts = RequestOptions(path: caminho);
  return status == null
      ? DioException(requestOptions: opts, type: DioExceptionType.connectionError)
      : DioException(
          requestOptions: opts,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: opts, statusCode: status),
        );
}

/// Fake com estado: marcar/desmarcar alteram o que `listarEvitadas` devolve.
class _PreferenciaServiceEvitadas extends PreferenciaServiceSemEvitadas {
  _PreferenciaServiceEvitadas(this.pecas);

  List<Peca> pecas;
  DioException? erroAoListar;
  DioException? erroAoAlterar;
  int listagens = 0;

  @override
  Future<Evitadas> listarEvitadas() async {
    listagens++;
    if (erroAoListar != null) throw erroAoListar!;
    return Evitadas(pecas: List.of(pecas));
  }

  @override
  Future<void> evitarPeca(String pecaId) async {
    if (erroAoAlterar != null) throw erroAoAlterar!;
    if (!pecas.any((p) => p.id == pecaId)) {
      pecas = [...pecas, [_vestido, _calca].firstWhere((p) => p.id == pecaId)];
    }
  }

  @override
  Future<void> pararDeEvitarPeca(String pecaId) async {
    if (erroAoAlterar != null) throw erroAoAlterar!;
    pecas = pecas.where((p) => p.id != pecaId).toList();
  }
}

/// Excluir a peça também a tira das evitadas, como o CASCADE do backend.
class _PecaServiceExclui extends PecaService {
  _PecaServiceExclui(this.preferencias);

  final _PreferenciaServiceEvitadas preferencias;

  @override
  Future<void> excluirPeca(String id, {bool removerDosLooks = false}) async {
    preferencias.pecas = preferencias.pecas.where((p) => p.id != id).toList();
  }

  @override
  Future<List<Peca>> listarPecas() async => [];
}

Future<void> _abrirDetalhe(WidgetTester tester, _PreferenciaServiceEvitadas service) async {
  // Tela alta: o botão "Evitar nas sugestões" fica no fim do detalhe (Etapa 8
  // do redesign) e o `ListView` só constrói o que cabe na tela.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferenciaServiceProvider.overrideWithValue(service)],
      child: MaterialApp(home: PecaDetailView(peca: _vestido)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirPreferencias(WidgetTester tester, _PreferenciaServiceEvitadas service) async {
  tester.view.physicalSize = const Size(800, 2400);
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

void main() {
  group('Detalhe da peça', () {
    testWidgets('"Evitar nas sugestões" marca, mostra o aviso e o botão vira "Parar de evitar"', (
      tester,
    ) async {
      final service = _PreferenciaServiceEvitadas([]);
      await _abrirDetalhe(tester, service);

      expect(find.text('Evitada nas sugestões'), findsNothing);
      await tester.ensureVisible(find.text('Evitar nas sugestões'));
      await tester.tap(find.text('Evitar nas sugestões'));
      await tester.pumpAndSettle();

      expect(service.pecas.map((p) => p.id), ['peca-1']);
      expect(find.text('Evitada nas sugestões'), findsOneWidget);
      expect(find.text('Parar de evitar'), findsOneWidget);
      expect(find.text('Peça marcada para não aparecer nas sugestões.'), findsOneWidget);
    });

    testWidgets('Peça evitada abre com o aviso, e "Parar de evitar" desmarca', (tester) async {
      final service = _PreferenciaServiceEvitadas([_vestido]);
      await _abrirDetalhe(tester, service);

      expect(find.text('Evitada nas sugestões'), findsOneWidget);
      await tester.ensureVisible(find.text('Parar de evitar'));
      await tester.tap(find.text('Parar de evitar'));
      await tester.pumpAndSettle();

      expect(service.pecas, isEmpty);
      expect(find.text('Evitada nas sugestões'), findsNothing);
      expect(find.text('Evitar nas sugestões'), findsOneWidget);
      expect(find.text('A peça voltou a poder aparecer nas sugestões.'), findsOneWidget);
    });

    testWidgets('Falha de rede ao marcar mostra mensagem e mantém o estado', (tester) async {
      final service = _PreferenciaServiceEvitadas([])
        ..erroAoAlterar = _erro('/preferencias/pecas-evitadas');
      await _abrirDetalhe(tester, service);

      await tester.ensureVisible(find.text('Evitar nas sugestões'));
      await tester.tap(find.text('Evitar nas sugestões'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão com o servidor. Não foi possível atualizar a peça.'),
        findsOneWidget,
      );
      expect(find.text('Evitada nas sugestões'), findsNothing);
      expect(find.text('Evitar nas sugestões'), findsOneWidget);
    });

    testWidgets('401 e 404 têm mensagens próprias', (tester) async {
      final service = _PreferenciaServiceEvitadas([_vestido])
        ..erroAoAlterar = _erro('/preferencias/pecas-evitadas/peca-1', status: 404);
      await _abrirDetalhe(tester, service);

      await tester.ensureVisible(find.text('Parar de evitar'));
      await tester.tap(find.text('Parar de evitar'));
      await tester.pumpAndSettle();
      expect(find.text('Peça não encontrada. Ela pode ter sido excluída.'), findsOneWidget);
      expect(find.text('Evitada nas sugestões'), findsOneWidget);

      // SnackBars entram em fila: espera o anterior sair antes do próximo erro.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      service.erroAoAlterar = _erro('/preferencias/pecas-evitadas/peca-1', status: 401);
      await tester.ensureVisible(find.text('Parar de evitar'));
      await tester.tap(find.text('Parar de evitar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sessão expirada ou inválida. Não foi possível atualizar a peça.'),
        findsOneWidget,
      );
    });

    testWidgets('Se a lista de evitadas falhar ao carregar, o detalhe segue utilizável', (
      tester,
    ) async {
      final service = _PreferenciaServiceEvitadas([])
        ..erroAoListar = _erro('/preferencias/evitadas');
      await _abrirDetalhe(tester, service);

      expect(find.text('Vestidos'), findsOneWidget);
      expect(find.text('Evitada nas sugestões'), findsNothing);
      // Botão com texto no corpo do detalhe (antes, ícone na barra).
      final botao = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Evitar nas sugestões'),
      );
      expect(botao.onPressed, isNotNull);
    });

    testWidgets('Excluir uma peça evitada recarrega a lista de evitadas', (tester) async {
      final preferencias = _PreferenciaServiceEvitadas([_vestido, _calca]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferenciaServiceProvider.overrideWithValue(preferencias),
            pecaServiceProvider.overrideWithValue(_PecaServiceExclui(preferencias)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ListView(
                  children: [
                    const SecaoPecasEvitadas(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => PecaDetailView(peca: _vestido)),
                      ),
                      child: const Text('Abrir detalhe'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vestidos'), findsOneWidget);

      await tester.tap(find.text('Abrir detalhe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();

      // De volta à tela anterior: a seção já não mostra a peça excluída.
      expect(find.text('Vestidos'), findsNothing);
      expect(find.text('Calças'), findsOneWidget);
    });
  });

  group('Seção "Peças que evito"', () {
    testWidgets('Sem peças evitadas, orienta como marcar', (tester) async {
      await _abrirPreferencias(tester, _PreferenciaServiceEvitadas([]));

      expect(find.text('Peças que evito'), findsOneWidget);
      expect(find.textContaining('Nenhuma peça evitada.'), findsOneWidget);
    });

    testWidgets('Lista as peças evitadas com categoria e detalhes', (tester) async {
      await _abrirPreferencias(tester, _PreferenciaServiceEvitadas([_vestido, _calca]));

      expect(find.text('Vestidos'), findsOneWidget);
      expect(find.text('Longo · Azul'), findsOneWidget);
      expect(find.text('Calças'), findsOneWidget);
      expect(find.byTooltip('Parar de evitar Vestidos'), findsOneWidget);
    });

    testWidgets('Remover pede confirmação: cancelar mantém, confirmar tira da lista', (
      tester,
    ) async {
      final service = _PreferenciaServiceEvitadas([_vestido, _calca]);
      await _abrirPreferencias(tester, service);

      await tester.tap(find.byTooltip('Parar de evitar Vestidos'));
      await tester.pumpAndSettle();
      expect(find.text('Voltar a sugerir esta peça?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(service.pecas, hasLength(2));
      expect(find.text('Vestidos'), findsOneWidget);

      await tester.tap(find.byTooltip('Parar de evitar Vestidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Parar de evitar'));
      await tester.pumpAndSettle();
      expect(service.pecas.map((p) => p.id), ['peca-2']);
      expect(find.text('Vestidos'), findsNothing);
      expect(find.text('Calças'), findsOneWidget);
    });

    testWidgets('Falha ao remover mostra mensagem e mantém a peça', (tester) async {
      final service = _PreferenciaServiceEvitadas([_vestido])
        ..erroAoAlterar = _erro('/preferencias/pecas-evitadas/peca-1');
      await _abrirPreferencias(tester, service);

      await tester.tap(find.byTooltip('Parar de evitar Vestidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Parar de evitar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão com o servidor. Não foi possível atualizar a peça.'),
        findsOneWidget,
      );
      expect(find.text('Vestidos'), findsOneWidget);
    });

    testWidgets('Erro ao carregar as evitadas não derruba a tela; "Tentar novamente" refaz', (
      tester,
    ) async {
      final service = _PreferenciaServiceEvitadas([_calca])
        ..erroAoListar = _erro('/preferencias/evitadas');
      await _abrirPreferencias(tester, service);

      expect(find.text('Não foi possível carregar as peças evitadas.'), findsOneWidget);
      // As outras seções seguem na tela.
      expect(find.text('Estilos preferidos'), findsOneWidget);

      // As seções de peças e de combinações evitadas leem o mesmo provider:
      // as duas mostram o erro, e qualquer "Tentar novamente" recarrega ambas.
      expect(find.text('Tentar novamente'), findsNWidgets(2));
      service.erroAoListar = null;
      await tester.tap(find.text('Tentar novamente').first);
      await tester.pumpAndSettle();
      expect(find.text('Calças'), findsOneWidget);
    });
  });
}
