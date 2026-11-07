import 'package:guarda_roupa_app/core/constants/peca_opcoes.dart';
import 'package:guarda_roupa_app/models/peca_parada.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_controller.dart';

/// Servidor falso de `GET /pecas` para os `PecaService` falsos dos testes
/// (E11.F1.2): cada fake continua devolvendo a lista inteira em `listarPecas`
/// e este mixin a recorta como o backend faz — categorias, gaveta "Outras",
/// filtros (as regras de `filtrarPecas`), `limite`/`deslocamento` e o total.
///
/// [paginasPedidas] registra cada chamada, para os testes conferirem quantas
/// páginas o app realmente pediu.
mixin PaginaDaLista on PecaService {
  final List<({ConsultaPecas consulta, int limite, int deslocamento})> paginasPedidas = [];

  @override
  Future<PaginaDePecas> listarPagina(
    ConsultaPecas consulta, {
    required int limite,
    int deslocamento = 0,
  }) async {
    paginasPedidas.add((consulta: consulta, limite: limite, deslocamento: deslocamento));
    final todas = await listarPecas();
    final doRecorte = filtrarPecas(todas, consulta.filtro).where((p) {
      if (consulta.categorias.isEmpty && !consulta.outras) return true;
      return consulta.categorias.contains(p.categoria) ||
          (consulta.outras && !categoriasFixas.contains(p.categoria));
    }).toList();
    final pagina = doRecorte.skip(deslocamento).take(limite).toList();
    return PaginaDePecas(pagina, doRecorte.length);
  }

  /// Sem peças paradas (E13.F1.2): as telas que montam a `HomeShell` não
  /// abrem o aviso. Os testes do aviso sobrescrevem.
  @override
  Future<List<PecaParada>> listarParadas({required DateTime hoje, int limite = 1}) async => [];
}
