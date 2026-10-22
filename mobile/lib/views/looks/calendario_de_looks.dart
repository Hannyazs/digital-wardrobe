import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/uso_look.dart';
import 'looks_controller.dart';
import 'montar_look_controller.dart' show lookServiceProvider;
import 'widgets/pecas_do_look.dart';

/// Histórico de looks utilizados como calendário (E3.F4.3): grade do mês com
/// marcação nos dias que têm uso; tocar num dia mostra os looks daquele dia,
/// com opção de desfazer um registro. Busca só o mês visível
/// (`GET /looks/historico?de=&ate=`).
class HistoricoView extends ConsumerWidget {
  const HistoricoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesVisivelProvider);
    final usosAsync = ref.watch(historicoMesProvider(mes));
    final selecionado = ref.watch(diaSelecionadoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de looks')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(historicoMesProvider(mes));
          await ref.read(historicoMesProvider(mes).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _CabecalhoDoMes(mes: mes),
            const SizedBox(height: 8),
            _GradeDoMes(
              mes: mes,
              // Durante carregamento/erro a grade aparece sem marcações.
              usosPorDia: usosPorDia(usosAsync.valueOrNull ?? const []),
              selecionado: selecionado,
            ),
            const Divider(height: 32),
            usosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _Erro(
                mensagem: _mensagemDeErro(error),
                onTentarNovamente: () => ref.invalidate(historicoMesProvider(mes)),
              ),
              data: (usos) => _UsosDoDia(
                dia: selecionado,
                usos: selecionado == null ? const [] : usosPorDia(usos)[selecionado] ?? const [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mensagemDeErro(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Sessão expirada ou inválida. Não foi possível carregar seu histórico.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'A busca demorou demais. Verifique sua conexão e tente novamente.';
        case DioExceptionType.connectionError:
          return 'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
        default:
          return 'Não foi possível carregar seu histórico. Tente novamente.';
      }
    }
    return 'Não foi possível carregar seu histórico. Tente novamente.';
  }
}

class _CabecalhoDoMes extends ConsumerWidget {
  const _CabecalhoDoMes({required this.mes});

  final DateTime mes;

  void _irPara(WidgetRef ref, DateTime novoMes) {
    ref.read(mesVisivelProvider.notifier).state = novoMes;
    // Trocar de mês limpa a seleção; no mês atual volta a selecionar hoje.
    final agora = DateTime.now();
    final ehMesAtual = novoMes.year == agora.year && novoMes.month == agora.month;
    ref.read(diaSelecionadoProvider.notifier).state =
        ehMesAtual ? DateTime(agora.year, agora.month, agora.day) : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = DateTime.now();
    // Meses futuros não podem ter uso (o backend recusa datas futuras).
    final podeAvancar = mes.year < agora.year || (mes.year == agora.year && mes.month < agora.month);

    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _irPara(ref, DateTime(mes.year, mes.month - 1)),
        ),
        Expanded(
          child: Text(
            rotuloDoMes(mes),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: podeAvancar ? () => _irPara(ref, DateTime(mes.year, mes.month + 1)) : null,
        ),
      ],
    );
  }
}

class _GradeDoMes extends ConsumerWidget {
  const _GradeDoMes({required this.mes, required this.usosPorDia, required this.selecionado});

  final DateTime mes;
  final Map<DateTime, List<UsoLook>> usosPorDia;
  final DateTime? selecionado;

  static const _diasDaSemana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diasNoMes = DateTime(mes.year, mes.month + 1, 0).day;
    // Semana começa no domingo: `weekday` é 1 (seg) a 7 (dom), e `% 7` põe o domingo em 0.
    final vazios = DateTime(mes.year, mes.month, 1).weekday % 7;
    final celulas = <DateTime?>[
      for (var i = 0; i < vazios; i++) null,
      for (var d = 1; d <= diasNoMes; d++) DateTime(mes.year, mes.month, d),
    ];
    while (celulas.length % 7 != 0) {
      celulas.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final letra in _diasDaSemana)
              Expanded(
                child: Center(
                  child: Text(letra, style: Theme.of(context).textTheme.labelMedium),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var inicio = 0; inicio < celulas.length; inicio += 7)
          Row(
            children: [
              for (final dia in celulas.sublist(inicio, inicio + 7))
                Expanded(
                  child: dia == null
                      ? const SizedBox(height: 48)
                      : _CelulaDoDia(
                          dia: dia,
                          eHoje: dia == hoje,
                          selecionado: dia == selecionado,
                          temUso: usosPorDia.containsKey(dia),
                          // Dias futuros não podem ter uso.
                          habilitado: !dia.isAfter(hoje),
                          onTap: () => ref.read(diaSelecionadoProvider.notifier).state = dia,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _CelulaDoDia extends StatelessWidget {
  const _CelulaDoDia({
    required this.dia,
    required this.eHoje,
    required this.selecionado,
    required this.temUso,
    required this.habilitado,
    required this.onTap,
  });

  final DateTime dia;
  final bool eHoje;
  final bool selecionado;
  final bool temUso;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Semantics(
      label: temUso ? 'Dia ${dia.day}, com looks usados' : 'Dia ${dia.day}',
      button: true,
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selecionado ? cores.primary : null,
                border: eHoje && !selecionado ? Border.all(color: cores.primary) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      color: selecionado
                          ? cores.onPrimary
                          : habilitado
                              ? null
                              : Theme.of(context).disabledColor,
                    ),
                  ),
                  // Marcação de "tem uso neste dia".
                  Container(
                    key: temUso ? ValueKey('marca-${dia.day}') : null,
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: temUso ? (selecionado ? cores.onPrimary : cores.primary) : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsosDoDia extends StatelessWidget {
  const _UsosDoDia({required this.dia, required this.usos});

  final DateTime? dia;
  final List<UsoLook> usos;

  @override
  Widget build(BuildContext context) {
    if (dia == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Toque num dia para ver os looks usados')),
      );
    }

    final rotulo = rotuloDoDia(dia!, DateTime.now());
    if (usos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.history, size: 48),
            const SizedBox(height: 12),
            Text('Nenhum look usado — $rotulo', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'No menu de um look, toque em "Usei hoje" ou "Usei em outra data…" para registrar',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(rotulo, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final uso in usos) _UsoCard(uso: uso),
      ],
    );
  }
}

class _UsoCard extends ConsumerWidget {
  const _UsoCard({required this.uso});

  final UsoLook uso;

  Future<void> _remover(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover este registro?'),
        content: Text('O uso de "${uso.look.nome}" será removido do histórico.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return; // cancelado (ou diálogo dispensado): nada muda
    try {
      await ref.read(lookServiceProvider).removerUso(uso.id);
      ref.invalidate(historicoMesProvider);
      ref.invalidate(historicoProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_mensagemRemocao(error))));
    }
  }

  String _mensagemRemocao(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'Sessão expirada ou inválida. Não foi possível remover o registro.';
      if (status == 404) return 'Registro não encontrado. Atualize o histórico.';
      if (error.type == DioExceptionType.connectionError) {
        return 'Sem conexão com o servidor. Não foi possível remover o registro.';
      }
    }
    return 'Não foi possível remover o registro. Tente novamente.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    uso.look.nome,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover registro',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remover(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PecasDoLook(pecas: uso.look.pecas),
          ],
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(mensagem, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTentarNovamente,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
