import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart';

/// `SugestaoService` falso para testes que montam a Casa (`HomeView`/`HomeShell`)
/// sem se importar com o card "Look do dia" (E6.F1.2): sem ele, o card cairia
/// no `Dio` real. Devolve "sem look" com um motivo, sem peças nem botões.
class SugestaoServiceSemLookDoDia extends SugestaoService {
  @override
  Future<LookDoDia> lookDoDia({
    required DateTime data,
    String? ocasiao,
    List<List<String>> descartados = const [],
  }) async =>
      LookDoDia(ocasiao: ocasiao ?? 'Casual', motivo: 'Cadastre mais peças para ter um look do dia.');
}
