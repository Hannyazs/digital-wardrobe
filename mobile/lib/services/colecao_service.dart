import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/colecao.dart';

/// Chama os endpoints de app/api/v1/colecoes.py no backend (E8.F2.1).
class ColecaoService {
  final Dio _dio = ApiClient.instance;

  Future<List<Colecao>> listar() async {
    final response = await _dio.get('/colecoes');
    return (response.data as List)
        .map((json) => Colecao.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Colecao> criar(String nome) async {
    final response = await _dio.post('/colecoes', data: {'nome': nome});
    return Colecao.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Colecao> renomear(String id, String nome) async {
    final response = await _dio.patch('/colecoes/$id', data: {'nome': nome});
    return Colecao.fromJson(response.data as Map<String, dynamic>);
  }

  /// Exclui só a coleção: as referências dela ficam, sem coleção.
  Future<void> excluir(String id) async {
    await _dio.delete('/colecoes/$id');
  }
}
