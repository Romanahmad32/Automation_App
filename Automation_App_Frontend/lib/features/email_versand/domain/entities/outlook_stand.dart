import 'package:equatable/equatable.dart';

/// Welches Outlook auf diesem Rechner steht (§4.7) — beim Start des Dienstes
/// einmal ermittelt.
///
/// Drei Dinge in dieser App sprechen mit Outlook: der Entwurf, der Griff nach
/// den Anhängen der offenen Nachricht und die Übernahme der Signatur. Alle drei
/// brauchen das **klassische** Outlook. Das neue (die Store-App) lässt sich
/// nicht steuern — dann tun alle drei still nichts, und jedes für sich sieht
/// aus wie ein Aussetzer. Genau deshalb gibt es diesen Stand: damit die
/// Oberfläche den Grund hinschreiben kann, statt ihn geschehen zu lassen.
class OutlookStand extends Equatable {
  /// Ob die drei Outlook-Funktionen überhaupt etwas liefern können. False
  /// heißt **nicht** „kaputt": Der Direktversand läuft über das Postfach und
  /// ist davon unberührt.
  final bool steuerbar;

  /// Die Store-App liegt auf dem Rechner. Entscheidet nur die Formulierung.
  final bool neu;

  /// Der Grund im Klartext; leer, wenn alles da ist.
  final String hinweis;

  const OutlookStand({
    this.steuerbar = true,
    this.neu = false,
    this.hinweis = '',
  });

  /// Der Stand, solange nicht gefragt wurde: Es wird nichts behauptet und
  /// nichts abgeschaltet, bis der Dienst geantwortet hat.
  static const OutlookStand unbekannt = OutlookStand();

  factory OutlookStand.fromJson(Map<String, dynamic> json) => OutlookStand(
    steuerbar: json['steuerbar'] as bool? ?? true,
    neu: json['neu'] as bool? ?? false,
    hinweis: json['hinweis'] as String? ?? '',
  );

  /// Ein Halbsatz für enge Stellen — der volle Grund gehört daneben in den
  /// Tooltip, nicht in die Zeile.
  String get kurz => neu
      ? 'Das neue Outlook lässt sich nicht steuern.'
      : 'Kein klassisches Outlook auf diesem Rechner.';

  @override
  List<Object?> get props => [steuerbar, neu, hinweis];
}
