namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Ein Auftrag in der Warteschlange des Word-Threads — PDF-Umwandlung, Druck
/// oder (ohne Pfad) das Vorwärmen.
///
/// Der Aufrufer wartet nur begrenzt (<c>ConversionTimeoutSeconds</c>), und die
/// Wartezeit schließt die Zeit in der Schlange mit ein. Gibt er auf, bevor
/// Word den Auftrag angefasst hat, darf der Auftrag nicht mehr laufen: Beim
/// Druck meldet die App dem Anwalt dann „nicht gedruckt" und öffnet die Datei
/// zum Selbst-Drucken — käme das Blatt danach doch noch aus dem Drucker, läge
/// die Vollmacht doppelt da. Wer zuerst kommt, Word-Thread
/// (<see cref="Beginne"/>) oder Aufrufer (<see cref="GibAuf"/>), entscheidet
/// das atomar; der andere erfährt es aus dem Rückgabewert.
/// </summary>
public sealed class WordAuftrag(string? docxPfad, bool drucken = false)
{
    private const int Wartet = 0;
    private const int Laeuft = 1;
    private const int Aufgegeben = 2;

    private int _zustand = Wartet;

    /// <summary>Die Datei; <c>null</c> heißt: nur Word vorwärmen.</summary>
    public string? DocxPfad { get; } = docxPfad;

    public bool Drucken { get; } = drucken;

    public TaskCompletionSource<byte[]> Ergebnis { get; } =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    /// <summary>
    /// Der Word-Thread beansprucht den Auftrag. <c>false</c>: Der Aufrufer hat
    /// schon aufgegeben, der Auftrag fällt aus.
    /// </summary>
    public bool Beginne() => Interlocked.CompareExchange(ref _zustand, Laeuft, Wartet) == Wartet;

    /// <summary>
    /// Der Aufrufer wartet nicht länger. <c>true</c>: Word hatte den Auftrag
    /// noch nicht angefasst und wird es nicht mehr tun. <c>false</c>: Er läuft
    /// schon — ein Druck kann dann noch herauskommen.
    /// </summary>
    public bool GibAuf()
    {
        var aufgegeben = Interlocked.CompareExchange(ref _zustand, Aufgegeben, Wartet) == Wartet;
        if (aufgegeben)
        {
            Ergebnis.TrySetCanceled();
        }

        return aufgegeben;
    }
}
