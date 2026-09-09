using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ersetzt den Register-Spiegel in Tests des Vorgangsabschlusses.
///
/// Nötig, weil der echte Dienst eine Datei schreibt und Word aufruft — beides
/// hat in einem Test über Status und Auftragsnummer nichts verloren. Die
/// Attrappe kann außerdem <see cref="Wirft"/>: Damit lässt sich prüfen, was der
/// eigentliche Punkt der Reihenfolge ist — dass ein Fehlschlag beim Spiegel den
/// bereits festgeschriebenen Abschluss nicht mehr anfasst.
///
/// Seit §4.8 („der Abschluss wartet nicht mehr darauf, dass die
/// Register-Dateien geschrieben sind") stößt der Abschluss den Spiegel
/// abgesetzt an. Daraus folgen zwei Zusätze:
/// <see cref="Angestossen"/> ist der Wartepunkt — ein Test, der direkt nach
/// dem Abschluss den Zähler liest, findet sonst mal eine 1 und mal eine 0, je
/// nachdem, wie der Planer die Aufgabe gelegt hat. Und
/// <see cref="Anhalten"/> hält den Lauf fest: Kehrt der Abschluss dann
/// trotzdem zurück, hat er nachweislich nicht gewartet.
/// </summary>
public sealed class RegisterSpiegelAttrappe : IRegisterSpiegelService, IDisposable
{
    readonly TaskCompletionSource _angestossen =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    readonly TaskCompletionSource _tor =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    bool _anhalten;

    public int Aufrufe { get; private set; }

    /// <summary>Ausnahme, die <see cref="SchreibeAsync"/> werfen soll.</summary>
    public Exception? Wirft { get; set; }

    /// <summary>Wird erfüllt, sobald <see cref="SchreibeAsync"/> begonnen hat.</summary>
    public Task Angestossen => _angestossen.Task;

    /// <summary>Lässt den Lauf nicht durch, bis <see cref="Freigeben"/> kommt.</summary>
    public void Anhalten() => _anhalten = true;

    /// <summary>Lässt einen angehaltenen Lauf weiterlaufen.</summary>
    public void Freigeben() => _tor.TrySetResult();

    public async Task<RegisterSpiegelErgebnis> SchreibeAsync(
        bool erzwingen = false,
        CancellationToken cancellationToken = default)
    {
        Aufrufe++;
        _angestossen.TrySetResult();
        if (_anhalten) await _tor.Task;
        if (Wirft is not null) throw Wirft;
        return Leer();
    }

    public Task<RegisterSpiegelErgebnis> StandAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(Leer());

    static RegisterSpiegelErgebnis Leer() =>
        new(false, "Attrappe", null, null, null, null, false, 0, null, []);

    /// <summary>
    /// Gibt einen noch angehaltenen Lauf frei. Ohne das bliebe am Ende des
    /// Tests eine Aufgabe stehen, die auf ein Tor wartet, das nie aufgeht.
    /// </summary>
    public void Dispose() => Freigeben();
}
