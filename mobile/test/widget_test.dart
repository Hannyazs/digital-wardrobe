// Smoke test básico: confirma que o app sobe e abre no armário.
// O teste original aqui era o boilerplate padrão do `flutter create`
// (referenciava uma classe `MyApp` de contador que nunca existiu neste
// projeto) — substituído durante a implementação da PBI E1.F1.1, ver
// docs/PBIs/E1-F1-adicionar-foto/E1.F1.1-captura-e-selecao-de-foto.md.
//
// Os testes de "envio da foto" (E1.F1.3) usam um PecaService falso — nunca
// batem numa API real — para exercitar os estados de carregamento e erro
// da UploadView. Ver docs/PBIs/E1-F1-adicionar-foto/E1.F1.3-envio-e-exibicao-do-resultado.md.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:guarda_roupa_app/main.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart';
import 'package:guarda_roupa_app/views/upload/upload_view.dart';
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;

import 'support/look_service_sem_historico.dart';
import 'support/sugestao_service_sem_look_do_dia.dart';

/// Substitui o [UploadPhotoController] real: começa direto com uma foto
/// "selecionada" (via `XFile.fromData`, sem tocar nenhum canal de
/// plataforma), pra testar a etapa de envio sem precisar acionar o
/// seletor de câmera/galeria de verdade.
// PNG 1x1 transparente válido — bytes vazios fazem o Image.memory da
// UploadView lançar "Invalid image data" e derrubar o teste.
final Uint8List _pngDeTeste = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _FotoJaSelecionadaController extends UploadPhotoController {
  @override
  XFile? build() => XFile.fromData(_pngDeTeste, name: 'foto.png');
}

/// Armário sem peças, usado nos testes que só precisam renderizar
/// `WardrobeView`/`HomeShell` sem bater numa API real (E2.F1.1).
class _PecaServiceArmarioVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _PecaServiceComSucesso extends _PecaServiceArmarioVazio {
  @override
  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {'imagem_url': 'http://localhost:8000/uploads/foto.png', 'sugestao': <String, dynamic>{}};
  }
}

class _PecaServiceComErro extends PecaService {
  @override
  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas/processar-imagem'),
      type: DioExceptionType.connectionError,
    );
  }
}

/// Processamento sempre falha, mas o fallback de upload sem remoção de
/// fundo (E1.F1.4) funciona — cobre o botão "Continuar sem remoção de fundo".
class _PecaServiceComFallback extends PecaService {
  @override
  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas/processar-imagem'),
      type: DioExceptionType.connectionError,
    );
  }

  @override
  Future<Map<String, dynamic>> uploadImagemOriginal(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {'imagem_url': 'http://localhost:8000/uploads/original.jpg'};
  }
}

/// Tanto o processamento quanto o fallback falham — não pode virar um beco
/// sem saída dentro do beco sem saída.
class _PecaServiceTudoFalha extends PecaService {
  @override
  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas/processar-imagem'),
      type: DioExceptionType.connectionError,
    );
  }

  @override
  Future<Map<String, dynamic>> uploadImagemOriginal(XFile imagem) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas/upload-original'),
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
  testWidgets('App abre na Home; aba Armário mostra o guarda-roupa', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceArmarioVazio()),
          // A Casa mostra o calendário de looks, que busca o histórico.
          lookServiceProvider.overrideWithValue(LookServiceSemHistorico()),
          sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
        ],
        child: const GuardaRoupaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Redesign visual (Etapa 4): a aba inicial agora é "Casa", não o
    // armário diretamente.
    expect(find.text('Welcome!'), findsOneWidget);

    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();

    expect(find.text('Meu Guarda-Roupa'), findsOneWidget);
  });

  testWidgets('FAB do armário navega para a tela de adicionar peça (E1.F1.1)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceArmarioVazio()),
          // A Casa mostra o calendário de looks, que busca o histórico.
          lookServiceProvider.overrideWithValue(LookServiceSemHistorico()),
          sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
        ],
        child: const GuardaRoupaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Redesign visual (Etapa 4): precisa entrar na aba Armário primeiro —
    // a Home tem seu próprio atalho "Adicionar peça", que usa outro ícone.
    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_a_photo));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar Peça'), findsOneWidget);
    expect(find.text('Adicione uma foto da peça'), findsOneWidget);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
  });

  testWidgets('Confirmar mostra carregamento e depois o resultado processado (E1.F1.3)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadPhotoProvider.overrideWith(_FotoJaSelecionadaController.new),
          pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso()),
        ],
        child: const MaterialApp(home: UploadView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(find.text('Processando foto...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('Fundo removido! Revise os dados na próxima etapa.'), findsOneWidget);
  });

  testWidgets('"Continuar" na tela de resultado abre o formulário de metadados (E1.F2.1)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadPhotoProvider.overrideWith(_FotoJaSelecionadaController.new),
          pecaServiceProvider.overrideWithValue(_PecaServiceComSucesso()),
        ],
        child: const MaterialApp(home: UploadView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes da peça'), findsOneWidget);
  });

  testWidgets('Falha no envio mostra mensagem de erro com opção de tentar novamente (E1.F1.3)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadPhotoProvider.overrideWith(_FotoJaSelecionadaController.new),
          pecaServiceProvider.overrideWithValue(_PecaServiceComErro()),
        ],
        child: const MaterialApp(home: UploadView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    // Não trava: dá pra tentar de novo sem escolher a foto outra vez.
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Processando foto...'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    '"Continuar sem remoção de fundo" mostra o resultado com aviso (E1.F1.4)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadPhotoProvider.overrideWith(_FotoJaSelecionadaController.new),
            pecaServiceProvider.overrideWithValue(_PecaServiceComFallback()),
          ],
          child: const MaterialApp(home: UploadView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Continuar sem remoção de fundo'), findsOneWidget);

      await tester.tap(find.text('Continuar sem remoção de fundo'));
      await tester.pump();
      expect(find.text('Processando foto...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(
        find.text('Continuando sem remoção de fundo — você pode ajustar isso depois.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Fallback também falhando volta pro estado de erro, sem travar (E1.F1.4)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadPhotoProvider.overrideWith(_FotoJaSelecionadaController.new),
            pecaServiceProvider.overrideWithValue(_PecaServiceTudoFalha()),
          ],
          child: const MaterialApp(home: UploadView()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar sem remoção de fundo'));
      await tester.pumpAndSettle();

      // Ainda dá pra tentar qualquer um dos dois caminhos de novo.
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Continuar sem remoção de fundo'), findsOneWidget);
      expect(find.text('Trocar foto'), findsOneWidget);
    },
  );
}
