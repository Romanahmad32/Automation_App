using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Zugriff auf die Vorgänge — die gemeinsame Klammer über den Lebenszyklus.
/// Bewusst pro-Datensatz (Upsert/Delete) statt Bulk-Replace: jede Mutation
/// schreibt genau eine Zeile, damit auch bei tausenden (auch abgeschlossenen)
/// Vorgängen schnell gespeichert wird. Gelesen wird gefiltert (Status/Jahr).
/// </summary>
public interface IVorgangRepository
{
    Task<IReadOnlyList<VorgangEntity>> GetAllAsync(
        string? status = null,
        string? jahr = null,
        CancellationToken cancellationToken = default);

    Task<VorgangEntity?> GetByReferenzAsync(string referenz, CancellationToken cancellationToken = default);

    /// <summary>
    /// Fallback-Suche für die Antwort-Zuordnung, wenn die Referenz nicht passt
    /// (z. B. in der Mail verstümmelt): angefragte Vorgänge, deren
    /// Gegner-Kennzeichen (normalisiert) und Unfalldatum mit der Antwort
    /// übereinstimmen. Nur ein Hinweis — die Zuordnung bestätigt der Anwalt.
    /// </summary>
    Task<IReadOnlyList<VorgangEntity>> FindeAngefragteZuUnfallAsync(
        string kennzeichen,
        string unfallDatum,
        CancellationToken cancellationToken = default);

    /// <summary>Legt den Vorgang an oder ersetzt den bestehenden mit gleicher Referenz.</summary>
    Task<VorgangEntity> UpsertAsync(VorgangEntity vorgang, CancellationToken cancellationToken = default);

    /// <summary>Löscht den Vorgang zur Referenz. false, wenn keiner passte.</summary>
    Task<bool> DeleteAsync(string referenz, CancellationToken cancellationToken = default);

    /// <summary>
    /// Setzt den angefangenen Ausfüllstand (<see cref="VorgangEntity.EntwurfJson"/>)
    /// oder löscht ihn (<paramref name="entwurfJson"/> = null). Bewusst ein
    /// eigener Weg statt eines Upsert: Der Entwurf wird beim Tippen laufend
    /// geschrieben, und ein Upsert des ganzen Vorgangs würde dabei jedes Mal
    /// alle übrigen Spalten aus der Sicht des Aufrufers überschreiben — auch
    /// eine Zentralruf-Antwort, die inzwischen eingetroffen ist. Null, wenn
    /// kein Vorgang zur Referenz existiert.
    /// </summary>
    Task<VorgangEntity?> SetzeEntwurfAsync(
        string referenz,
        string? entwurfJson,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Benennt den Vorgang von <paramref name="von"/> auf <paramref name="nach"/> um
    /// (Referenz korrigieren, z. B. Tippfehler). Die Referenz-Bestandteile
    /// (Nr/Jahr/Abteilung/Kennzeichen) werden dabei neu aus der Zielreferenz
    /// abgeleitet. Schlägt fehl, wenn kein Vorgang zu <paramref name="von"/>
    /// existiert oder <paramref name="nach"/> bereits vergeben ist.
    /// </summary>
    Task<ReferenzAenderung> RenameReferenzAsync(
        string von,
        string nach,
        CancellationToken cancellationToken = default);
}
