namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Hält ersetzte Dateien bis zum erfolgreichen Datenbanktausch zur Rückabwicklung bereit.</summary>
public sealed class ImportDateien(string arbeitsordner) : IDisposable
{
    readonly List<(string Ziel, string? Vorher)> _aenderungen = [];
    bool _bestaetigt;

    public IReadOnlyList<string> Vorlagen(string quelle, string ziel)
    {
        // Das bestehende Verhalten bleibt: abweichende lokale Vorlagen ausdrücklich melden.
        foreach (var datei in Directory.EnumerateFiles(quelle, "*.docx", SearchOption.AllDirectories))
        {
            var pfad = Path.Combine(ziel, Path.GetRelativePath(quelle, datei));
            if (!File.Exists(pfad) && !SicherungsArchiv.IstSperrdatei(datei))
                _aenderungen.Add((pfad, null));
        }
        return VorlagenWiederherstellung.StelleWiederHer(quelle, ziel);
    }

    public void Anhaenge(string quelle, string ziel)
    {
        foreach (var datei in Directory.EnumerateFiles(quelle, "*", SearchOption.AllDirectories))
        {
            var pfad = Path.Combine(ziel, Path.GetRelativePath(quelle, datei));
            string? vorher = null;
            if (File.Exists(pfad))
            {
                vorher = Path.Combine(arbeitsordner, $"rollback-{Guid.NewGuid():N}");
                File.Copy(pfad, vorher);
            }
            _aenderungen.Add((pfad, vorher));
            Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
            File.Copy(datei, pfad, overwrite: true);
        }
    }

    public void Bestaetige() => _bestaetigt = true;

    public void Dispose()
    {
        if (_bestaetigt) return;
        foreach (var (ziel, vorher) in _aenderungen.AsEnumerable().Reverse())
        {
            if (vorher is null) File.Delete(ziel);
            else File.Copy(vorher, ziel, overwrite: true);
        }
    }
}
