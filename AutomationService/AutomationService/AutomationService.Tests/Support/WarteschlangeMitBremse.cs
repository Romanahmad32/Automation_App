using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Die echte PDF-Warteschlange, davor eine Bremse.
///
/// <para>
/// Sie ersetzt das, was vorher <c>PdfAttrappe.Verzoegerung</c> geleistet hat.
/// Solange die Wandlung im Schreiblauf steckte, war sie der lange Schritt
/// <em>innerhalb</em> der <c>RegisterSpiegelSchleuse</c> — und damit die
/// Stelle, an der sich zwei Läufe messbar trafen. Seit die Wandlung
/// nachgezogen wird (§6.2), endet der geschützte Abschnitt beim Einreihen, und
/// im Betrieb dauert dort nichts mehr. Ohne einen Ersatz könnte kein Test mehr
/// zeigen, dass die Schleuse überhaupt etwas tut: Zwei Läufe liefen im Test
/// einfach zu schnell aneinander vorbei.
/// </para>
///
/// <para>
/// <see cref="MaximalGleichzeitig"/> zählt deshalb, wie viele Läufe zugleich im
/// Einreihen standen — dem letzten Schritt des geschützten Abschnitts. Ohne
/// Schleuse sind das zwei, mit Schleuse einer.
/// </para>
/// </summary>
/// <param name="echt">
/// Die Warteschlange, an die weitergegeben wird — die echte, damit die
/// Aufträge danach wirklich abgearbeitet werden können.
/// </param>
public sealed class WarteschlangeMitBremse(RegisterPdfWarteschlange echt) : IRegisterPdfWarteschlange
{
    readonly Lock schloss = new();

    int gleichzeitig;

    /// <summary>Hält das Einreihen an, damit ein zweiter Lauf Zeit hat, hineinzulaufen.</summary>
    public TimeSpan Verzoegerung { get; set; } = TimeSpan.Zero;

    /// <summary>Wie viele Läufe zur selben Zeit im Einreihen standen.</summary>
    public int MaximalGleichzeitig { get; private set; }

    /// <summary>Wie viele Aufträge insgesamt durchgingen.</summary>
    public int Einreihungen { get; private set; }

    public bool Laeuft => echt.Laeuft;

    public void Einreihen(RegisterPdfAuftrag auftrag)
    {
        var jetzt = Interlocked.Increment(ref gleichzeitig);
        try
        {
            lock (schloss)
            {
                MaximalGleichzeitig = Math.Max(MaximalGleichzeitig, jetzt);
                Einreihungen++;
            }

            // Blockierend und nicht await: Einreihen ist im Betrieb synchron,
            // und genau diese Synchronität soll die Bremse nachbilden.
            if (Verzoegerung > TimeSpan.Zero) Thread.Sleep(Verzoegerung);

            echt.Einreihen(auftrag);
        }
        finally
        {
            Interlocked.Decrement(ref gleichzeitig);
        }
    }
}
