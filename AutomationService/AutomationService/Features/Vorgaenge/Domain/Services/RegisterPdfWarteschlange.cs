using System.Threading.Channels;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Die Warteschlange selbst: ein Kanal und ein Zähler.
///
/// <para>
/// <b>Warum ein Kanal.</b> Einreihen darf nicht blockieren — es passiert
/// mitten im Vorgangsabschluss, dessen ganzer Sinn hier ist, sofort fertig zu
/// sein. Abgearbeitet wird dagegen streng nacheinander: Die Wandlung ruft Word
/// über COM, und zwei Wandlungen zugleich sind dort keine halbe Zeit, sondern
/// zwei Instanzen, die sich um denselben unsichtbaren Word-Prozess streiten.
/// <c>SingleReader</c> hält das fest, damit es nicht nur zufällig so ist.
/// </para>
///
/// <para>
/// <b>Warum unbegrenzt.</b> Ein überholter Auftrag wird nicht hier verworfen,
/// sondern erst beim Abarbeiten erkannt (der Stand sagt, welcher Bestand im
/// Ablageordner liegt). Das ist der einzige Ort, an dem sich „überholt" sicher
/// beantworten lässt — und er fängt zugleich den Auftrag, der schon in der
/// Wandlung steht und aus keiner Warteschlange mehr entfernt werden könnte.
/// Verworfen wird also einheitlich an einer Stelle statt an zwei.
/// </para>
///
/// <para>
/// <b>Der Zähler</b> trägt <see cref="Laeuft"/> und damit die Anzeige an der
/// Oberfläche. Er zählt beim Einreihen hoch und erst nach dem Abarbeiten
/// herunter — nicht beim Entnehmen: Sonst stünde die Oberfläche für die Dauer
/// der ganzen Wandlung auf „kein PDF unterwegs", also genau während der
/// zwanzig Sekunden, um die es geht.
/// </para>
///
/// Reicht als Singleton im Prozess, wie die <see cref="RegisterSpiegelSchleuse"/>
/// daneben: Die App schreibt diese Dateien allein.
/// </summary>
public sealed class RegisterPdfWarteschlange : IRegisterPdfWarteschlange
{
    readonly Channel<RegisterPdfAuftrag> kanal =
        Channel.CreateUnbounded<RegisterPdfAuftrag>(new UnboundedChannelOptions { SingleReader = true });

    int offen;

    public bool Laeuft => Volatile.Read(ref offen) > 0;

    public void Einreihen(RegisterPdfAuftrag auftrag)
    {
        ArgumentNullException.ThrowIfNull(auftrag);

        // Hochzählen, bevor geschrieben wird: Zwischen Schreiben und Zählen
        // könnte der Abnehmer den Auftrag längst erledigt und auf eine 0
        // heruntergezählt haben — der Zähler stünde danach auf 1 und die
        // Oberfläche für immer auf „PDF läuft".
        Interlocked.Increment(ref offen);
        if (kanal.Writer.TryWrite(auftrag)) return;

        Interlocked.Decrement(ref offen);
    }

    /// <summary>
    /// Arbeitet ab, bis der Dienst beendet wird — der Weg des
    /// Hintergrunddienstes.
    /// </summary>
    /// <param name="arbeit">
    /// Was mit einem Auftrag geschieht. Darf nicht werfen: Eine Ausnahme, die
    /// hier durchkäme, beendete die Schleife, und danach entstünde still kein
    /// PDF mehr — bis zum nächsten Start der App.
    /// </param>
    /// <param name="cancellationToken">Beendet die Schleife beim Herunterfahren.</param>
    public async Task AbarbeitenAsync(Func<RegisterPdfAuftrag, Task> arbeit, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(arbeit);

        await foreach (var auftrag in kanal.Reader.ReadAllAsync(cancellationToken))
        {
            await FuehreAusAsync(arbeit, auftrag);
        }
    }

    /// <summary>
    /// Arbeitet ab, was gerade eingereiht ist, und kehrt dann zurück.
    ///
    /// Für Tests, die den Zeitpunkt prüfen — „die .docx liegt, bevor das PDF
    /// entsteht" ist eine Aussage über die Reihenfolge und lässt sich nur
    /// zeigen, wenn der Test das Abarbeiten selbst auslöst, statt auf einen
    /// Hintergrunddienst zu warten. Dasselbe Muster wie
    /// <c>SicherungsZeitgeber.TickAsync</c>.
    /// </summary>
    /// <returns>Wie viele Aufträge abgearbeitet wurden.</returns>
    public async Task<int> AlleAbarbeitenAsync(Func<RegisterPdfAuftrag, Task> arbeit)
    {
        ArgumentNullException.ThrowIfNull(arbeit);

        var abgearbeitet = 0;
        while (kanal.Reader.TryRead(out var auftrag))
        {
            await FuehreAusAsync(arbeit, auftrag);
            abgearbeitet++;
        }

        return abgearbeitet;
    }

    /// <summary>
    /// Der Zähler geht auch dann herunter, wenn die Arbeit wirft — sonst hinge
    /// die Anzeige an einem Fehlschlag fest, den niemand mehr auflösen kann.
    /// </summary>
    async Task FuehreAusAsync(Func<RegisterPdfAuftrag, Task> arbeit, RegisterPdfAuftrag auftrag)
    {
        try
        {
            await arbeit(auftrag);
        }
        finally
        {
            Interlocked.Decrement(ref offen);
        }
    }
}
