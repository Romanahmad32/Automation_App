using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Zaehlt Aufrufe der automatischen Sicherung, statt eine zu schreiben.
///
/// Der Abschluss stoesst sie nebenher an (<c>Task.Run</c>, ohne <c>await</c>) —
/// deshalb ein Wartepunkt statt eines blossen Zaehlers: Ein Test, der direkt
/// nach dem Abschluss nachsieht, findet sonst mal eine 1 und mal eine 0, je
/// nachdem, wie der Planer die Aufgabe gelegt hat.
/// </summary>
public sealed class AutomatischeSicherungAttrappe : IAutomatischeSicherung
{
    readonly TaskCompletionSource _angestossen =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    public int Aufrufe { get; private set; }
    public int Arbeitsbeginne { get; private set; }

    /// <summary>Wird erfuellt, sobald <see cref="SchreibeAsync"/> gelaufen ist.</summary>
    public Task Angestossen => _angestossen.Task;

    public Task<LetzteSicherung?> SchreibeAsync(CancellationToken cancellationToken = default)
    {
        Aufrufe++;
        _angestossen.TrySetResult();
        return Task.FromResult<LetzteSicherung?>(null);
    }

    public void MerkeArbeitsbeginn() => Arbeitsbeginne++;
}
