import '../core/network/api_client.dart';
import '../models/evitadas.dart';
import '../models/preferencia.dart';

/// Chama os endpoints de app/api/v1/preferencias.py no backend (E4.F1.1).
class PreferenciaService {
  final _dio = ApiClient.instance;

  /// `GET /preferencias`: sem nada salvo, o backend devolve os padrões.
  Future<Preferencia> obter() async {
    final response = await _dio.get('/preferencias');
    return Preferencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /preferencias`: envia só os [campos] que mudaram (chaves ausentes
  /// não são tocadas). Devolve o estado completo confirmado pelo servidor.
  Future<Preferencia> atualizar(Map<String, dynamic> campos) async {
    final response = await _dio.patch('/preferencias', data: campos);
    return Preferencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// `GET /preferencias/evitadas` (E4.F4.1): peças e pares de peças evitados.
  Future<Evitadas> listarEvitadas() async {
    final response = await _dio.get('/preferencias/evitadas');
    return Evitadas.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /preferencias/pecas-evitadas`: idempotente (marcar de novo não duplica).
  Future<void> evitarPeca(String pecaId) async {
    await _dio.post('/preferencias/pecas-evitadas', data: {'peca_id': pecaId});
  }

  /// `DELETE /preferencias/pecas-evitadas/{id}`: a peça volta a poder ser sugerida.
  Future<void> pararDeEvitarPeca(String pecaId) async {
    await _dio.delete('/preferencias/pecas-evitadas/$pecaId');
  }

  /// `POST /preferencias/combinacoes-evitadas` (E4.F4.3). Idempotente e sem
  /// ordem: o mesmo par, em qualquer ordem, devolve o registro existente com
  /// 200 (`jaExistia: true`) em vez de duplicar; um par novo vem com 201.
  Future<({CombinacaoEvitada par, bool jaExistia})> evitarCombinacao(
    String pecaAId,
    String pecaBId,
  ) async {
    final response = await _dio.post(
      '/preferencias/combinacoes-evitadas',
      data: {'peca_a_id': pecaAId, 'peca_b_id': pecaBId},
    );
    return (
      par: CombinacaoEvitada.fromJson(response.data as Map<String, dynamic>),
      jaExistia: response.statusCode == 200,
    );
  }

  /// `DELETE /preferencias/combinacoes-evitadas/{id}`.
  Future<void> pararDeEvitarCombinacao(String combinacaoId) async {
    await _dio.delete('/preferencias/combinacoes-evitadas/$combinacaoId');
  }
}
