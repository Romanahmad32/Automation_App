namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Die Zeilen der Registeransicht (§6.2) — laufende Vorgänge und übernommene
/// Historie in einer Folge.
///
/// Eigener Dienst und nicht der Register-Spiegel: Der schreibt eine Datei und
/// filtert nach der Einstellung „Filter der Datei". Der Bildschirm zeigt auch
/// laufende Vorgänge, sonst verschwände ein Vorgang aus der Ansicht, bis er
/// abgeschlossen ist.
/// </summary>
public interface IRegisterZeilenDienst
{
    /// <summary>
    /// Alle Zeilen, sortiert nach Jahrgang und laufender Nummer. Mit
    /// <paramref name="jahrgang"/> nur die dieses Jahres (vierstellig).
    /// </summary>
    Task<IReadOnlyList<RegisterZeile>> LadeAsync(
        int? jahrgang,
        CancellationToken cancellationToken = default);
}
