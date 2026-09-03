using AutomationService.Features.EmailVersand.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die zwei Handgriffe, die jeder der drei Mail-Bestände beim Schreiben tut
/// (§4.7): die nächste Nummer vergeben und prüfen, ob es den Eintrag schon
/// gibt.
///
/// Zusammengezogen am 03.09.2026. Vorher stand beides in
/// <see cref="MailVorlagenRepository"/>, <see cref="GrussformelnRepository"/>
/// und <see cref="AnredeBausteineRepository"/> je einmal — mitsamt der Falle
/// in <see cref="GibtEsSchonAsync{T}"/>, die dort dreimal erklärt werden
/// musste und beim vierten Bestand ein viertes Mal übersehen worden wäre.
/// </summary>
public static class BestandVergabe
{
    /// <summary>
    /// Die nächste freie Nummer: höchste vergebene + 1, im leeren Bestand 1.
    ///
    /// Serverseitig und nicht über <c>AUTOINCREMENT</c>, weil die Seeds feste
    /// Nummern tragen (<c>HasData</c>) — die Kanzlei-Vorlage soll beim Ändern
    /// dieselbe Zeile bleiben.
    /// </summary>
    public static async Task<int> NaechsteIdAsync<T>(
        IQueryable<T> bestand,
        CancellationToken cancellationToken)
        where T : class, IBestandEintrag
        => await bestand.AnyAsync(cancellationToken)
            ? await bestand.MaxAsync(e => e.Id, cancellationToken) + 1
            : 1;

    /// <summary>
    /// Der nächste Platz am Ende der Liste: höchste Sortierung + 10, im leeren
    /// Bestand 10. Ein neuer Eintrag soll die gewohnte Reihenfolge der
    /// vorhandenen nicht durcheinanderbringen.
    /// </summary>
    public static async Task<int> NaechsteSortierungAsync<T>(
        IQueryable<T> bestand,
        CancellationToken cancellationToken)
        where T : class, IBestandEintragMitReihenfolge
        => await bestand.AnyAsync(cancellationToken)
            ? await bestand.MaxAsync(e => e.Sortierung, cancellationToken) + 10
            : 10;

    /// <summary>
    /// Ob es den Eintrag schon gibt. <paramref name="gleiche"/> ist die
    /// gefilterte Abfrage („alle mit diesem Namen"),
    /// <paramref name="eigeneId"/> die Nummer des Eintrags, der gerade
    /// geschrieben wird — beim Anlegen null.
    /// </summary>
    /// <remarks>
    /// Die Fallunterscheidung ist die eigentliche Auskunft dieser Methode:
    /// Ein durchgehendes <c>e.Id != eigeneId</c> übersetzt EF bei
    /// <c>eigeneId == null</c> zu <c>Id &lt;&gt; NULL</c>. Das ist in SQL
    /// weder wahr noch falsch, sondern unbekannt, und trifft deshalb nie —
    /// beim Anlegen bliebe jede Dublette unerkannt.
    /// </remarks>
    public static Task<bool> GibtEsSchonAsync<T>(
        IQueryable<T> gleiche,
        int? eigeneId,
        CancellationToken cancellationToken)
        where T : class, IBestandEintrag
        => eigeneId is null
            ? gleiche.AnyAsync(cancellationToken)
            : gleiche.Where(e => e.Id != eigeneId.Value).AnyAsync(cancellationToken);
}
