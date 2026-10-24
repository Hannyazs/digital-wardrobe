import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_client.dart';
import '../models/referencia.dart';
import '../models/sugestao_de_look.dart';

/// Chama os endpoints de app/api/v1/referencias.py no backend (E8.F1.1).
class ReferenciaService {
  final Dio _dio = ApiClient.instance;

  Future<List<Referencia>> listar() async {
    final response = await _dio.get('/referencias');
    return (response.data as List)
        .map((json) => Referencia.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Referencia> atualizarNota(String id, String? nota) async {
    final response = await _dio.patch('/referencias/$id', data: {'nota': nota});
    return Referencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// Muda a coleção (E8.F2.2); `null` tira a referência da coleção. A nota
  /// não vai no corpo, então o servidor não mexe nela.
  Future<Referencia> mover(String id, String? colecaoId) async {
    final response =
        await _dio.patch('/referencias/$id', data: {'colecao_id': colecaoId});
    return Referencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// Liga a referência a um look salvo (E8.F3.1); `null` desliga.
  Future<Referencia> ligarLook(String id, String? lookId) async {
    final response = await _dio.patch('/referencias/$id', data: {'look_id': lookId});
    return Referencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// Troca a lista de etiquetas inteira (E8.F4.1); lista vazia limpa.
  Future<Referencia> atualizarEtiquetas(String id, List<String> etiquetas) async {
    final response = await _dio.patch('/referencias/$id', data: {'etiquetas': etiquetas});
    return Referencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// Pede à IA um look para a referência (E8.F5.2). Demora (uma comparação por
  /// etiqueta, perto de 1 minuto): o tempo de espera é maior só nesta chamada.
  ///
  /// `connectTimeout` também sobe: no navegador o Dio o usa como "tempo até a
  /// resposta começar" quando a requisição não tem corpo (esta não tem), e o
  /// servidor só responde ao terminar a análise — com os 15 s padrão ela falhava
  /// como "sem conexão" mesmo com o servidor funcionando.
  Future<SugestaoDeLook> sugerirLook(String id) async {
    final response = await _dio.post(
      '/referencias/$id/sugestao-de-look',
      options: Options(
        connectTimeout: const Duration(seconds: 150),
        receiveTimeout: const Duration(seconds: 150),
      ),
    );
    return SugestaoDeLook.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> excluir(String id) async {
    await _dio.delete('/referencias/$id');
  }

  /// Envia a imagem como veio da galeria. Bytes em vez de um caminho de
  /// arquivo: `dart:io File` não funciona no Flutter Web.
  Future<Referencia> criar(XFile imagem,
      {String? nota, String? colecaoId}) async {
    final bytes = await imagem.readAsBytes();
    final formData = FormData.fromMap({
      'arquivo': MultipartFile.fromBytes(
        bytes,
        filename: imagem.name.isEmpty ? 'referencia.jpg' : imagem.name,
      ),
      if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
      if (colecaoId != null) 'colecao_id': colecaoId,
    });
    final response = await _dio.post('/referencias', data: formData);
    return Referencia.fromJson(response.data as Map<String, dynamic>);
  }
}
