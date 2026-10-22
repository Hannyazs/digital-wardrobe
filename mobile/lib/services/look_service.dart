import '../core/network/api_client.dart';
import '../models/look.dart';
import '../models/uso_look.dart';

/// Formata só a data (`yyyy-MM-dd`), no fuso local do dispositivo. Manual, e
/// não `toIso8601String()`: esse incluiria hora/fuso e sairia do contrato
/// `date` do backend (E3.F4.1); `toUtc()` registraria o dia errado à noite.
String formatarDataApi(DateTime data) {
  final mm = data.month.toString().padLeft(2, '0');
  final dd = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mm-$dd';
}

/// Chama os endpoints de app/api/v1/looks.py no backend (E3.F1.1).
class LookService {
  final _dio = ApiClient.instance;

  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    final response = await _dio.post('/looks', data: {
      'nome': nome,
      'peca_ids': pecaIds,
      if (ocasioes.isNotEmpty) 'ocasioes': ocasioes,
    });
    return Look.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Look>> listarLooks() async {
    final response = await _dio.get('/looks');
    return (response.data as List).map((json) => Look.fromJson(json)).toList();
  }

  /// `PATCH /looks/{id}` (E3.F2.1). Recebe um mapa de campos: `favorito`
  /// (E3.F2.2) e `ocasioes` (E3.F3.2, lista). Para limpar as ocasiões, enviar
  /// `[]` (chave omitida = "não mexer"; `null` é recusado pelo backend).
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    final response = await _dio.patch('/looks/$id', data: campos);
    return Look.fromJson(response.data as Map<String, dynamic>);
  }

  /// `DELETE /looks/{id}` (E3.F5.1): arquiva o look. Ele some da lista, mas os
  /// usos continuam no histórico (calendário).
  Future<void> excluirLook(String id) async {
    await _dio.delete('/looks/$id');
  }

  /// `POST /looks/{id}/usos` (E3.F4.1): registra um uso do look na [data]
  /// (só o dia; sem horário). A resposta (uso com o look embutido) só será
  /// consumida pelo histórico (E3.F4.3), por isso retorna `void` por ora.
  Future<void> registrarUso(String lookId, DateTime data) async {
    await _dio.post('/looks/$lookId/usos', data: {'usado_em': formatarDataApi(data)});
  }

  /// `GET /looks/historico` (E3.F4.1): usos do usuário, mais recentes primeiro
  /// (o backend limita a 100 por padrão). [de] e [ate] (inclusivos, só o dia)
  /// restringem o período — o calendário busca só o mês visível.
  Future<List<UsoLook>> listarHistorico({DateTime? de, DateTime? ate, int? limite}) async {
    final response = await _dio.get('/looks/historico', queryParameters: {
      if (de != null) 'de': formatarDataApi(de),
      if (ate != null) 'ate': formatarDataApi(ate),
      if (limite != null) 'limite': limite,
    });
    return (response.data as List)
        .map((json) => UsoLook.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `DELETE /looks/usos/{id}` (E3.F4.1): desfaz um registro de uso.
  Future<void> removerUso(String usoId) async {
    await _dio.delete('/looks/usos/$usoId');
  }
}
