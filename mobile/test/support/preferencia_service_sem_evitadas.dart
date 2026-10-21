import 'package:guarda_roupa_app/models/evitadas.dart';
import 'package:guarda_roupa_app/models/preferencia.dart';
import 'package:guarda_roupa_app/services/preferencia_service.dart';

/// Base dos `PreferenciaService` falsos de testes que montam o detalhe da peça
/// ou a tela de preferências.
///
/// Desde a E4.F4.2 as duas telas leem as peças evitadas
/// (`GET /preferencias/evitadas`). Sem este override, um fake que não trata
/// isso cairia no `Dio` real durante o teste. Aqui não há nada evitado e as
/// preferências são as padrão; testes que precisam de outro estado
/// sobrescrevem os métodos.
class PreferenciaServiceSemEvitadas extends PreferenciaService {
  @override
  Future<Preferencia> obter() async => const Preferencia();

  @override
  Future<Evitadas> listarEvitadas() async => const Evitadas();
}
