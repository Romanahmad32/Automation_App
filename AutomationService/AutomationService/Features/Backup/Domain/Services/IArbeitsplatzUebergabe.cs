namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Die Uebergabe zwischen zwei Arbeitsplaetzen (§7.2, #39): erkennen, ob
/// woanders ein neuerer Stand liegt, und ihn auf Wunsch uebernehmen.
///
/// Ein Sicherungsordner ohne diese Rueckfrage waere eine Falle — man spielt
/// montags im Buero einen Stand von Freitag ein und ueberschreibt die Arbeit vom
/// Wochenende. Deshalb gibt es hier keine stille Uebernahme: <see cref="Stand"/>
/// liefert nur die Auskunft, gehandelt wird erst auf ausdruecklichen Auftrag.
/// </summary>
public interface IArbeitsplatzUebergabe
{
    /// <summary>
    /// Was beim Start zu zeigen ist. Ein unerreichbarer oder unlesbarer
    /// Ablageordner ergibt kein Angebot statt eines Fehlers — der Start dieses
    /// Rechners darf nicht daran haengen, in welchem Zustand der andere ist.
    /// </summary>
    UebergabeStand Stand();

    /// <summary>
    /// Spielt den angebotenen Stand ein — ueber denselben Weg wie eine Sicherung
    /// von Hand: Der bisherige Stand wird vorher vollstaendig daneben gelegt,
    /// die maschinenabhaengigen Ordnerpfade ueberleben. Danach traegt die eigene
    /// Akte den uebernommenen Stand, damit der naechste Start nicht erneut
    /// dasselbe Archiv anbietet.
    /// </summary>
    Task<UebernahmeErgebnis> UebernehmenAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Haelt fest, dass der Anwalt die Meldung ueber eine misslungene Sicherung
    /// gesehen hat. Ohne das staende sie bei jedem Start wieder da.
    /// </summary>
    void QuittiereFehler();
}
