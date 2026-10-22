import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/peca_opcoes.dart' show ocasioesFixas;
import '../../models/look.dart';
import '../../models/uso_look.dart';
import 'montar_look_controller.dart' show lookServiceProvider;

/// Lista de looks do usuário (E3.F1.3). `autoDispose` para rebuscar sozinho
/// sempre que a tela de "Looks" for recriada (ex: ao voltar da montagem),
/// mesmo padrão de `pecaListProvider` (wardrobe_controller.dart).
final lookListProvider = FutureProvider.autoDispose<List<Look>>((ref) {
  return ref.watch(lookServiceProvider).listarLooks();
});

/// Filtro da listagem de looks: favoritos (E3.F2.2) e ocasiões (E3.F3.3).
/// Favoritos e ocasiões combinam por E lógico; entre as ocasiões marcadas vale
/// o OU (basta o look ter uma delas).
class FiltroLooks {
  const FiltroLooks({this.somenteFavoritos = false, this.ocasioes = const {}});

  final bool somenteFavoritos;
  final Set<String> ocasioes;

  bool get ativo => somenteFavoritos || ocasioes.isNotEmpty;

  FiltroLooks copyWith({bool? somenteFavoritos, Set<String>? ocasioes}) {
    return FiltroLooks(
      somenteFavoritos: somenteFavoritos ?? this.somenteFavoritos,
      ocasioes: ocasioes ?? this.ocasioes,
    );
  }

  /// Marca ou desmarca [ocasiao] (seleção múltipla).
  FiltroLooks alternarOcasiao(String ocasiao) {
    final novas = {...ocasioes};
    novas.contains(ocasiao) ? novas.remove(ocasiao) : novas.add(ocasiao);
    return copyWith(ocasioes: novas);
  }
}

/// Sem `autoDispose`: `HomeShell` mantém `LooksView` montada, e o filtro deve
/// sobreviver à troca de aba.
final filtroLooksProvider = StateProvider<FiltroLooks>((ref) => const FiltroLooks());

/// Filtragem client-side, como `filtrarPecas` (E2.F2.1).
List<Look> filtrarLooks(List<Look> looks, FiltroLooks filtro) {
  return looks.where((look) {
    if (filtro.somenteFavoritos && !look.favorito) return false;
    // OU entre as ocasiões marcadas, por comparação exata; look sem ocasião
    // nunca casa quando há alguma ocasião marcada.
    if (filtro.ocasioes.isNotEmpty && !look.ocasioes.any(filtro.ocasioes.contains)) return false;
    return true;
  }).toList();
}

/// Opções de ocasião do filtro de looks: as que algum look tem (na ordem de
/// `ocasioesFixas`, depois as personalizadas), mais as já marcadas, para
/// poderem ser desmarcadas.
List<String> ocasioesDosLooks(List<Look> looks, Set<String> marcadas) {
  final existentes = {...looks.expand((l) => l.ocasioes), ...marcadas};
  final extras = existentes.where((o) => !ocasioesFixas.contains(o)).toList()..sort();
  return [...ocasioesFixas.where(existentes.contains), ...extras];
}

/// Histórico de usos (E3.F4.3). `autoDispose`: rebusca ao abrir a tela, então
/// um uso recém-registrado (E3.F4.2) aparece sem puxar para atualizar. O
/// registro e a remoção ainda invalidam o provider explicitamente.
final historicoProvider = FutureProvider.autoDispose<List<UsoLook>>((ref) {
  return ref.watch(lookServiceProvider).listarHistorico();
});

/// Usos de um mês para o calendário (E3.F4.3): busca só o período visível.
/// A chave é o primeiro dia do mês (`DateTime(ano, mes)`). 500 é o máximo que
/// o backend aceita; um mês dificilmente chega perto.
final historicoMesProvider =
    FutureProvider.autoDispose.family<List<UsoLook>, DateTime>((ref, mes) {
  return ref.watch(lookServiceProvider).listarHistorico(
        de: DateTime(mes.year, mes.month, 1),
        ate: DateTime(mes.year, mes.month + 1, 0),
        limite: 500,
      );
});

