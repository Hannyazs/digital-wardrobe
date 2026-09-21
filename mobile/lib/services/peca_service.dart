import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_client.dart';
import '../models/peca.dart';

/// Chama os endpoints de app/api/v1/pecas.py no backend.
class PecaService {
  final Dio _dio = ApiClient.instance;

  Future<List<Peca>> listarPecas() async {
    final response = await _dio.get('/pecas');
    return (response.data as List).map((json) => Peca.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    // Bytes em vez de MultipartFile.fromFile(path): `dart:io File`/path não
    // funciona no Flutter Web (única plataforma validada no momento).
    final bytes = await imagem.readAsBytes();
    final formData = FormData.fromMap({
      'arquivo': MultipartFile.fromBytes(bytes, filename: imagem.name),
    });
    final response = await _dio.post('/pecas/processar-imagem', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Fallback do E1.F1.4: salva a foto sem remoção de fundo, quando
  /// [processarImagem] falhou e o usuário optou por continuar assim mesmo.
  Future<Map<String, dynamic>> uploadImagemOriginal(XFile imagem) async {
    final bytes = await imagem.readAsBytes();
    final formData = FormData.fromMap({
      'arquivo': MultipartFile.fromBytes(bytes, filename: imagem.name),
    });
    final response = await _dio.post('/pecas/upload-original', data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Peca> criarPeca(Peca peca) async {
    final response = await _dio.post('/pecas', data: peca.toJson());
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }
}
