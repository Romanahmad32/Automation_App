using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// EF-Core-Repository für den Single-Row-Einstellungssatz. Upsert läuft immer auf
/// <see cref="KanzleiSettingsEntity.SingletonId"/>, sodass nie ein zweiter Satz
/// entsteht. Die Standardwerte spiegeln die Defaults der Flutter-Entität, damit
/// sich beim Umstieg nichts ändert.
/// </summary>
public sealed class KanzleiSettingsRepository(AutomationDbContext db)
    : IKanzleiSettingsRepository
{
    public async Task<KanzleiSettingsEntity> GetAsync(CancellationToken cancellationToken = default)
    {
        var entity = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);
        return entity ?? CreateDefault();
    }

    public async Task<KanzleiSettingsEntity> SaveAsync(
        KanzleiSettingsEntity settings,
        CancellationToken cancellationToken = default)
    {
        var existing = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);

        if (existing is null)
        {
            settings.Id = KanzleiSettingsEntity.SingletonId;
            db.KanzleiSettings.Add(settings);
            await db.SaveChangesAsync(cancellationToken);
            return settings;
        }

        CopyInto(existing, settings);
        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<KanzleiSettingsEntity> ErhoeheAuftragsnummerAsync(
        CancellationToken cancellationToken = default)
    {
        var existing = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);

        if (existing is null)
        {
            existing = CreateDefault();
            existing.LaufendeAuftragsnummer += 1;
            db.KanzleiSettings.Add(existing);
        }
        else
        {
            existing.LaufendeAuftragsnummer += 1;
        }

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    /// <summary>
    /// Übernimmt alle fachlichen Felder (ohne Id) in die getrackte Zeile.
    /// „Alle" ist wörtlich zu nehmen und wird geprüft
    /// (<c>KanzleiSettingsRepositoryTests</c>): Ein hier vergessenes Feld geht
    /// beim Speichern still verloren, während die Oberfläche Erfolg meldet.
    /// </summary>
    static void CopyInto(KanzleiSettingsEntity target, KanzleiSettingsEntity source)
    {
        target.Personentyp = source.Personentyp;
        target.Name = source.Name;
        target.StrasseHausnummer = source.StrasseHausnummer;
        target.Postleitzahl = source.Postleitzahl;
        target.Ort = source.Ort;
        target.EmailAdresse = source.EmailAdresse;
        target.Telefonnummer = source.Telefonnummer;
        target.LaufendeAuftragsnummer = source.LaufendeAuftragsnummer;
        target.Abteilung = source.Abteilung;
        target.TabellenkopfFarbeHex = source.TabellenkopfFarbeHex;
        target.AktenStammordner = source.AktenStammordner;
        target.MailSignatur = source.MailSignatur;
        target.MailSignaturHtml = source.MailSignaturHtml;
        target.RegisterAblageOrdner = source.RegisterAblageOrdner;
        target.RegisterDateiname = source.RegisterDateiname;
        target.RegisterNachAbschlussSchreiben = source.RegisterNachAbschlussSchreiben;
        target.RegisterExportFilter = source.RegisterExportFilter;
    }

    /// <summary>
    /// Standardwerte, identisch zu den Defaults der Flutter-Entität. Öffentlich,
    /// damit der Vorgangsabschluss (VorgangAbschlussService) beim Erst-Inkrement
    /// dieselben Defaults anlegt statt sie zu duplizieren.
    /// </summary>
    public static KanzleiSettingsEntity CreateDefault() => new()
    {
        Id = KanzleiSettingsEntity.SingletonId,
        Personentyp = "Rechtsanwalt",
        Abteilung = "C03",
        LaufendeAuftragsnummer = 1,
        TabellenkopfFarbeHex = "D9D9D9",
        RegisterDateiname = RegisterSpiegelVorgabe.Dateiname,
        RegisterNachAbschlussSchreiben = true,
        RegisterExportFilter = RegisterSpiegelVorgabe.FilterAlle,
    };
}
