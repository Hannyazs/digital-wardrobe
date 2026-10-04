import '../core/network/api_client.dart';
import '../models/look.dart';

/// Chama os endpoints de app/api/v1/looks.py no backend (E3.F1.1).
class LookService {
  final _dio = ApiClient.instance;

  Future<Look> criarLook({required String nome, required List<String> pecaIds}) async {
    final response = await _dio.post('/looks', data: {
      'nome': nome,
      'peca_ids': pecaIds,
    });
    return Look.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Look>> listarLooks() async {
    final response = await _dio.get('/looks');
    return (response.data as List).map((json) => Look.fromJson(json)).toList();
  }
}
