using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Akten bleiben in OneDrive; ihre Verweise werden an den Stammordner des Zielrechners gebunden.</summary>
public static class AktenPfadSicherung
{
    const string Anker = "@akten/";

    public static async Task PasseAnAsync(string datenbank, bool export, CancellationToken ct)
    {
        await using var db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={datenbank};Pooling=False").Options)
        { IsolierteSicherung = true };
        var settings = await db.KanzleiSettings.FirstOrDefaultAsync(ct);
        var wurzel = AppOrdnerPfad.LoeseAuf(settings?.AktenStammordner);
        foreach (var vorgang in await db.Vorgaenge.ToListAsync(ct))
        {
            vorgang.AktenOrdner = PasseAn(vorgang.AktenOrdner, wurzel, export);
            vorgang.DokumentPfad = PasseAn(vorgang.DokumentPfad, wurzel, export);
        }
        await db.SaveChangesAsync(ct);
    }

    public static string? PasseAn(string? pfad, string? wurzel, bool export)
    {
        if (string.IsNullOrEmpty(pfad)) return pfad;
        if (!export && pfad.StartsWith(Anker, StringComparison.Ordinal))
        {
            if (string.IsNullOrWhiteSpace(wurzel))
                throw new InvalidBackupException("Bitte auf diesem Rechner zuerst den synchronisierten Aktenstammordner einstellen.");
            var rest = pfad[Anker.Length..];
            if (Path.IsPathRooted(rest) || rest.Contains(':') || rest.Split(['/', '\\']).Contains(".."))
                throw new InvalidBackupException("Ein Aktenverweis in der Sicherung ist ungültig.");
            return Path.Combine(wurzel, rest.Replace('/', Path.DirectorySeparatorChar));
        }
        if (export && !string.IsNullOrWhiteSpace(wurzel) && Path.IsPathFullyQualified(pfad))
        {
            var rest = Path.GetRelativePath(wurzel, pfad);
            if (!Path.IsPathRooted(rest) && !rest.Split(['/', '\\']).Contains(".."))
                return Anker + rest.Replace('\\', '/');
        }
        // Andere OneDrive-Pfade tragen ihren Kontotyp; niemals einen fremden Benutzernamen erraten.
        return export ? AppOrdnerPfad.MacheRelativ(pfad) : AppOrdnerPfad.LoeseAuf(pfad) ?? pfad;
    }
}
