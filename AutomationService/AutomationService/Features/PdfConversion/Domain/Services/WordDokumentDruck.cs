using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Ein Druckauftrag in einer schon laufenden Word-Instanz: Dokument öffnen,
/// den Drucker ablesen, <c>PrintOut</c>, schließen. Läuft ausschließlich auf
/// dem STA-Thread von <see cref="WordInteropPdfConversionService"/>, der die
/// Instanz hält — Word-COM ist nicht threadsafe.
///
/// <c>Background: false</c> ist der Punkt: Im Hintergrunddruck kehrte
/// <c>PrintOut</c> sofort zurück, das anschließende <c>Close</c> nähme Word
/// den Auftrag unter der Hand weg, und der Aufrufer löschte eine Datei, die
/// noch gar nicht in der Warteschlange stand.
///
/// Wiederholt wird nur, was <b>vor</b> dem Druck scheitert. Die Queue baut
/// Word nach einer <see cref="COMException"/> neu auf und führt den Auftrag
/// ein zweites Mal aus — für eine PDF harmlos, für einen Druck ein zweites
/// Blatt. Deshalb verlässt ein Fehler ab <c>PrintOut</c> diese Klasse nie
/// als <see cref="COMException"/>: Ob Word das Blatt schon an die
/// Warteschlange gegeben hat, weiß dann niemand.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WordDokumentDruck(ILogger logger)
{
    private const int WdDoNotSaveChanges = 0;     // WdSaveOptions.wdDoNotSaveChanges

    /// <returns>Der Drucker, an den Word übergeben hat; <c>null</c>, wenn Word ihn nicht nannte.</returns>
    public string? Drucke(dynamic word, string docxPath)
    {
        dynamic? document = null;
        string? drucker = null;
        try
        {
            // Scheitert das Öffnen an einer weggebrochenen Instanz, darf die
            // Queue neu aufbauen und wiederholen — gedruckt ist noch nichts.
            //
            // Visible: true, anders als beim PDF-Export: Ein unsichtbar
            // geöffnetes Dokument hat kein aktives Dokumentfenster, und ohne
            // das verweigert Word PrintOut mit 0x800A11FD („nicht verfügbar,
            // weil kein Dokumentfenster aktiv ist"). ExportAsFixedFormat
            // braucht das Fenster nicht. Auf dem Bildschirm erscheint trotzdem
            // nichts — die Anwendung selbst bleibt unsichtbar
            // (WordInteropPdfConversionService.EnsureWordApplication).
            document = word.Documents.Open(
                docxPath,
                ReadOnly: true,
                AddToRecentFiles: false,
                Visible: true);
            drucker = AktiverDrucker(word);
            try
            {
                document!.PrintOut(Background: false);
            }
            catch (COMException exception)
            {
                throw new InvalidOperationException("Word hat den Druckauftrag abgebrochen.", exception);
            }
        }
        finally
        {
            if (document is not null)
            {
                SchliesseNachDruck(document);
            }
        }

        return drucker;
    }

    /// <summary>
    /// Der Drucker, an den <c>PrintOut</c> gleich geht — für die Rückmeldung an
    /// den Anwalt. Lässt er sich nicht lesen, wird trotzdem gedruckt; und eine
    /// <see cref="COMException"/> von hier darf den Auftrag nicht wiederholen.
    /// </summary>
    private string? AktiverDrucker(dynamic word)
    {
        try
        {
            return WordDruckerName.AusActivePrinter((string?)word.ActivePrinter);
        }
        catch (COMException exception)
        {
            logger.LogInformation(exception, "Word nannte den aktiven Drucker nicht.");
            return null;
        }
    }

    /// <summary>
    /// Ein Fehler beim Schließen ist nicht der Fehler des Druckauftrags — und
    /// dürfte als <see cref="COMException"/> den Wiederholungsdruck auslösen.
    /// </summary>
    private void SchliesseNachDruck(dynamic document)
    {
        try
        {
            document.Close(WdDoNotSaveChanges);
            Marshal.ReleaseComObject(document);
        }
        catch (COMException exception)
        {
            logger.LogWarning(exception, "Word-Dokument ließ sich nach dem Druck nicht schließen.");
        }
    }
}
