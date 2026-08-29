using System.Globalization;
using System.Text.Json;
using AutomationService.Core.Persistence;
using AutomationService.Features.MailboxMonitor.Domain.Persistence;
using AutomationService.Features.Versicherer.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// SQLite-gestützte Umsetzung von <see cref="IReceivedReplyStore"/>. Ersetzt den
/// früheren prozessinternen Speicher: erfasste Antworten überdauern nun den
/// Neustart. Pro Treffer wird genau eine Zeile geschrieben; die Dublettenprüfung
/// stützt sich auf den Unique-Index über den Mail-Schlüssel.
///
/// Beim Anlegen wird best-effort der Vorgang zur Referenz gesucht und nur als
/// Verknüpfung vermerkt (<see cref="ReceivedReplyEntity.VorgangId"/>/<c>Zugeordnet</c>);
/// der Vorgang selbst bleibt unverändert — das Übernehmen ist der bestätigte
/// Schritt im Frontend.
/// </summary>
public sealed class DbReceivedReplyStore(
    AutomationDbContext db,
    IVorgangRepository vorgaenge,
    IVersichererWissen versichererWissen)
    : IReceivedReplyStore
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<bool> ContainsAsync(string dedupeKey, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrEmpty(dedupeKey);
        return await db.ReceivedReplies.AnyAsync(r => r.DedupeKey == dedupeKey, cancellationToken);
    }

    public async Task<ReceivedReply?> AddAsync(
        string dedupeKey,
        ZentralrufReplyData data,
        string? subject,
        string? from,
        IReadOnlyList<string> warnings,
        string? rawText = null,
        IReadOnlyList<string>? anhangPfade = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrEmpty(dedupeKey);
        ArgumentNullException.ThrowIfNull(data);

        if (await db.ReceivedReplies.AnyAsync(r => r.DedupeKey == dedupeKey, cancellationToken))
        {
            return null;
        }

        // Best-effort: passenden Vorgang über die Referenz finden und nur verknüpfen.
        var match = string.IsNullOrWhiteSpace(data.Referenz)
            ? null
            : await vorgaenge.GetByReferenzAsync(data.Referenz, cancellationToken);

        // Fallback bei verstümmelter/fehlender Referenz: eindeutiger Treffer über
        // Gegner-Kennzeichen + Unfalldatum unter den angefragten Vorgängen — nur
        // als vermutete Zuordnung vermerkt, bestätigen bleibt beim Anwalt.
        var vermutet = match is null
            && !string.IsNullOrWhiteSpace(data.Kennzeichen)
            && !string.IsNullOrWhiteSpace(data.UnfallDatum)
            && await vorgaenge.FindeAngefragteZuUnfallAsync(
                data.Kennzeichen, data.UnfallDatum, cancellationToken) is [var einziger]
            ? einziger
            : null;

        var entity = new ReceivedReplyEntity
        {
            DedupeKey = dedupeKey,
            EmpfangenAm = DateTime.Now,
            Referenz = data.Referenz,
            Betreff = subject,
            Absender = from,
            RohdatenJson = JsonSerializer.Serialize(data, JsonOptions),
            WarnungenJson = JsonSerializer.Serialize(warnings, JsonOptions),
            AnhaengeJson = JsonSerializer.Serialize(anhangPfade ?? [], JsonOptions),
            Rohtext = rawText,
            Quittiert = false,
            Zugeordnet = match is not null,
            VorgangId = match?.Id ?? vermutet?.Id,
            ZuordnungVermutet = vermutet is not null,
        };

        db.ReceivedReplies.Add(entity);
        await db.SaveChangesAsync(cancellationToken);

        // Versicherer-Wissensbasis mitlernen lassen (Verbesserungsplan Punkt 4).
        await versichererWissen.MerkeAusAntwortAsync(data, cancellationToken);

        return Map(entity);
    }

    public async Task<IReadOnlyList<ReceivedReply>> GetAllAsync(
        bool includeAcknowledged,
        CancellationToken cancellationToken = default)
    {
        var query = db.ReceivedReplies.AsQueryable();
        if (!includeAcknowledged)
        {
            query = query.Where(r => !r.Quittiert);
        }

        var entities = await query
            .OrderByDescending(r => r.EmpfangenAm)
            .ToListAsync(cancellationToken);

        return entities.Select(Map).ToList();
    }

    public async Task<bool> AcknowledgeAsync(string id, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrEmpty(id);
        if (!int.TryParse(id, NumberStyles.Integer, CultureInfo.InvariantCulture, out var key))
        {
            return false;
        }

        var entity = await db.ReceivedReplies.FirstOrDefaultAsync(r => r.Id == key, cancellationToken);
        if (entity is null)
        {
            return false;
        }

        entity.Quittiert = true;
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<int> CountAsync(CancellationToken cancellationToken = default) =>
        await db.ReceivedReplies.CountAsync(cancellationToken);

    /// <summary>Bildet die Persistenz-Zeile auf das Domänen-/DTO-Modell ab.</summary>
    private static ReceivedReply Map(ReceivedReplyEntity e) => new()
    {
        Id = e.Id.ToString(CultureInfo.InvariantCulture),
        ReceivedAt = new DateTimeOffset(e.EmpfangenAm),
        Subject = e.Betreff,
        From = e.Absender,
        Data = Deserialize(e.RohdatenJson),
        Warnings = DeserializeListe(e.WarnungenJson),
        AnhangPfade = DeserializeListe(e.AnhaengeJson),
        RawText = e.Rohtext,
        Acknowledged = e.Quittiert,
        ZuordnungVermutet = e.ZuordnungVermutet,
    };

    private static ZentralrufReplyData Deserialize(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return new ZentralrufReplyData();
        }

        try
        {
            return JsonSerializer.Deserialize<ZentralrufReplyData>(json, JsonOptions) ?? new ZentralrufReplyData();
        }
        catch (JsonException)
        {
            return new ZentralrufReplyData();
        }
    }

    /// <summary>Eine als JSON abgelegte Zeichenkettenliste; leer, wenn nichts oder Unlesbares dasteht.</summary>
    private static List<string> DeserializeListe(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        try
        {
            return JsonSerializer.Deserialize<List<string>>(json, JsonOptions) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