/// Mês exibido no calendário (primeiro dia do mês) e dia selecionado.
final mesVisivelProvider = StateProvider.autoDispose<DateTime>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month);
});

final diaSelecionadoProvider = StateProvider.autoDispose<DateTime?>((ref) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, agora.day);
});

const _nomesDosMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// "Outubro 2026".
String rotuloDoMes(DateTime mes) => '${_nomesDosMeses[mes.month - 1]} ${mes.year}';

/// Usos indexados por dia (`DateTime` sem hora), para marcar o calendário.
Map<DateTime, List<UsoLook>> usosPorDia(List<UsoLook> usos) {
  final mapa = <DateTime, List<UsoLook>>{};
  for (final uso in usos) {
    final dia = DateTime(uso.usadoEm.year, uso.usadoEm.month, uso.usadoEm.day);
    mapa.putIfAbsent(dia, () => []).add(uso);
  }
  return mapa;
}

bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hoje", "Ontem" ou `dd/MM/yyyy`. [hoje] é injetado (nos testes, uma data
/// fixa) em vez de chamar `DateTime.now()` aqui dentro. Formatado à mão, sem `intl`.
String rotuloDoDia(DateTime dia, DateTime hoje) {
  if (_mesmoDia(dia, hoje)) return 'Hoje';
  if (_mesmoDia(dia, DateTime(hoje.year, hoje.month, hoje.day - 1))) return 'Ontem';
  final dd = dia.day.toString().padLeft(2, '0');
  final mm = dia.month.toString().padLeft(2, '0');
  return '$dd/$mm/${dia.year}';
}

/// Até quantos dias desde o último uso um look conta como "repetição
/// recente" (E3.F4.4).
const diasDeRepeticaoRecente = 7;

/// Último dia de uso de cada look (`lookId` → dia), a partir do histórico.
/// Considera só ano/mês/dia; vários usos do mesmo look ficam com o mais recente.
Map<String, DateTime> ultimoUsoPorLook(List<UsoLook> usos) {
  final mapa = <String, DateTime>{};
  for (final uso in usos) {
    final dia = DateTime(uso.usadoEm.year, uso.usadoEm.month, uso.usadoEm.day);
    final atual = mapa[uso.lookId];
    if (atual == null || dia.isAfter(atual)) mapa[uso.lookId] = dia;
  }
  return mapa;
}

/// Dias de calendário entre [ultimoUso] e [hoje] (não 24h: 23h de ontem e 1h
/// de hoje são 1 dia). Usa UTC só para a conta não sofrer com horário de
/// verão. Usos "no futuro" (tolerância de fuso do backend) contam como 0.
int diasDesdeUltimoUso(DateTime ultimoUso, DateTime hoje) {
  final dias = DateTime.utc(hoje.year, hoje.month, hoje.day)
      .difference(DateTime.utc(ultimoUso.year, ultimoUso.month, ultimoUso.day))
      .inDays;
  return dias < 0 ? 0 : dias;
}

/// "Usado hoje", "Usado ontem" ou "Usado há N dias". [hoje] é injetado para
/// testar sem relógio real.
String rotuloDeRecencia(DateTime ultimoUso, DateTime hoje) {
  final dias = diasDesdeUltimoUso(ultimoUso, hoje);
  if (dias == 0) return 'Usado hoje';
  if (dias == 1) return 'Usado ontem';
  return 'Usado há $dias dias';
}

/// Último uso há [diasDeRepeticaoRecente] dias ou menos.
bool repeticaoRecente(DateTime ultimoUso, DateTime hoje) =>
    diasDesdeUltimoUso(ultimoUso, hoje) <= diasDeRepeticaoRecente;
