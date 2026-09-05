using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Settings.Presentation.Dtos;

/// <summary>
/// Was in den Einstellungen über einen der fünf Ordner zu sagen ist (#103):
/// die Speicherform, der wirksame Ordner, und in einem Wort, warum die beiden
/// gleich oder verschieden sind.
///
/// Die Oberfläche formt daraus einen Satz in Klartext („OneDrive-Konto
/// (OneDriveCommercial) auf diesem Rechner nicht vorhanden") — deshalb gehen
/// hier Zustände hinaus und keine fertigen Meldungen: Der Dienst kennt die
/// Lage, die Oberfläche die Worte.
/// </summary>
public sealed record OrdnerZustandDto(
    string Feld,
    string Gespeichert,
    string Wirksam,
    string Zustand,
    string Anker)
{
    public static OrdnerZustandDto From(OrdnerZustand zustand) => new(
        zustand.Feld,
        zustand.Gespeichert,
        zustand.Wirksam,
        zustand.Zustand,
        zustand.Anker);
}
