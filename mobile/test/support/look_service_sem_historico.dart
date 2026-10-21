import 'package:guarda_roupa_app/models/uso_look.dart';
import 'package:guarda_roupa_app/services/look_service.dart';

/// Base dos `LookService` falsos dos testes que montam `LooksView`.
///
/// Desde a E3.F4.4 a lista de looks lê o histórico (`GET /looks/historico`)
/// para mostrar "Usado há N dias". Sem este override, um fake que não trata o
/// histórico cairia no `Dio` real durante o teste. Aqui o histórico é vazio
/// (nenhum rótulo); testes que precisam de usos sobrescrevem `listarHistorico`.
class LookServiceSemHistorico extends LookService {
  @override
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async => [];
}
