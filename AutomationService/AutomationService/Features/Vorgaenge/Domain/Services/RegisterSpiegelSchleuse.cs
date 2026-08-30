namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Lässt immer nur einen Schreiblauf des Register-Spiegels durch.
///
/// Zwei Läufe gleichzeitig sind kein Sonderfall, sondern der Normalfall am
/// Feierabend: Der Anwalt schliesst einen Vorgang ab — der Abschluss stösst
/// den Spiegel an — und drückt währenddessen auf „Register jetzt schreiben".
/// <see cref="RegisterSpiegelBauordner"/> trennt zwar die Zwischenstände, aber
/// nicht die letzten Schritte am Zielort. Dort greifen beide auf dieselben
/// zwei Dateien zu, und die Schritte sind einzeln atomar, zusammen aber nicht:
///
/// <list type="bullet">
/// <item>Lauf A nimmt den Schreibschutz von der .docx
/// (<c>AtomareAblage.Ersetze</c>).</item>
/// <item>Lauf B setzt ihn im selben Moment wieder — er ist gerade fertig
/// geworden.</item>
/// <item>Lauf A scheitert am eigenen Schutz und meldet „Die Datei ist
/// geöffnet", obwohl niemand sie geöffnet hat.</item>
/// </list>
///
/// Der Satz ist dann nicht nur falsch, er ist irreführend: Er nennt eine
/// Ursache, die der Anwalt vergeblich sucht. Dazu kommt der Fingerabdruck —
/// beide Läufe lesen ihn, bevor einer ihn schreibt, und der zweite überschreibt
/// den Eintrag des ersten mit einem Bestand, der so nie im Ordner lag.
///
/// Bewusst nur für das Schreiben. <c>StandAsync</c> läuft daran vorbei: Es
/// liest bloss, und beim Öffnen der Registerseite hinter einem laufenden
/// Export zu warten hiesse, den Tabwechsel um die Dauer einer PDF-Wandlung zu
/// verzögern. Dass es dabei keinen halben Stand liest, sichert
/// <see cref="RegisterSpiegelStand"/> selbst.
///
/// Reicht als Singleton im Prozess, weil die App die Datei allein schreibt.
/// Zwei Arbeitsplätze auf demselben Ablageordner wären etwas anderes — dagegen
/// hilft nur, was der Synchronisierungsdienst tut: eine Konfliktkopie anlegen,
/// die <see cref="KonfliktkopieName"/> erkennt und die Leiste meldet.
/// </summary>
public sealed class RegisterSpiegelSchleuse : IDisposable
{
    readonly SemaphoreSlim tor = new(1, 1);

    /// <summary>
    /// Führt <paramref name="lauf"/> aus, sobald kein anderer Lauf mehr
    /// unterwegs ist.
    /// </summary>
    public async Task<T> NacheinanderAsync<T>(Func<Task<T>> lauf, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(lauf);

        await tor.WaitAsync(cancellationToken);
        try
        {
            return await lauf();
        }
        finally
        {
            tor.Release();
        }
    }

    public void Dispose() => tor.Dispose();
}
