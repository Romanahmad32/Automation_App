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
/// </summary>
public sealed class RegisterSpiegelAttrappe : IRegisterSpiegelService
{
    public int Aufrufe { get; private set; }

    /// <summary>Ausnahme, die <see cref="SchreibeAsync"/> werfen soll.</summary>
    public Exception? Wirft { get; set; }

    public Task<RegisterSpiegelErgebnis> SchreibeAsync(
        bool erzwingen = false,
        CancellationToken cancellationToken = default)
    {
        Aufrufe++;
        if (Wirft is not null) throw Wirft;
        return Task.FromResult(Leer());
    }

    public Task<RegisterSpiegelErgebnis> StandAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(Leer());

    static RegisterSpiegelErgebnis Leer() =>
        new(false, "Attrappe", null, null, null, null, 0, null, []);
}
