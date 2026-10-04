import 'package:flutter/material.dart';

/// Variante visual do [AppButton] — todas puxam do `ThemeData` global
/// (ver core/theme/app_theme.dart, Etapa 0 do redesign visual).
enum AppButtonVariant { primary, secondary, text }

/// Botão padrão do app. Substitui o uso direto de `ElevatedButton`/
/// `OutlinedButton`/`TextButton` espalhado pelas telas, e centraliza o
/// padrão de "estado de carregamento" (spinner no lugar do texto) que
/// antes era repetido ad hoc em upload_view/peca_form_view/montar_look_view.
///
/// Por baixo continua sendo um `ElevatedButton`/`OutlinedButton`/`TextButton`
/// de verdade (não um widget customizado do zero) — testes existentes que
/// fazem `find.byType(ElevatedButton)` continuam funcionando sem ajuste.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final onPressedEfetivo = loading ? null : onPressed;
    final Widget child = loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              );

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton(onPressed: onPressedEfetivo, child: child),
      AppButtonVariant.secondary => OutlinedButton(onPressed: onPressedEfetivo, child: child),
      AppButtonVariant.text => TextButton(onPressed: onPressedEfetivo, child: child),
    };
  }
}
