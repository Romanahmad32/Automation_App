namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn eine Mail-Textvorlage ohne Namen gespeichert werden
/// soll. Der Controller übersetzt das in 400 Bad Request.
/// </summary>
/// <remarks>
/// <c>IsRequired()</c> an der Entität verbietet nur NULL, nicht die leere
/// Zeichenkette — über die API ließ sich damit ein namenloser Eintrag anlegen
/// (ergänzt am 03.09.2026). Der Name ist der fachliche Schlüssel: Danach wählt
/// der Anwalt beim Verfassen, und ohne ihn stünde in der Auswahl eine Zeile,
/// die nichts über sich sagt. Dieselbe Lücke wie bei den Anredeanfängen und
/// den Grüßen (<see cref="AnredeBausteinUngueltigException"/>,
/// <see cref="GrussformelUngueltigException"/>).
///
/// <b>Nur der Name.</b> Betreff und Text dürfen leer bleiben: Eine halb
/// geschriebene Vorlage muss sich speichern lassen (§1.3, §4.7) — der
/// Vorlageneditor ist ein Hinweisgeber, kein Riegel, und was fehlt, sagt er
/// beim Schreiben.
/// </remarks>
public sealed class MailVorlageUngueltigException(string message) : Exception(message);
