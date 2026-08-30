using AutomationService.Features.Mandanten.Domain.Services;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Was ein Import bewirkt hat oder bewirken würde. Vorschau und Übernahme
/// liefern denselben Bericht; nur <see cref="Angewendet"/> unterscheidet sie.
///
/// <c>OrdnerZugeordnet</c> ist die Zahl der Akten-Ordner, die dadurch an einen
/// Mandanten gehen — die Zahl, um die der Zuordnungsstapel kleiner wird, und
/// damit die einzige, die den Erfolg des Imports beschreibt.
/// </summary>
public sealed record ImportBerichtDto(
    IReadOnlyList<ImportEintragDto> Eintraege,
    int Neu,
    int Ergaenzt,
    int Unveraendert,
    int Abgelehnt,
    int OrdnerZugeordnet,
    int OhneMandantenbezug,
    bool Angewendet)
{
    public static ImportBerichtDto From(MandantenImportBefund befund) => new(
        [.. befund.Eintraege.Select(ImportEintragDto.From)],
        befund.Neu,
        befund.Ergaenzt,
        befund.Unveraendert,
        befund.Abgelehnt,
        befund.OrdnerZugeordnet,
        befund.OhneMandantenbezug,
        befund.Angewendet);
}

/// <summary>
/// Das Ergebnis einer einzelnen Zeile der Importdatei. <c>Art</c> ist
/// <c>neu</c>, <c>ergaenzt</c>, <c>unveraendert</c> oder <c>abgelehnt</c> — als
/// Zeichenkette, weil eine Zahl die Dart-Seite an die Deklarationsreihenfolge
/// eines C#-Enums koppeln würde.
/// </summary>
public sealed record ImportEintragDto(
    int Zeile,
    string Anzeigename,
    IReadOnlyList<string> AktenOrdnernamen,
    string Art,
    int? MandantId,
    string Sicherheit,
    string Quelle,
    IReadOnlyList<string> Hinweise)
{
    public static ImportEintragDto From(ImportEintragBefund e) => new(
        e.Zeile,
        e.Anzeigename,
        e.AktenOrdnernamen,
        e.Art,
        e.MandantId,
        e.Sicherheit,
        e.Quelle,
        e.Hinweise);
}
