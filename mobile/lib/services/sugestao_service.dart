import '../core/network/api_client.dart';
import '../models/sugestao.dart';
import 'look_service.dart' show formatarDataApi;

/// Filtros da tela de sugestões (E5.F2.1). `null` = sem filtro.
class FiltroSugestoes {
  const FiltroSugestoes({this.ocasiao, this.estilo, this.estacao, this.cor});

  final String? ocasiao;
  final String? estilo;
  final String? estacao;
  final String? cor;

  Map<String, dynamic> toJson() => {
        if (ocasiao != null) 'ocasiao': ocasiao,
        if (estilo != null) 'estilo': estilo,
        if (estacao != null) 'estacao': estacao,
        if (cor != null) 'cor': cor,
      };
}

/// Chama `POST /sugestoes` (app/api/v1/sugestoes.py, E5.F1.2).
class SugestaoService {
  final _dio = ApiClient.instance;

  Future<PaginaSugestoes> sugerir({
    FiltroSugestoes filtros = const FiltroSugestoes(),
    String? pecaBaseId,
    int pagina = 1,
    List<List<String>> descartados = const [],
  }) async {
    final response = await _dio.post('/sugestoes', data: {
      ...filtros.toJson(),
      if (pecaBaseId != null) 'peca_base_id': pecaBaseId,
      'pagina': pagina,
      'descartados': descartados,
    });
    return PaginaSugestoes.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /sugestoes/look-do-dia` (E6.F1.1). [data] é o dia local do
  /// aparelho; sem [ocasiao], o backend usa a salva nas preferências ou "Casual".
  Future<LookDoDia> lookDoDia({
    required DateTime data,
    String? ocasiao,
    List<List<String>> descartados = const [],
  }) async {
    final response = await _dio.post('/sugestoes/look-do-dia', data: {
      'data': formatarDataApi(data),
      if (ocasiao != null) 'ocasiao': ocasiao,
      'descartados': descartados,
    });
    return LookDoDia.fromJson(response.data as Map<String, dynamic>);
  }
}
