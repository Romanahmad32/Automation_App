using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Startet nichts und merkt sich jeden Aufruf (#196). Mit <see cref="Ausnahme"/>
/// scheitert der Start wie bei einem Virenscanner, der die Datei sperrt; mit
/// <see cref="SofortBeendetMit"/> beendet sich das „Setup" sofort wieder, wie
/// bei einem zweiten, das am <c>SetupMutex</c> scheitert; mit
/// <see cref="Sperrgrund"/> darf hier gar keins starten. Gewartet wird nie
/// wirklich — die Anlauffrist kostet im Test keine Zeit.
/// </summary>
internal sealed class InstallerStarterAttrappe : IInstallerStarter
{
    private readonly List<InstallerAufruf> _aufrufe = [];
    private readonly List<InstallerLaufAttrappe> _laeufe = [];
    private readonly Lock _sperre = new();

    public Exception? Ausnahme { get; set; }

    /// <summary>Der Rückgabewert, mit dem sich das Setup sofort beendet; <c>null</c>: es läuft weiter.</summary>
    public int? SofortBeendetMit { get; set; }

    public string? Sperrgrund { get; set; }

    /// <summary>Läuft im Moment des Starts — um festzuhalten, was dann schon auf der Platte liegt.</summary>
    public Action<InstallerAufruf>? BeimStart { get; set; }

    public IReadOnlyList<InstallerAufruf> Aufrufe
    {
        get
        {
            lock (_sperre)
            {
                return [.. _aufrufe];
            }
        }
    }

    /// <summary>Je erfolgreichem Start ein Lauf — mit der Frist, auf die gewartet wurde.</summary>
    public IReadOnlyList<InstallerLaufAttrappe> Laeufe
    {
        get
        {
            lock (_sperre)
            {
                return [.. _laeufe];
            }
        }
    }

    public IInstallerLauf Starte(InstallerAufruf aufruf)
    {
        BeimStart?.Invoke(aufruf);
        if (Ausnahme is not null)
        {
            throw Ausnahme;
        }

        var lauf = new InstallerLaufAttrappe(SofortBeendetMit);
        lock (_sperre)
        {
            _aufrufe.Add(aufruf);
            _laeufe.Add(lauf);
        }

        return lauf;
    }
}

/// <summary>Ein Setup, das läuft oder sich mit <paramref name="rueckgabewert"/> beendet hat — ohne zu warten.</summary>
internal sealed class InstallerLaufAttrappe(int? rueckgabewert) : IInstallerLauf
{
    /// <summary>Wie lange der Dienst hingesehen hätte; <c>null</c>, solange er nicht gefragt hat.</summary>
    public TimeSpan? Frist { get; private set; }

    public bool Entsorgt { get; private set; }

    public int? WarteAufEnde(TimeSpan frist)
    {
        Frist = frist;
        return rueckgabewert;
    }

    public void Dispose() => Entsorgt = true;
}
