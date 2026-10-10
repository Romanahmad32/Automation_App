import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:flutter/material.dart';

/// Die Zustände, auf die [MailboxStatusPille] den Verbindungsstatus des
/// Postfachs verdichtet — dieselbe Fallunterscheidung wie im breiten
/// `MailboxStatusBanner`, nur gröber gestuft für die kompakte Kopfzeile.
///
/// [abruf] und [inaktiv] sind ausdrücklich **nicht** dasselbe: [abruf] heißt
/// „verbunden, aber ohne Push (IDLE) — das Postfach wird in Abständen
/// abgefragt", [inaktiv] heißt „die Überwachung ist ausgeschaltet, es kommt
/// gar nichts". Beides „Abruf" zu nennen, wie es bis zum 13.09.2026 der Fall
/// war, verkaufte den ausgeschalteten Zustand als eine langsamere Betriebsart.
enum MailboxStatusZustand { verbunden, abruf, inaktiv, keinZugang, fehler }

/// Farbe, Symbol, Kurz- und Langtext zu einem [MailboxStatus] — von
/// [MailboxStatusPille] verwendet.
///
/// Eigene, öffentliche Datei statt einer privaten Hilfsfunktion in
/// `mailbox_status_pille.dart` (im Frontend sind private Top-Level-Bausteine
/// nicht erlaubt) und statt eines Umbaus von `mailbox_status_banner.dart`
/// selbst: Der Banner bleibt unverändert und behält seine feiner gestufte
/// Fallunterscheidung (u. a. den separaten Wortlaut für „Verbindung
/// unterbrochen" gegenüber einem von außen gemeldeten Fehler) — hier zählt
/// für den Pillentext nur, ob überhaupt ein Fehler vorliegt.
@immutable
class MailboxStatusDarstellung {
  final MailboxStatusZustand zustand;
  final Color accent;
  final IconData icon;

  /// Kurzer Pillentext: „Verbunden", „Abruf", „Inaktiv", „Kein Zugang" oder
  /// „Fehler".
  final String kurztext;

  /// Ausführlicher Text für den Tooltip (Modus, letzter Empfang bzw. die
  /// Fehlermeldung) — derselbe Wortlaut wie im Banner.
  final String langtext;

  const MailboxStatusDarstellung({
    required this.zustand,
    required this.accent,
    required this.icon,
    required this.kurztext,
    required this.langtext,
  });

  /// Leitet die Darstellung aus [status] ab, in derselben Rangfolge wie
  /// `MailboxStatusBanner`: ein von außen gemeldeter [error] geht vor, dann
  /// die bestehende Verbindung (mit Push oder im Abruf-Modus), dann die
  /// ausgeschaltete Überwachung, dann fehlender Zugang, dann eine
  /// unterbrochene Verbindung. Der verbleibende Fall „eingeschaltet,
  /// eingerichtet, verbindet gerade" teilt sich Farbe und Kurztext mit „Kein
  /// Zugang" (beide tertiär) — er ist so kurzlebig, dass eine eigene
  /// Pillen-Bezeichnung dafür die vereinbarten Kurztexte unnötig vermehren
  /// würde; der Tooltip nennt ihn trotzdem beim Namen.
  factory MailboxStatusDarstellung.von(
    MailboxStatus status,
    ColorScheme scheme, {
    String? error,
  }) {
    if (error != null) {
      return MailboxStatusDarstellung(
        zustand: MailboxStatusZustand.fehler,
        accent: scheme.error,
        icon: Icons.error_outline,
        kurztext: 'Fehler',
        langtext: error,
      );
    }
    if (status.connected) {
      // Verbunden ist verbunden — der Unterschied liegt darin, *wie* schnell
      // eine eingehende Antwort ankommt: sofort (IDLE/Push) oder erst beim
      // nächsten Abruf. Deshalb dieselbe Farbe, aber ein eigener Kurztext.
      final push = status.idleSupported;
      return MailboxStatusDarstellung(
        zustand: push
            ? MailboxStatusZustand.verbunden
            : MailboxStatusZustand.abruf,
        accent: Colors.green,
        icon: push ? Icons.cloud_done : Icons.cloud_sync,
        kurztext: push ? 'Verbunden' : 'Abruf',
        langtext: push
            ? 'Verbunden — eingehende Antworten werden automatisch erfasst '
                  '(Push/IDLE).'
            : 'Verbunden — das Postfach kennt kein Push (IDLE) und wird '
                  'deshalb in Abständen abgefragt (Abruf-Modus).',
      );
    }
    if (!status.enabled) {
      return MailboxStatusDarstellung(
        zustand: MailboxStatusZustand.inaktiv,
        accent: scheme.outline,
        icon: Icons.cloud_off,
        kurztext: 'Inaktiv',
        langtext:
            'Überwachung ausgeschaltet. In den Einstellungen unter "E-Mail" '
            'aktivieren.',
      );
    }
    if (!status.configured) {
      return MailboxStatusDarstellung(
        zustand: MailboxStatusZustand.keinZugang,
        accent: scheme.tertiary,
        icon: Icons.key_off,
        kurztext: 'Kein Zugang',
        langtext:
            'Kein Postfach-Zugang hinterlegt. In den Einstellungen unter '
            '"E-Mail" einrichten.',
      );
    }
    if (status.lastError != null) {
      return MailboxStatusDarstellung(
        zustand: MailboxStatusZustand.fehler,
        accent: scheme.error,
        icon: Icons.sync_problem,
        kurztext: 'Fehler',
        langtext:
            'Verbindung unterbrochen: ${status.lastError}. Es wird '
            'automatisch erneut verbunden.',
      );
    }
    return MailboxStatusDarstellung(
      zustand: MailboxStatusZustand.keinZugang,
      accent: scheme.tertiary,
      icon: Icons.sync,
      kurztext: 'Kein Zugang',
      langtext: 'Überwachung eingeschaltet — verbinde …',
    );
  }
}
