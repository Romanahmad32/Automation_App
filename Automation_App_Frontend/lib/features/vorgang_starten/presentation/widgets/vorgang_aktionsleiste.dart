import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Unten angeheftete Aktionsleiste (scrollt nicht mit). Primäraktion „Vorgang
/// speichern"; bei Verkehrsrecht zusätzlich „Zentralruf-Formular ausfüllen"
/// (öffnet den Browser und speichert den Vorgang zugleich). Beide sind nur bei
/// gültigem Formular aktiv; während des Speicherns wird ein Ladeindikator gezeigt.
class VorgangAktionsleiste extends StatelessWidget {
  final bool zeigeZentralruf;
  final VoidCallback onSpeichern;
  final VoidCallback onZentralruf;

  const VorgangAktionsleiste({
    super.key,
    required this.zeigeZentralruf,
    required this.onSpeichern,
    required this.onZentralruf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: BlocBuilder<VorgangStartenBloc, VorgangStartenState>(
              builder: (context, state) {
                final isLoading = state is VorgangStartenLoading;
                return ReactiveFormConsumer(
                  builder: (context, formGroup, child) {
                    final aktiv = formGroup.valid && !isLoading;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (zeigeZentralruf) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Zentralruf-Formular ausfüllen'),
                            onPressed: aktiv ? onZentralruf : null,
                          ),
                          const SizedBox(width: 12),
                        ],
                        FilledButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Vorgang speichern'),
                          onPressed: aktiv ? onSpeichern : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
