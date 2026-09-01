import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/services/wahrscheinlicher_vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Kompakter Read-only-Hinweis im Kopf der Postfach-Detailansicht: zeigt auf
/// einen Blick, welchem Vorgang die erfasste Antwort über ihre Referenz
/// zugeordnet ist. Aufgelöst wird live aus dem [VorgangCubit] (über die
/// Referenz), damit die Anzeige neue oder geänderte Vorgänge berücksichtigt.
///
/// Bewusst nur informativ — die tatsächliche, korrigierbare Zuordnung trifft der
/// Anwalt weiter unten im Formular (`VorgangZuordnungAuswahl`).
class MailboxVorgangZuordnung extends StatelessWidget {
  /// Ausgewertete Antwortdaten: die Referenz löst den Vorgang direkt auf;
  /// passt sie nicht, dienen Gegner-Kennzeichen + Unfalldatum als Fallback
  /// für einen „wahrscheinlich zugehörigen" Vorgang.
  final ZentralrufReplyData antwortDaten;

  const MailboxVorgangZuordnung({super.key, required this.antwortDaten});

  String? get antwortReferenz => antwortDaten.referenz;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final ziel = getIt<VorgangCubit>().findeZuReferenz(antwortReferenz);
        if (ziel != null) return _mitZuordnung(context, ziel);
        final vermutet = findeWahrscheinlichenVorgang(vorgaenge, antwortDaten);
        return vermutet == null
            ? _ohneZuordnung(context)
            : _mitVermutung(context, vermutet);
      },
    );
  }

  /// Fallback-Treffer über Kennzeichen + Unfalldatum: nur ein Hinweis — die
  /// tatsächliche Zuordnung bestätigt der Anwalt unten im Formular.
  Widget _mitVermutung(BuildContext context, Vorgang vermutet) {
    final theme = Theme.of(context);
    final akzent = theme.colorScheme.tertiary;

    return _rahmen(
      context,
      akzent: akzent,
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 18, color: akzent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wahrscheinlich zugehörig: Vorgang „${vermutet.referenz}" '
              '(Kennzeichen + Unfalldatum stimmen überein) — Zuordnung unten '
              'im Formular bestätigen.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 10),
          VorgangStatusChip(status: vermutet.status),
        ],
      ),
    );
  }

  Widget _mitZuordnung(BuildContext context, Vorgang ziel) {
    final theme = Theme.of(context);
    final akzent = theme.colorScheme.primary;
    final untertitel = [
      ziel.zeichen,
      if (ziel.parteienBezeichnung.isNotEmpty) ziel.parteienBezeichnung,
    ].join(' · ');

    return _rahmen(
      context,
      akzent: akzent,
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: akzent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zugeordneter Vorgang',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(untertitel, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 10),
          VorgangStatusChip(status: ziel.status),
        ],
      ),
    );
  }

  Widget _ohneZuordnung(BuildContext context) {
    final theme = Theme.of(context);
    final akzent = theme.colorScheme.outline;
    final ref = (antwortReferenz ?? '').trim();

    return _rahmen(
      context,
      akzent: akzent,
      child: Row(
        children: [
          Icon(Icons.folder_off_outlined, size: 18, color: akzent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ref.isEmpty
                  ? 'Keine Referenz erkannt — noch keinem Vorgang zugeordnet.'
                  : 'Kein Vorgang zur Referenz „$ref" gefunden — noch keinem '
                        'Vorgang zugeordnet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rahmen(
    BuildContext context, {
    required Color akzent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: akzent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: akzent.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
