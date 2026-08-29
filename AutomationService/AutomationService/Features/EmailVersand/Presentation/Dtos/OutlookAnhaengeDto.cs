using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Die Anhänge der Nachricht, die in Outlook gerade offen oder markiert ist
/// (§4.7) — samt der Angabe, welche Nachricht das war.
///
/// Die Angabe ist kein Beiwerk: Der Griff nach Outlook ist der einzige Schritt
/// des Ablaufs, dessen Eingabe der Anwalt nicht in der App gewählt hat. Ohne
/// Betreff und Absender bekäme er Dateien vorgelegt, ohne zu wissen, woher.
/// </summary>
public sealed record OutlookAnhaengeDto(
    IReadOnlyList<string> Pfade,
    string Betreff,
    string Absender,
    bool AusOffenemFenster,
    bool OutlookErreicht)
{
    public static OutlookAnhaengeDto From(OutlookAnhaenge anhaenge) => new(
        anhaenge.Pfade,
        anhaenge.Betreff,
        anhaenge.Absender,
        anhaenge.AusOffenemFenster,
        anhaenge.OutlookErreicht);
}
