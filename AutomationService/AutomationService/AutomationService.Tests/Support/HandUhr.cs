namespace AutomationService.Tests.Support;

/// <summary>
/// Eine Uhr, die nur weiterläuft, wenn der Test sie vorstellt — für
/// Verzögerungen, deren Dauer geprüft werden soll, ohne sie abzuwarten.
/// Sie kann genau so viel, wie <c>Task.Delay(TimeSpan, TimeProvider, CancellationToken)</c>
/// braucht: einmalige Timer. Ein Zeitraum (<c>period</c>) wird nicht wiederholt.
/// </summary>
internal sealed class HandUhr : TimeProvider
{
    private readonly Lock _sperre = new();
    private readonly List<Wecker> _wecker = [];
    private DateTimeOffset _jetzt = new(2026, 10, 14, 12, 0, 0, TimeSpan.Zero);

    public override DateTimeOffset GetUtcNow()
    {
        lock (_sperre)
        {
            return _jetzt;
        }
    }

    public override ITimer CreateTimer(TimerCallback callback, object? state, TimeSpan dueTime, TimeSpan period)
    {
        var wecker = new Wecker(this, callback, state);
        wecker.Change(dueTime, period);
        return wecker;
    }

    /// <summary>Stellt die Uhr vor und löst jeden Timer aus, der bis dahin fällig ist — auf dem Thread des Tests.</summary>
    public void Vorstellen(TimeSpan dauer)
    {
        List<Wecker> faellig;
        lock (_sperre)
        {
            _jetzt += dauer;
            faellig = [.. _wecker.Where(wecker => wecker.Faellig <= _jetzt)];
            _wecker.RemoveAll(faellig.Contains);
        }

        foreach (var wecker in faellig)
        {
            wecker.Klingeln();
        }
    }

    private sealed class Wecker(HandUhr uhr, TimerCallback rueckruf, object? zustand) : ITimer
    {
        public DateTimeOffset Faellig { get; private set; }

        public bool Change(TimeSpan dueTime, TimeSpan period)
        {
            lock (uhr._sperre)
            {
                uhr._wecker.Remove(this);
                if (dueTime != Timeout.InfiniteTimeSpan)
                {
                    Faellig = uhr._jetzt + dueTime;
                    uhr._wecker.Add(this);
                }
            }

            return true;
        }

        public void Klingeln() => rueckruf(zustand);

        public void Dispose()
        {
            lock (uhr._sperre)
            {
                uhr._wecker.Remove(this);
            }
        }

        public ValueTask DisposeAsync()
        {
            Dispose();
            return ValueTask.CompletedTask;
        }
    }
}
