import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/pasta_look.dart';

/// Chama os endpoints de app/api/v1/pastas.py no backend (E3.F6.1).
class PastaService {
  final Dio _dio = ApiClient.instance;

  /// Em ordem alfabética, com a quantidade de looks de cada uma.
  Future<List<PastaLook>> listar() async {
    final response = await _dio.get('/pastas');
    return (response.data as List)
        .map((json) => PastaLook.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<PastaLook> criar(String nome) async {
    final response = await _dio.post('/pastas', data: {'nome': nome});
    return PastaLook.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PastaLook> renomear(String id, String nome) async {
    final response = await _dio.patch('/pastas/$id', data: {'nome': nome});
    return PastaLook.fromJson(response.data as Map<String, dynamic>);
  }

  /// Exclui só a pasta: os looks dela ficam, sem pasta.
  Future<void> excluir(String id) async {
    await _dio.delete('/pastas/$id');
  }
}
