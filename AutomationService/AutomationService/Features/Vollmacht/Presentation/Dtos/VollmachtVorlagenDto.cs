using AutomationService.Features.Vollmacht.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>Antwort auf <c>GET api/Vollmacht/vorlagen</c>: der Ordner und seine drei Vorlagen.</summary>
public sealed record VollmachtVorlagenDto(string Ordner, IReadOnlyList<VollmachtVorlageDto> Vorlagen);

/// <summary>Stand einer Vollmachtsvorlage; <see cref="Art"/> wie im Auftrag.</summary>
public sealed record VollmachtVorlageDto(
    string Art,
    string Dateiname,
    bool Vorhanden,
    DateTime? GeaendertAm)
{
    public static VollmachtVorlageDto From(VollmachtVorlage vorlage) => new(
        VollmachtArten.Wert(vorlage.Art),
        vorlage.Dateiname,
        vorlage.Vorhanden,
        vorlage.GeaendertAm);
}
