import 'peca.dart';

/// Espelha app/schemas/peca.py::PecaParadaRead (E13.F1.1): uma peça sem uso
/// há 90 dias ou mais.
class PecaParada {
  const PecaParada({required this.peca, required this.ultimoUso, required this.diasParada});

  final Peca peca;

  /// Data do último uso; `null` se a peça nunca foi usada (conta do cadastro).
  final DateTime? ultimoUso;
  final int diasParada;

  factory PecaParada.fromJson(Map<String, dynamic> json) {
    final ultimoUso = json['ultimo_uso'] as String?;
    return PecaParada(
      peca: Peca.fromJson(json['peca'] as Map<String, dynamic>),
      ultimoUso: ultimoUso == null ? null : DateTime.parse(ultimoUso),
      diasParada: json['dias_parada'] as int,
    );
  }
}
