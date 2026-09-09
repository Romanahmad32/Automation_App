using System.Security.Cryptography;
using System.Text;

namespace AutomationService.Features.Backup.Domain.Services;

public static class UebergabePruefung
{
    public static bool IstFremderStand(ArbeitsplatzEintrag fremd, ArbeitsplatzEintrag? eigener)
    {
        if (fremd.GesichertAm is null || !SichererDateiname(fremd.Sicherung)) return false;
        if (fremd.Revision is not null && eigener?.Revision is not null)
            return fremd.Revision != eigener.Revision && !eigener.Vorfahren.Contains(fremd.Revision);
        return eigener?.GesichertAm is null || fremd.GesichertAm > eigener.GesichertAm;
    }

    public static bool Konflikt(ArbeitsplatzEintrag fremd, LokalerSynchronisationsStand? lokal, bool geaendert) =>
        lokal is not null && (geaendert || fremd.Revision is null || lokal.Eintrag.Revision is null
            || !fremd.Vorfahren.Contains(lokal.Eintrag.Revision));

    public static bool SichererDateiname(string? name) => !string.IsNullOrWhiteSpace(name)
        && !name.Contains('/') && !name.Contains('\\') && !name.Contains(':')
        && name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase);

    public static bool Vollstaendig(string ordner, ArbeitsplatzEintrag eintrag)
    {
        if (!SichererDateiname(eintrag.Sicherung)) return false;
        var datei = new FileInfo(Path.Combine(ordner, eintrag.Sicherung!));
        return datei.Exists && (eintrag.Bytes is null || datei.Length == eintrag.Bytes);
    }

    public static string Kennung(ArbeitsplatzEintrag eintrag, string? lokal) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{eintrag.Sicherung}|{eintrag.Revision}|{eintrag.Sha256}|{lokal}")));

    public static void PruefeStream(Stream strom, ArbeitsplatzEintrag angebot)
    {
        if (angebot.Bytes is { } bytes && strom.Length != bytes
            || angebot.Sha256 is { } hash && Convert.ToHexString(SHA256.HashData(strom)) != hash)
        {
            throw new InvalidBackupException("Die Übertragung ist noch nicht vollständig oder die Datei ist beschädigt. Bitte erneut prüfen.");
        }

        strom.Position = 0;
    }
}
