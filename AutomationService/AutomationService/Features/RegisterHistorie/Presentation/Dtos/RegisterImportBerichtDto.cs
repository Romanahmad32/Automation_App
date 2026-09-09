using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Presentation.Dtos;

/// <summary>
/// Was ein Registerimport bewirkt hat oder bewirken würde. Vorschau und
/// Übernahme liefern denselben Bericht; nur <see cref="Angewendet"/>
/// unterscheidet sie.
/// </summary>
public sealed record RegisterImportBerichtDto(
    IReadOnlyList<JahrgangBefundDto> Jahrgaenge,
    bool Angewendet)
{
    public static RegisterImportBerichtDto From(RegisterImportBefund befund)
    {
        ArgumentNullException.ThrowIfNull(befund);
        return new RegisterImportBerichtDto(
            [.. befund.Jahrgaenge.Select(JahrgangBefundDto.From)],
            befund.Angewendet);
    }
}

/// <summary>
/// Der Befund über einen Jahrgang — die Karte, die der Anwalt vor der Freigabe
/// liest. <c>Luecken</c> und <c>Doppelte</c> stehen vorn, weil sie über die
/// Vollständigkeit entscheiden; <c>ZuPruefen</c> ist die Zahl, nach der die
/// Zeilenliste vorgefiltert wird.
/// </summary>
public sealed record JahrgangBefundDto(
    int Jahrgang,
    int Zeilen,
    IReadOnlyList<int> Luecken,
    IReadOnlyList<int> Doppelte,
    int Neu,
    int Unveraendert,
    int Abgelehnt,
    int ZuPruefen,
    int Abweichungen,
    IReadOnlyList<RegisterZeilenBefundDto> Eintraege)
{
    public static JahrgangBefundDto From(JahrgangBefund befund)
    {
        ArgumentNullException.ThrowIfNull(befund);
        return new JahrgangBefundDto(
            befund.Jahrgang,
            befund.Zeilen,
            befund.Luecken,
            befund.Doppelte,
            befund.Neu,
            befund.Unveraendert,
            befund.Abgelehnt,
            befund.ZuPruefen,
            befund.Abweichungen,
            [.. befund.Eintraege.Select(RegisterZeilenBefundDto.From)]);
    }
}

/// <summary>
/// Das Ergebnis einer einzelnen Zeile. <c>Art</c> ist <c>neu</c>,
/// <c>unveraendert</c> oder <c>abgelehnt</c> — als Zeichenkette, weil eine Zahl
/// die Dart-Seite an die Deklarationsreihenfolge eines C#-Enums koppeln würde.
///
/// <c>ZuPruefen</c> wird mitgeschickt und nicht im Frontend nachgerechnet: Die
/// Regel („nicht hoch, oder es liegt ein Befund vor") gehört zur Fachlogik, und
/// zwei Fassungen davon versteckten am Bildschirm eine Zeile, die der Bericht
/// zählt.
/// </summary>
public sealed record RegisterZeilenBefundDto(
    int Zeile,
    int Jahrgang,
    int LaufendeNummer,
    string Aktenzeichen,
    string Anzeigetext,
    string Rechtsgebiet,
    string Sicherheit,
    string Art,
    IReadOnlyList<string> Befunde,
    IReadOnlyList<string> Hinweise,
    bool ZuPruefen)
{
    public static RegisterZeilenBefundDto From(RegisterZeilenBefund befund)
    {
        ArgumentNullException.ThrowIfNull(befund);
        return new RegisterZeilenBefundDto(
            befund.Zeile,
            befund.Jahrgang,
            befund.LaufendeNummer,
            befund.Aktenzeichen,
            befund.Anzeigetext,
            befund.Rechtsgebiet,
            befund.Sicherheit,
            befund.Art,
            befund.Befunde,
            befund.Hinweise,
            befund.ZuPruefen);
    }
}
