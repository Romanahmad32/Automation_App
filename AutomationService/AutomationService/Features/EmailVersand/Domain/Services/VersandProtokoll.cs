using System.Text.Json;
using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Hält fest, was zu einem Vorgang hinausgegangen ist (§4.7).
///
/// <b>Geschrieben wird erst hinterher.</b> Der Eintrag entsteht nach der
/// erfolgreichen Einlieferung beim Postausgangsserver, nie davor — ein
/// Protokoll, das Mails verzeichnet, die nie hinausgingen, ist als Nachweis
/// wertlos.
///
/// <b>Und es hält den Versand nie auf.</b> Scheitert das Schreiben, ist die
/// Mail trotzdem beim Empfänger; eine Ausnahme an dieser Stelle würde dem
/// Anwalt einen Fehlschlag melden, den es nicht gab, und ihn ein zweites Mal
/// senden lassen.
/// </summary>
public sealed class VersandProtokoll(AutomationDbContext db, ILogger<VersandProtokoll> logger)
{
    /// <summary>
    /// Schreibt den Eintrag. Ohne Vorgangsreferenz geschieht nichts: Ein
    /// Anschreiben ohne Vorgang (der Dialog lässt sich auch leer öffnen) hat
    /// keine Akte, an der es hinge.
    /// </summary>
    public async Task SchreibeAsync(VersandEintrag eintrag, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(eintrag.VorgangReferenz))
        {
            return;
        }

        try
        {
            db.Versandprotokoll.Add(new VersandEintragEntity
            {
                VorgangReferenz = eintrag.VorgangReferenz.Trim(),
                GesendetAm = eintrag.GesendetAm.UtcDateTime,
                Weg = eintrag.Weg.ToString(),
                Absender = eintrag.Absender,
                EmpfaengerJson = Liste(eintrag.Empfaenger),
                KopieJson = Liste(eintrag.Kopie),
                Betreff = eintrag.Betreff,
                AnhaengeJson = Liste(eintrag.Anhaenge),
                ImGesendetOrdner = eintrag.ImGesendetOrdner,
                MessageId = eintrag.MessageId,
            });
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ausnahme) when (ausnahme is not OperationCanceledException)
        {
            logger.LogWarning(
                ausnahme,
                "Der Versand an {Anzahl} Empfänger ließ sich nicht protokollieren. Die Mail ist hinaus.",
                eintrag.Empfaenger.Count);
        }
    }

    /// <summary>Alle Versände zu diesem Vorgang, der jüngste zuerst.</summary>
    public async Task<IReadOnlyList<VersandEintrag>> ZuAsync(
        string referenz,
        CancellationToken cancellationToken)
    {
        var gesucht = referenz.Trim();
        if (gesucht.Length == 0)
        {
            return [];
        }

        var eintraege = await db.Versandprotokoll
            .AsNoTracking()
            .Where(e => e.VorgangReferenz == gesucht)
            .OrderByDescending(e => e.GesendetAm)
            .ToListAsync(cancellationToken);

        return [.. eintraege.Select(Aus)];
    }

    /// <summary>
    /// Je Vorgang der jüngste Versand — für die Liste in der Vorgangsverwaltung,
    /// die sonst je Zeile einzeln nachfragen müsste.
    ///
    /// Gruppiert wird im Arbeitsspeicher und nicht in SQL: Das Protokoll einer
    /// Einzelkanzlei umfasst Hunderte Zeilen, nicht Millionen, und ein
    /// <c>GroupBy … First()</c> ist der eine LINQ-Ausdruck, den EF je nach
    /// Fassung nicht mehr übersetzt — ein Fehler, der erst zur Laufzeit
    /// auffiele.
    /// </summary>
    public async Task<IReadOnlyList<VersandEintrag>> LetzteJeVorgangAsync(
        CancellationToken cancellationToken)
    {
        var eintraege = await db.Versandprotokoll
            .AsNoTracking()
            .OrderByDescending(e => e.GesendetAm)
            .ToListAsync(cancellationToken);

        return
        [
            .. eintraege
                .GroupBy(e => e.VorgangReferenz, StringComparer.OrdinalIgnoreCase)
                .Select(gruppe => Aus(gruppe.First())),
        ];
    }

    private static VersandEintrag Aus(VersandEintragEntity entity) => new(
        entity.VorgangReferenz,
        new DateTimeOffset(DateTime.SpecifyKind(entity.GesendetAm, DateTimeKind.Utc)),
        Enum.TryParse<VersandWeg>(entity.Weg, out var weg) ? weg : VersandWeg.Direktversand,
        entity.Absender,
        Namen(entity.EmpfaengerJson),
        Namen(entity.KopieJson),
        entity.Betreff,
        Namen(entity.AnhaengeJson),
        entity.ImGesendetOrdner,
        entity.MessageId);

    private static string Liste(IReadOnlyList<string> werte) => JsonSerializer.Serialize(werte);

    /// <summary>
    /// Unlesbares JSON ergibt eine leere Liste, keinen Fehler: Ein Eintrag mit
    /// Zeitpunkt und Betreff ist als Nachweis immer noch mehr wert als eine
    /// Ansicht, die wegen einer alten Zeile gar nichts zeigt.
    /// </summary>
    private static List<string> Namen(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
