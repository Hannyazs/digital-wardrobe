// Testes do recorte manual da foto antes do envio (RecorteView + UploadView).
// Nenhum envio real: só a etapa local de ajuste, prévia e troca da foto.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:guarda_roupa_app/views/upload/recorte_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart';
import 'package:guarda_roupa_app/views/upload/upload_view.dart';

/// PNG sólido 200x100 gerado em memória (sem arquivo de asset).
Future<Uint8List> _png(int largura, int altura) async {
  final gravador = ui.PictureRecorder();
  Canvas(gravador).drawRect(
    Rect.fromLTWH(0, 0, largura.toDouble(), altura.toDouble()),
    Paint()..color = Colors.teal,
  );
  final imagem = await gravador.endRecording().toImage(largura, altura);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  return dados!.buffer.asUint8List();
}

class _FotoJaSelecionada extends UploadPhotoController {
  _FotoJaSelecionada(this._bytes);

  final Uint8List _bytes;

  @override
  XFile? build() => XFile.fromData(_bytes, name: 'foto.png');
}

/// Avança frames sem esperar "assentar": a área de recorte mantém um
/// indicador de carregamento animado enquanto decodifica a imagem.
Future<void> _avancar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _aguardar(WidgetTester tester, Finder alvo) async {
  // O recorte decodifica/recorta num isolate: precisa de tempo real.
  for (var i = 0; i < 100 && alvo.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// "Recortar" também existe na prévia da UploadView (rota de baixo).
final _recortarNaTelaDeRecorte =
    find.descendant(of: find.byType(RecorteView), matching: find.text('Recortar'));

/// Espera a imagem terminar de carregar na área de recorte (some o spinner).
Future<void> _aguardarImagemPronta(WidgetTester tester) async {
  final spinner = find.descendant(
    of: find.byType(RecorteView),
    matching: find.byType(CircularProgressIndicator),
  );
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
    if (i > 2 && spinner.evaluate().isEmpty) return;
  }
}

void main() {
  testWidgets('Prévia da foto oferece "Recortar" e abre a tela de recorte; cancelar mantém a foto', (
    WidgetTester tester,
  ) async {
    final bytes = (await tester.runAsync(() => _png(200, 100)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uploadPhotoProvider.overrideWith(() => _FotoJaSelecionada(bytes))],
        child: const MaterialApp(home: UploadView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recortar'));
    await _avancar(tester);
    expect(find.text('Recortar foto'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Voltou à prévia, com a mesma foto.
    expect(find.text('Confirmar'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(UploadView)));
    expect((await tester.runAsync(() => container.read(uploadPhotoProvider)!.readAsBytes()))!, bytes);
  });

  testWidgets('Recorta de verdade, mostra a prévia, permite refazer e usar o recorte', (
    WidgetTester tester,
  ) async {
    final bytes = (await tester.runAsync(() => _png(200, 100)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uploadPhotoProvider.overrideWith(() => _FotoJaSelecionada(bytes))],
        child: const MaterialApp(home: UploadView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recortar'));
    await _avancar(tester);

    // Espera a imagem carregar na área de recorte e recorta.
    await _aguardarImagemPronta(tester);
    await tester.tap(_recortarNaTelaDeRecorte);
    await _aguardar(tester, find.text('Prévia do recorte'));
    expect(find.text('Prévia do recorte'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Refazer volta ao ajuste.
    await tester.tap(find.text('Refazer recorte'));
    await _avancar(tester);
    expect(find.text('Recortar foto'), findsOneWidget);

    await _aguardarImagemPronta(tester);
    await tester.tap(_recortarNaTelaDeRecorte);
    await _aguardar(tester, find.text('Usar recorte'));
    await tester.tap(find.text('Usar recorte'));
    await tester.pumpAndSettle();

    // A foto do cadastro passa a ser o recorte (PNG novo, diferente do original).
    final container = ProviderScope.containerOf(tester.element(find.byType(UploadView)));
    final foto = container.read(uploadPhotoProvider)!;
    // (`name` só é preservado na web; o PecaService cobre o caso vazio.)
    final recortada = (await tester.runAsync(foto.readAsBytes))!;
    expect(recortada, isNot(bytes));
    final decodificada = (await tester.runAsync(() => ui.instantiateImageCodec(recortada)))!;
    final quadro = (await tester.runAsync(decodificada.getNextFrame))!;
    expect(quadro.image.width, lessThanOrEqualTo(200));
    expect(quadro.image.height, lessThanOrEqualTo(100));
  });

  testWidgets('RecorteView devolve null ao cancelar, sem alterar nada', (
    WidgetTester tester,
  ) async {
    final bytes = (await tester.runAsync(() => _png(200, 100)))!;
    Uint8List? resultado = Uint8List(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => resultado = await Navigator.of(context)
                .push<Uint8List>(MaterialPageRoute(builder: (_) => RecorteView(imagem: bytes))),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await _avancar(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, isNull);
  });
}
