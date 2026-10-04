import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Configuração global de testes (carregada automaticamente pelo
/// `flutter test` por estar em `test/flutter_test_config.dart`).
///
/// Desabilita o download de fontes em runtime do `google_fonts`
/// (AppTextStyles, Etapa 0 do redesign visual) — sem isso, cada teste que
/// monta uma tela tenta baixar as fontes da internet, o que não funciona
/// (ou é lento/instável) num ambiente de teste sem rede garantida, e deixa
/// timers pendentes que derrubam `pumpAndSettle`. Os testes passam a
/// renderizar com a fonte padrão de fallback, o que não afeta nenhuma
/// asserção (nenhum teste verifica a fonte usada).
FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
