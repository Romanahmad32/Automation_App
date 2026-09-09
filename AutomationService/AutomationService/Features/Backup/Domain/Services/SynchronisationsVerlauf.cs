using System.Text.Json;
using AutomationService.Core.Ablage;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Nur lokal: die tatsächlich übernommene Ausgangsbasis wird niemals aus OneDrive erraten.</summary>
public sealed class SynchronisationsVerlauf(string datenbank, Func<string> vorlagen)
{
    string? _aktivitaet;
    public string? Aktivitaet { get => Volatile.Read(ref _aktivitaet); set => Volatile.Write(ref _aktivitaet, value); }

    public static SemaphoreSlim Schleuse { get; } = new(1, 1);

    readonly BestandsFingerabdruck _inhalt = new(datenbank, vorlagen);
    readonly string _pfad = Path.Combine(Path.GetDirectoryName(datenbank)!, "synchronisations-verlauf.json");

    public string Fingerabdruck() => _inhalt.Lies();

    public LokalerSynchronisationsStand? Lies() => File.Exists(_pfad)
        ? JsonSerializer.Deserialize<LokalerSynchronisationsStand>(File.ReadAllText(_pfad))
            ?? throw new InvalidBackupException("Der lokale Synchronisationsstand ist nicht lesbar.")
        : null;

    public bool HatAenderungen() => Lies() is not { } stand || stand.Fingerabdruck != Fingerabdruck();

    public void Merke(ArbeitsplatzEintrag eintrag, string fingerabdruck)
    {
        var temp = _pfad + $".{Guid.NewGuid():N}.tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(new LokalerSynchronisationsStand(eintrag, fingerabdruck)));
        AtomareAblage.Ersetze(temp, _pfad);
    }
}

public sealed record LokalerSynchronisationsStand(ArbeitsplatzEintrag Eintrag, string Fingerabdruck);
