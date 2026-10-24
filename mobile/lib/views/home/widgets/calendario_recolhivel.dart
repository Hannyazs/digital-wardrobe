import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../looks/calendario_de_looks.dart';
import '../../looks/looks_controller.dart';

/// "Calendário de looks" da Casa, recolhido por padrão: só o título, o mês e o
/// ano visíveis e, se o histórico do mês já chegou, quantos usos há nele.
/// Tocar abre o calendário completo ([CalendarioDeLooks], com navegação entre
/// meses, dias marcados e looks do dia) ali mesmo; tocar de novo recolhe.
class CalendarioRecolhivel extends ConsumerStatefulWidget {
  const CalendarioRecolhivel({super.key});

  @override
  ConsumerState<CalendarioRecolhivel> createState() => _CalendarioRecolhivelState();
}

class _CalendarioRecolhivelState extends ConsumerState<CalendarioRecolhivel> {
  bool _aberto = false;

  /// Resumo só com dado real: sem histórico carregado (carregando ou erro)
  /// não mostra contagem.
  String? _resumo(DateTime mes) {
    final usos = ref.watch(historicoMesProvider(mes)).valueOrNull;
    if (usos == null) return null;
    return switch (usos.length) {
      0 => 'Nenhum uso registrado neste mês',
      1 => '1 uso registrado neste mês',
      final n => '$n usos registrados neste mês',
    };
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(mesVisivelProvider);
    final resumo = _resumo(mes);
    final tema = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _aberto,
            label: 'Calendário de looks, ${rotuloDoMes(mes)}',
            hint: _aberto ? 'Toque para recolher' : 'Toque para expandir',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () => setState(() => _aberto = !_aberto),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.sageEscuro),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calendário de looks', style: tema.titleMedium),
                              // Aberto, o mês já aparece no cabeçalho do calendário.
                              if (!_aberto)
                                Text(
                                  resumo == null
                                      ? rotuloDoMes(mes)
                                      : '${rotuloDoMes(mes)} · $resumo',
                                  style: tema.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _aberto ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.expand_more, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _aberto
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: CalendarioDeLooks(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
