using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Zugriff auf das Mandantenregister (§5.1). Vergibt IDs und prüft auf
/// Namens-Dubletten — Fachregeln, die mit dem Umstieg vom lokalen JSON-Register
/// ins Backend gewandert sind.
/// </summary>
public interface IMandantenRepository
{
    /// <summary>Alle Mandanten, neueste zuerst.</summary>
    Task<IReadOnlyList<MandantEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Ein Ausschnitt des Registers, neueste zuerst — für die Mandantenliste,
    /// die in der Kanzlei tausende Einträge zeigt und sie nicht alle auf
    /// einmal holen soll.
    /// </summary>
    /// <param name="suche">
    /// Freitext über Name, Ort und die Namen der zugeordneten Akten-Ordner. Er
    /// gilt für den <b>ganzen</b> Bestand, nicht für die zuletzt geholte
    /// Seite: eine Suche, die nur das Geladene durchsieht, findet den gesuchten
    /// Mandanten je nach Scrollstand mal und mal nicht.
    /// </param>
    /// <param name="ueberspringen">Wie viele Treffer vor dem Ausschnitt liegen.</param>
    /// <param name="anzahl">Größe des Ausschnitts; 0 oder kleiner heißt Vorgabe.</param>
    /// <param name="cancellationToken">Abbruch des Abrufs.</param>
    Task<MandantenSeite> GetSeiteAsync(
        string? suche,
        int ueberspringen,
        int anzahl,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Die Namen aller Akten-Ordner, die irgendeinem Mandanten zugeordnet
    /// sind. Der Zuordnungsstapel im Frontend braucht sie vollständig, um die
    /// gescannten Ordner in „schon zugeordnet" und „offen" zu teilen — aus
    /// einer Seite des Registers ließe sich das nicht ableiten.
    /// </summary>
    Task<IReadOnlyList<string>> GetAktenOrdnernamenAsync(CancellationToken cancellationToken = default);

    /// <summary>Legt einen Mandanten an (ID + ErstelltAm werden vergeben).</summary>
    /// <exception cref="MandantNameConflictException">Name bereits vergeben.</exception>
    Task<MandantEntity> CreateAsync(MandantEntity neu, CancellationToken cancellationToken = default);

    /// <summary>Aktualisiert einen Mandanten. Liefert null, wenn die ID unbekannt ist.</summary>
    /// <exception cref="MandantNameConflictException">Name bereits von einem anderen vergeben.</exception>
    Task<MandantEntity?> UpdateAsync(MandantEntity mandant, CancellationToken cancellationToken = default);

    /// <summary>Löscht den Mandanten. false, wenn die ID unbekannt war.</summary>
    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
