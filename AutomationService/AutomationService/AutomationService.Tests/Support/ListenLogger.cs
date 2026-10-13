using Microsoft.Extensions.Logging;

namespace AutomationService.Tests.Support;

/// <summary>
/// Sammelt die Meldungen eines Dienstes in einer Liste — für Tests, die
/// festhalten, <i>warum</i> ein Dienst nichts getan hat. Ein Dienst, der
/// wortlos zurückkehrt, sieht von außen gleich aus, ob er die Prüfung
/// bestanden oder gar nicht erst erreicht hat.
/// </summary>
internal sealed class ListenLogger<T> : ILogger<T>
{
    public List<string> Nachrichten { get; } = [];

    public IDisposable? BeginScope<TState>(TState state)
        where TState : notnull => null;

    public bool IsEnabled(LogLevel logLevel) => true;

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        ArgumentNullException.ThrowIfNull(formatter);
        Nachrichten.Add(formatter(state, exception));
    }
}
