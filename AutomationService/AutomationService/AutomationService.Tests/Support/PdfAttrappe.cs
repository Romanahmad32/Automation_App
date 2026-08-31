using System.Text;
using AutomationService.Features.PdfConversion.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ersetzt die PDF-Wandlung in Tests. Der echte Weg ruft Microsoft Word über
/// COM — auf einem Rechner ohne Word gäbe es den Test gar nicht, und mit Word
/// dauerte er Sekunden.
///
/// <see cref="Wirft"/> bildet genau diesen Rechner ohne Word nach: Dann muss
/// die .docx trotzdem geschrieben werden, denn sie ist die verbindliche
/// Fassung — das PDF ist die bequeme.
///
/// <see cref="Verzoegerung"/> und <see cref="MaximalGleichzeitig"/> gehören
/// zusammen: Die Wandlung ist im Betrieb der lange Schritt, in dem zwei Läufe
/// sich treffen können. Die Attrappe hält deshalb auf Wunsch an und zählt mit,
/// wie viele Läufe zugleich darin standen — daran hängt der Nachweis, dass
/// <c>RegisterSpiegelSchleuse</c> hält.
/// </summary>
public sealed class PdfAttrappe : IPdfConversionService
{
    public const string Inhalt = "%PDF-Attrappe";

    readonly Lock schloss = new();

    int aufrufe;
    int gleichzeitig;

    public Exception? Wirft { get; set; }

    /// <summary>Hält die Wandlung an, damit ein zweiter Lauf Zeit hat, hineinzulaufen.</summary>
    public TimeSpan Verzoegerung { get; set; } = TimeSpan.Zero;

    public int Aufrufe => Volatile.Read(ref aufrufe);

    /// <summary>Wie viele Wandlungen zur selben Zeit unterwegs waren.</summary>
    public int MaximalGleichzeitig { get; private set; }

    public async Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
    {
        var jetzt = Interlocked.Increment(ref gleichzeitig);
        lock (schloss) MaximalGleichzeitig = Math.Max(MaximalGleichzeitig, jetzt);

        try
        {
            Interlocked.Increment(ref aufrufe);
            if (Wirft is not null) throw Wirft;
            if (Verzoegerung > TimeSpan.Zero) await Task.Delay(Verzoegerung);
            return Encoding.UTF8.GetBytes(Inhalt);
        }
        finally
        {
            Interlocked.Decrement(ref gleichzeitig);
        }
    }

    public Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes) =>
        ConvertDocxToPdfAsync(string.Empty);
}
