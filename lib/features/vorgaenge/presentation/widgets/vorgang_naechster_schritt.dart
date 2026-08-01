import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart';
import 'package:flutter/material.dart';

/// „Nächster Schritt"-Button eines Vorgangs: springt statusabhängig dorthin,
/// wo der Vorgang weiterbearbeitet wird — Angefragt → Postfach (Antwort
/// prüfen), Beantwortet/Erstellt/Abgelegt → Word-Assistent (Schreiben
/// erstellen, prüfen/ablegen, versenden & abschließen). Beim Sprung in den
/// Word-Assistenten wird der Vorgang über das [VorgangNavigationSignal]
/// vorausgewählt. Abgeschlossene Vorgänge zeigen keinen Button.
///
/// So muss der Anwalt nicht wissen, welcher Sidebar-Tab als Nächstes dran ist
/// — der rote Faden Anfrage → Antwort → Schreiben → Ablage → Versand bleibt
/// aus der Vorgangsübersicht heraus bedienbar.
class VorgangNaechsterSchritt extends StatelessWidget {
  final Vorgang vorgang;

  const VorgangNaechsterSchritt({super.key, required this.vorgang});

  ({String label, IconData icon, int tabIndex, bool vorauswahl})? get _schritt {
    return switch (vorgang.status) {
      VorgangStatus.angefragt => (
          label: 'Antwort prüfen',
          icon: Icons.mark_email_unread_outlined,
          tabIndex: AppTabIndex.postfach,
          vorauswahl: false,
        ),
      VorgangStatus.beantwortet => (
          label: 'Schreiben erstellen',
          icon: Icons.description_outlined,
          tabIndex: AppTabIndex.wordAutomation,
          vorauswahl: true,
        ),
      VorgangStatus.erstellt => (
          label: 'Prüfen & ablegen',
          icon: Icons.fact_check_outlined,
          tabIndex: AppTabIndex.wordAutomation,
          vorauswahl: true,
        ),
      VorgangStatus.abgelegt => (
          label: 'Versenden & abschließen',
          icon: Icons.send_outlined,
          tabIndex: AppTabIndex.wordAutomation,
          vorauswahl: true,
        ),
      VorgangStatus.versendet => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final schritt = _schritt;
    if (schritt == null) return const SizedBox.shrink();

    return FilledButton.tonalIcon(
      icon: Icon(schritt.icon, size: 18),
      label: Text(schritt.label),
      onPressed: () {
        if (schritt.vorauswahl) {
          getIt<VorgangNavigationSignal>().setze(vorgang.referenz);
        }
        AutoTabsRouter.of(context).setActiveIndex(schritt.tabIndex);
      },
    );
  }
}
