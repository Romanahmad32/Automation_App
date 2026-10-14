using Microsoft.Extensions.Hosting;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ein <see cref="IHostApplicationLifetime"/>, der nur mitschreibt (#196):
/// <see cref="StopApplication"/> zählt und löst wie das Original
/// <see cref="ApplicationStopping"/> aus — beendet aber keinen Wirt.
/// </summary>
internal sealed class LebensdauerAttrappe : IHostApplicationLifetime, IDisposable
{
    private readonly CancellationTokenSource _gestartet = new();
    private readonly CancellationTokenSource _haeltAn = new();
    private readonly CancellationTokenSource _angehalten = new();
    private readonly TaskCompletionSource _gestoppt = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private int _stopps;

    public CancellationToken ApplicationStarted => _gestartet.Token;

    public CancellationToken ApplicationStopping => _haeltAn.Token;

    public CancellationToken ApplicationStopped => _angehalten.Token;

    /// <summary>Wie oft <see cref="StopApplication"/> gerufen wurde.</summary>
    public int Stopps => Volatile.Read(ref _stopps);

    /// <summary>Erfüllt beim ersten <see cref="StopApplication"/>.</summary>
    public Task Gestoppt => _gestoppt.Task;

    public void StopApplication()
    {
        Interlocked.Increment(ref _stopps);
        _haeltAn.Cancel();
        _gestoppt.TrySetResult();
    }

    public void Dispose()
    {
        _gestartet.Dispose();
        _haeltAn.Dispose();
        _angehalten.Dispose();
    }
}
