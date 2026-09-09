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

    /// <summary>
    /// Löscht die Zeile zur Id (§6.3). <c>false</c>, wenn es sie nicht gibt —
    /// derselbe Wettlauf wie bei <see cref="AendereAsync"/>: Der Anwalt sah die
    /// Zeile im selben Bestand, den er gerade löscht, ein Fehlschlag hier ist
    /// kein Programmfehler.
    /// </summary>
    Task<bool> LoescheAsync(int id, CancellationToken cancellationToken = default);

    /// <summary>
    /// Übernimmt die gespiegelte Registerzeile eines gelöschten Vorgangs als
    /// eigenständige Zeile der Historie (§6.3) — ohne diesen Schritt
    /// verschwände sie beim nächsten Schreiben, weil sie nur ein Spiegel des
    /// Vorgangs war. <c>null</c>, wenn der natürliche Schlüssel (Jahr,
    /// LaufendeNummer, NummerZusatz) schon belegt ist: Dann steht die Zeile
    /// ohnehin im Register, und es gibt nichts zu bewahren.
    ///
    /// Wirft nie wegen dieser Kollision — sie wird vor dem Schreiben erkannt,
    /// nicht als <c>DbUpdateException</c> danach aufgefangen. Ein Löschvorgang
    /// darf daran nicht scheitern.
    /// </summary>
    Task<RegisterHistorieEntity?> UebernehmeAsync(
        RegisterHistorieUebernahme uebernahme,
        CancellationToken cancellationToken = default);
}
