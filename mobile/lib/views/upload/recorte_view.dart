import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';

/// Recorte manual da foto antes do envio ao backend. Duas etapas na mesma
/// tela: ajustar (arrastar/zoom da imagem sob a área de recorte) e conferir a
/// prévia, de onde dá para refazer. Devolve os bytes recortados (PNG) via
/// `Navigator.pop`, ou `null` se o usuário cancelar — a foto original nunca
/// é alterada por esta tela.
class RecorteView extends StatefulWidget {
  const RecorteView({super.key, required this.imagem});

  final Uint8List imagem;

  @override
  State<RecorteView> createState() => _RecorteViewState();
}

class _RecorteViewState extends State<RecorteView> {
  final _controller = CropController();
  Uint8List? _recortada;
  bool _recortando = false;

  void _aoRecortar(CropResult resultado) {
    switch (resultado) {
      case CropSuccess(:final croppedImage):
        setState(() {
          _recortada = croppedImage;
          _recortando = false;
        });
      case CropFailure():
        setState(() => _recortando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível recortar a foto. Tente novamente.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = _recortada;

    return Scaffold(
      appBar: AppBar(title: Text(previa == null ? 'Recortar foto' : 'Prévia do recorte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: previa == null ? _etapaDeAjuste() : _etapaDePrevia(previa),
      ),
    );
  }

  Widget _etapaDeAjuste() {
    return Column(
      children: [
        const Text(
          'Arraste e use o zoom para destacar a peça dentro da área de recorte.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Crop(
            image: widget.imagem,
            controller: _controller,
            onCropped: _aoRecortar,
            interactive: true,
            baseColor: AppColors.backgroundSecondary,
            maskColor: Colors.black.withValues(alpha: 0.5),
            progressIndicator: const CircularProgressIndicator(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            AppButton(
              label: 'Cancelar',
              variant: AppButtonVariant.secondary,
              onPressed: _recortando ? null : () => Navigator.of(context).pop(),
            ),
            AppButton(
              label: 'Recortar',
              loading: _recortando,
              onPressed: () {
                setState(() => _recortando = true);
                _controller.crop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _etapaDePrevia(Uint8List previa) {
    return Column(
      children: [
        Expanded(child: Image.memory(previa, fit: BoxFit.contain)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            AppButton(
              label: 'Refazer recorte',
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => _recortada = null),
            ),
            AppButton(
              label: 'Usar recorte',
              onPressed: () => Navigator.of(context).pop(previa),
            ),
          ],
        ),
      ],
    );
  }
}
