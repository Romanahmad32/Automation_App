using System.Text.RegularExpressions;
using AutomationService.Core.Persistence;
using AutomationService.Features.Versicherer.Domain.Persistence;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Versicherer.Domain.Services;

/// <summary>
/// SQLite-gestützte Umsetzung von <see cref="IVersichererWissen"/>. Dedupe über
/// den normalisierten Namen (Unique-Index): Schreibvarianten derselben
/// Gesellschaft landen in einer Zeile, deren Felder mit jeder Antwort
/// vollständiger bzw. aktueller werden.
/// </summary>
public sealed partial class VersichererWissen(AutomationDbContext db) : IVersichererWissen
{
    public async Task MerkeAusAntwortAsync(
        ZentralrufReplyData data,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(data);

        var name = data.VersichererName?.Trim();
        if (string.IsNullOrEmpty(name))
        {
            return;
        }

        var schluessel = NormalisiereName(name);
        var eintrag = await db.Versicherer
            .FirstOrDefaultAsync(v => v.NameNormalisiert == schluessel, cancellationToken);

        if (eintrag is null)
        {
            eintrag = new VersichererEntity { Name = name, NameNormalisiert = schluessel };
            db.Versicherer.Add(eintrag);
        }

        // Neuere Antwort gewinnt — aber nur mit tatsächlich vorhandenen Werten;
        // eine Antwort ohne E-Mail darf eine früher gelernte E-Mail nicht löschen.
        eintrag.Name = name;
        eintrag.Strasse = Bevorzuge(data.VersichererStrasse, eintrag.Strasse);
        eintrag.Plz = Bevorzuge(data.VersichererPlz, eintrag.Plz);
        eintrag.Ort = Bevorzuge(data.VersichererOrt, eintrag.Ort);
        eintrag.Telefon = Bevorzuge(data.VersichererTelefon, eintrag.Telefon);
        eintrag.Fax = Bevorzuge(data.VersichererFax, eintrag.Fax);
        eintrag.Email = Bevorzuge(data.VersichererEmail, eintrag.Email);
        eintrag.ZuletztAktualisiertAm = DateTime.Now;
        eintrag.Quelle = string.IsNullOrWhiteSpace(data.AnfrageDatum)
            ? "Zentralruf-Antwort"
            : $"Zentralruf-Antwort zur Anfrage vom {data.AnfrageDatum.Trim()}";

        await db.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<VersichererEntity>> GetAllAsync(
        CancellationToken cancellationToken = default) =>
        await db.Versicherer.OrderBy(v => v.Name).ToListAsync(cancellationToken);

    /// <summary>
    /// Normalisiert den Namen zum Dedupe-Schlüssel: getrimmt, Großschreibung,
    /// Whitespace kollabiert — analog zur Referenz-Normalisierung im Frontend.
    /// </summary>
    public static string NormalisiereName(string name) =>
        WhitespaceRegex().Replace(name, " ").Trim().ToUpperInvariant();

    static string? Bevorzuge(string? neu, string? vorhanden) =>
        string.IsNullOrWhiteSpace(neu) ? vorhanden : neu.Trim();

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespaceRegex();
}
