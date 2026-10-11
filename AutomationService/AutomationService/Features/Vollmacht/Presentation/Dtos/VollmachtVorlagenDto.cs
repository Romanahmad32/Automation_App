using AutomationService.Features.Vollmacht.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>Antwort auf <c>GET api/Vollmacht/vorlagen</c>: der Ordner und seine drei Vorlagen.</summary>
public sealed record VollmachtVorlagenDto(string Ordner, IReadOnlyList<VollmachtVorlageDto> Vorlagen);

/// <summary>
/// Stand einer Vollmachtsvorlage; <see cref="Art"/> wie im Auftrag.
/// <see cref="Platzhalter"/> sind die Namen ohne Klammern, wie sie in der Datei
/// stehen, je Name einmal (#171); der Dialog zeigt danach nur die Felder dieser
/// Vorlage. <c>null</c> heißt „unbekannt" (Datei fehlt, gesperrt oder kaputt) —
/// dann zeigt er alle —, eine leere Liste „keine Platzhalter".
/// </summary>
public sealed record VollmachtVorlageDto(
    string Art,
    string Dateiname,
    bool Vorhanden,
    DateTime? GeaendertAm,
    IReadOnlyList<string>? Platzhalter)
{
    public static VollmachtVorlageDto From(VollmachtVorlage vorlage) => new(
        VollmachtArten.Wert(vorlage.Art),
        vorlage.Dateiname,
        vorlage.Vorhanden,
        vorlage.GeaendertAm,
        vorlage.Platzhalter);
}
