using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Ein Paket samt der Zahl seiner erledigten Ordner. <see cref="Erledigt"/>
/// steht bewusst <b>neben</b> der Entität und nicht in ihr: Es wird bei jedem
/// Lesen frisch gerechnet und nie gespeichert. Ein Ordner, der später wieder
/// frei wird, senkt die Zahl dadurch von selbst — es gibt keinen Stand, der
/// veralten kann.
/// </summary>
public sealed record ImportPaketStand(ImportPaketEntity Paket, int Erledigt);

/// <summary>
/// Die Buchführung über die herausgegebenen Arbeitspakete des
/// Mandanten-Imports (§5.1, §6.1).
///
/// Zusammengesetzt wird ein Paket im Frontend — welche Ordner es im
/// Dateisystem gibt, weiß nur dort jemand. Dieser Dienst nimmt die Namen
/// entgegen, vergibt die Nummer und beantwortet danach die einzige Frage, die
/// den Anwalt wirklich interessiert: wie weit ist welches Paket.
///
/// <b>Ein Ordner gilt als erledigt, wenn er einem Mandanten zugeordnet ist
/// oder einen Vermerk trägt</b> — dieselbe Rechnung wie „offen" im
/// Zuordnungsstapel, nur andersherum. Verglichen wird durchgehend ohne
/// Rücksicht auf Groß- und Kleinschreibung, passend zur NOCASE-Kollation der
/// Vermerke und zum Windows-Dateisystem, aus dem die Namen stammen.
/// </summary>
public interface IImportPaketBuch
{
    /// <summary>Alle Pakete, das jüngste zuerst (Nummer absteigend).</summary>
    Task<IReadOnlyList<ImportPaketStand>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Verbucht ein herausgegebenes Paket und vergibt dabei die nächste
    /// Nummer. Doppelte Namen werden ohne Rücksicht auf die Schreibweise
    /// entdoppelt.
    /// </summary>
    /// <exception cref="ArgumentException">Kein einziger brauchbarer Ordnername.</exception>
    Task<ImportPaketStand> NotiereAsync(
        IReadOnlyList<string> ordnernamen,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Schließt jedes offene Paket, dessen Ordner inzwischen vollständig
    /// erledigt sind, und hält <paramref name="zeilen"/> als Umfang der Datei
    /// fest, die es geschlossen hat.
    ///
    /// Ein nur teilweise abgearbeitetes Paket bleibt offen — das ist die
    /// ehrliche Antwort, und wie weit es ist, sagt der Zähler aus
    /// <see cref="ImportPaketStand.Erledigt"/>. Weder Paketnummer in der Datei
    /// noch Rückfrage an den Anwalt: die Zuordnung ergibt sich aus den
    /// Ordnernamen.
    /// </summary>
    Task SchreibeFortschrittAsync(int zeilen, CancellationToken cancellationToken = default);

    /// <summary>
    /// Nimmt ein versehentlich herausgegebenes Paket zurück. Setzt an den
    /// Ordnern nichts zurück — das Paket war ohnehin nur eine Buchführungszeile,
    /// keine Reservierung —, sondern löscht ausschließlich diese Zeile.
    /// </summary>
    /// <returns><c>false</c>, wenn keine Paketnummer <paramref name="nummer"/> existiert.</returns>
    /// <exception cref="InvalidOperationException">
    /// Das Paket ist bereits eingelesen — das Löschen einer abgeschlossenen
    /// Zeile sähe nach einem Rückgängig der eingelesenen Mandanten aus, macht
    /// aber keinen davon rückgängig.
    /// </exception>
    Task<bool> LoescheAsync(int nummer, CancellationToken cancellationToken = default);
}
