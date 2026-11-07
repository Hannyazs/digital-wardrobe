import 'package:flutter/material.dart';

import '../../../models/pasta_look.dart';

/// Escolha feita no seletor de pasta (E3.F6.3): uma pasta, "Sem pasta"
/// (`pastaId == null`) ou criar uma nova ([nova]). `null` como resultado do
/// sheet = dispensado, nada muda.
class EscolhaDePasta {
  const EscolhaDePasta.pasta(this.pastaId) : nova = false;
  const EscolhaDePasta.nova()
      : pastaId = null,
        nova = true;

  final String? pastaId;
  final bool nova;
}

/// "Mover para pasta": lista as pastas, "Sem pasta" e "Nova pasta…", com a
/// atual marcada.
Future<EscolhaDePasta?> escolherPasta(
  BuildContext context, {
  required List<PastaLook> pastas,
  required String? atual,
}) {
  return showModalBottomSheet<EscolhaDePasta>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      Widget opcao(String rotulo, String? pastaId, IconData icone) => ListTile(
            leading: Icon(icone),
            title: Text(rotulo),
            trailing: atual == pastaId ? const Icon(Icons.check) : null,
            selected: atual == pastaId,
            onTap: () => Navigator.of(sheet).pop(EscolhaDePasta.pasta(pastaId)),
          );
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Mover para pasta')),
            for (final pasta in pastas) opcao(pasta.nome, pasta.id, Icons.folder_outlined),
            opcao('Sem pasta', null, Icons.folder_off_outlined),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Nova pasta…'),
              onTap: () => Navigator.of(sheet).pop(const EscolhaDePasta.nova()),
            ),
          ],
        ),
      );
    },
  );
}
