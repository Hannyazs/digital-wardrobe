import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/peca.dart';

/// Chama os endpoints de app/api/v1/pecas.py no backend.
class PecaService {
  final Dio _dio = ApiClient.instance;

  Future<List<Peca>> listarPecas() async {
    final response = await _dio.get('/pecas');
    return (response.data as List).map((json) => Peca.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> processarImagem(File imagem) async {
    final formData = FormData.fromMap({
      'arquivo': await MultipartFile.fromFile(imagem.path),
    });
    final response = await _dio.post('/pecas/processar-imagem', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Peca> criarPeca(Peca peca) async {
    final response = await _dio.post('/pecas', data: peca.toJson());
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }
}
