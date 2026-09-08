using AutomationService.Features.RegisterHistorie.Domain.Persistence;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Lesen und Nachführen der übernommenen Registerhistorie (§6.2).
///
/// Die Registeransicht baut ihre Zeilen aus zwei Quellen — laufende Vorgänge
/// und diese Historie —, damit Bildschirm und Word/PDF-Spiegel per Konstruktion
/// dasselbe sagen. Deshalb ist das hier eine Schnittstelle der Domain: Der
/// Vorgangs-Slice hängt an ihr, nicht an der Tabelle.
/// </summary>
public interface IRegisterHistorie
{
    /// <summary>
    /// Die Zeilen, sortiert nach Jahr und laufender Nummer. Ohne
    /// <paramref name="jahr"/> alle. Ungetrackt gelesen: Die Ansicht ändert
    /// nichts.
    /// </summary>
    Task<IReadOnlyList<RegisterHistorieEntity>> GetAllAsync(
        int? jahr,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Eine einzelne Zeile, ungetrackt. <c>null</c>, wenn es die Id nicht gibt.
    ///
    /// Gebraucht vom Bearbeiten-Dialog: Er zeigt neben den änderbaren Feldern
    /// den Freitext, gegen den der Anwalt seine Berichtigung liest, und den
    /// hält die Registeransicht nicht vor.
    /// </summary>
    Task<RegisterHistorieEntity?> GetAsync(int id, CancellationToken cancellationToken = default);

    /// <summary>Welche Jahrgänge übernommen sind, welche fehlen, welche Lücken offen blieben.</summary>
    Task<RegisterHistorieStand> StandAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Setzt die änderbaren Felder einer Zeile, hält den Änderungszeitpunkt
    /// fest und rechnet ihre Befunde neu — sonst behauptete die Zeile nach der
    /// Berichtigung weiter den Widerspruch, den der Anwalt gerade aufgelöst
    /// hat. <c>null</c>, wenn es die Id nicht gibt.
    /// </summary>
    Task<RegisterHistorieEntity?> AendereAsync(
        int id,
        RegisterHistorieAenderung aenderung,
        CancellationToken cancellationToken = default);
}
