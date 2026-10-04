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

  /// Recebe só os campos que `PecaCreate` (backend) espera, não um [Peca]
  /// completo — este ainda não existe antes da criação (exige `id`, que só
  /// o backend atribui na resposta).
  Future<Peca> criarPeca({
    required String imagemUrl,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? estacao,
    String? ocasiao,
  }) async {
    final response = await _dio.post('/pecas', data: {
      'imagem_url': imagemUrl,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'estacao': estacao,
      'ocasiao': ocasiao,
    });
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }

  /// Edita os metadados de uma peça existente (E1.F3.1) — nunca a imagem.
  Future<Peca> atualizarPeca({
    required String id,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? estacao,
    String? ocasiao,
  }) async {
    final response = await _dio.put('/pecas/$id', data: {
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'estacao': estacao,
      'ocasiao': ocasiao,
    });
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }

  /// Exclui uma peça (E1.F3.1) — física e definitiva, sem undo.
  Future<void> excluirPeca(String id) async {
    await _dio.delete('/pecas/$id');
  }
}
