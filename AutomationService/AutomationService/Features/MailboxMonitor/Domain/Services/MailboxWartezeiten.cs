namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Wartezeiten des Postfach-Monitors. Beide enden vorzeitig, wenn sich die
/// Konfiguration ändert — sonst würde ein gerade hinterlegter Zugang bis zu
/// mehreren Minuten wirkungslos bleiben.
/// </summary>
public static class MailboxWartezeiten
{
    /// <summary>Wartet, bis sich die Konfiguration ändert oder der Host herunterfährt.</summary>
    public static async Task WarteAufNeukonfigurationAsync(
        MailboxConfigStore configStore,
        CancellationToken stoppingToken)
    {
        ArgumentNullException.ThrowIfNull(configStore);

        using var linked = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, configStore.ChangeToken);
        try
        {
            await Task.Delay(Timeout.InfiniteTimeSpan, linked.Token);
        }
        catch (OperationCanceledException)
        {
            // Entweder Shutdown oder Konfigurationsänderung — der Aufrufer wertet neu aus.
        }
    }

    /// <summary>
    /// Verzögerung vor dem nächsten Verbindungsversuch.
    /// </summary>
    /// <returns>true, wenn die volle Zeit abgelaufen ist; false bei vorzeitigem Abbruch.</returns>
    public static async Task<bool> WarteAsync(
        TimeSpan delay,
        CancellationToken changeToken,
        CancellationToken stoppingToken)
    {
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, changeToken);
        try
        {
            await Task.Delay(delay, linked.Token);
            return true;
        }
        catch (OperationCanceledException)
        {
            return false;
        }
    }
}
