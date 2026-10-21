import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_client.dart';
import '../models/peca.dart';

/// Chama os endpoints de app/api/v1/pecas.py no backend.
class PecaService {
  final Dio _dio = ApiClient.instance;

  /// O recorte (`XFile.fromData`) não tem nome fora da web; o backend deduz a
  /// extensão do arquivo salvo a partir dele, e o recorte é sempre PNG.
  String _nomeDoArquivo(XFile imagem) => imagem.name.isEmpty ? 'recorte.png' : imagem.name;

  Future<List<Peca>> listarPecas() async {
    final response = await _dio.get('/pecas');
    return (response.data as List).map((json) => Peca.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> processarImagem(XFile imagem) async {
    // Bytes em vez de MultipartFile.fromFile(path): `dart:io File`/path não
    // funciona no Flutter Web (única plataforma validada no momento).
    final bytes = await imagem.readAsBytes();
    final formData = FormData.fromMap({
      'arquivo': MultipartFile.fromBytes(bytes, filename: _nomeDoArquivo(imagem)),
    });
    final response = await _dio.post('/pecas/processar-imagem', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Fallback do E1.F1.4: salva a foto sem remoção de fundo, quando
  /// [processarImagem] falhou e o usuário optou por continuar assim mesmo.
  Future<Map<String, dynamic>> uploadImagemOriginal(XFile imagem) async {
    final bytes = await imagem.readAsBytes();
    final formData = FormData.fromMap({
      'arquivo': MultipartFile.fromBytes(bytes, filename: _nomeDoArquivo(imagem)),
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
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    final response = await _dio.post('/pecas', data: {
      'imagem_url': imagemUrl,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'tonalidade_cor': tonalidadeCor,
      'estacao': estacao,
      'estilo': estilo,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    });
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }

  /// Edita os metadados de uma peça existente (E1.F3.1) — nunca a imagem.
  Future<Peca> atualizarPeca({
    required String id,
    required String categoria,
    String? subcategoria,
    String? corPrincipal,
    String? tonalidadeCor,
    String? estacao,
    String? estilo,
    String? modelagem,
    List<String> ocasioes = const [],
  }) async {
    final response = await _dio.put('/pecas/$id', data: {
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'tonalidade_cor': tonalidadeCor,
      'estacao': estacao,
      'estilo': estilo,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    });
    return Peca.fromJson(response.data as Map<String, dynamic>);
  }

  /// Exclui uma peça (E1.F3.1) — física e definitiva, sem undo. Se ela está
  /// em looks, o backend responde 409 (ver [quantidadeDeLooksDoConflito]) até
  /// que [removerDosLooks] seja confirmado pelo usuário.
  Future<void> excluirPeca(String id, {bool removerDosLooks = false}) async {
    await _dio.delete(
      '/pecas/$id',
      queryParameters: removerDosLooks ? {'remover_dos_looks': true} : null,
    );
  }

  /// Quantos looks usam a peça, se [erro] for o 409 de "peça em looks";
  /// `null` para qualquer outro erro.
  static int? quantidadeDeLooksDoConflito(DioException erro) {
    if (erro.response?.statusCode != 409) return null;
    final dados = erro.response?.data;
    final detalhe = dados is Map ? dados['detail'] : null;
    if (detalhe is Map && detalhe['codigo'] == 'peca_em_looks') {
      return detalhe['looks'] as int?;
    }
    return null;
  }
}
