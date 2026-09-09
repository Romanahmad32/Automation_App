using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Warteschlange und der Nachzug hinter der PDF-Fassung des
/// Register-Spiegels (§6.2 „Word sofort, PDF nachgezogen").
///
/// Eigene Datei, weil hier eine andere Frage geprüft wird als in
/// <see cref="RegisterSpiegelPdfTests"/>: nicht, was im Ablageordner liegen
/// darf, sondern was der abgesetzte Lauf tut — ob er sichtbar ist, ob er
/// meldet, was er getan hat, und was er tut, wenn ihn ein neuerer Lauf
/// überholt hat.
///
/// Der Hintergrunddienst wird dabei nicht gestartet, sondern von Hand
/// ausgelöst (<c>RegisterSpiegelUmgebung.PdfNachziehenAsync</c>). Ein Test, der
/// auf einen Planer wartet, prüft am Ende den Planer.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterPdfNachzugTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    async Task BestandAnlegen()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
    }

    /// <summary>
    /// „Dass ein PDF gerade entsteht, ist an der Oberfläche ablesbar" (§6.2).
    /// Geprüft auf beiden Wegen: im Ergebnis des Schreiblaufs <b>und</b> im
    /// Stand — der Anwalt wechselt den Tab, und beim Zurückkommen muss der
    /// laufende Lauf noch zu sehen sein.
    /// </summary>
    [Fact]
    public async Task PdfLaeuft_IstWaehrendDesLaufsWahrUndDanachFalsch()
    {
        await BestandAnlegen();

        var geschrieben = await _umgebung.Dienst().SchreibeAsync();

        geschrieben.PdfLaeuft.Should().BeTrue();
        (await _umgebung.Dienst().StandAsync()).PdfLaeuft.Should().BeTrue(
            "sonst wäre der Lauf nach einem Fensterwechsel unsichtbar");

        await _umgebung.PdfNachziehenAsync();

        (await _umgebung.Dienst().StandAsync()).PdfLaeuft.Should().BeFalse();
    }

    /// <summary>
    /// Der Wortlaut der Meldung. Sie ist der einzige Weg, auf dem die
    /// Oberfläche vom Ende des Laufs erfährt — ohne sie bliebe ihr nur, im
    /// Takt nachzufragen.
    /// </summary>
    [Fact]
    public async Task Nachzug_MeldetDieFertigeFassungMitPfad()
    {
        await BestandAnlegen();
        await _umgebung.Dienst().SchreibeAsync();

        _umgebung.Hub.Meldungen.Should().BeEmpty("vor dem Nachzug gibt es nichts zu melden");

        await _umgebung.PdfNachziehenAsync();

        var meldung = _umgebung.Hub.LetztePdfMeldung;
        meldung.Should().NotBeNull();
        meldung!.Fertig.Should().BeTrue();
        meldung.PdfPfad.Should().Be(_umgebung.PdfPfad);
        meldung.Fehler.Should().BeNull();
    }

    /// <summary>
    /// Ein Fehlschlag der Wandlung lässt die .docx unberührt und wird
    /// gemeldet, nicht geworfen. Der Nachzug läuft in einem
    /// <c>BackgroundService</c>: Eine Ausnahme, die dort durchkäme, beendete
    /// die Schleife — und danach entstünde still kein PDF mehr, bis die App
    /// neu startet.
    /// </summary>
    [Fact]
    public async Task Nachzug_MeldetDenFehlschlagUndLaesstDieWordDateiUnberuehrt()
    {
        await BestandAnlegen();
        _umgebung.Pdf.Wirft = new InvalidOperationException("Word ist nicht verfügbar.");
        await _umgebung.Dienst().SchreibeAsync();
        var docxVorher = await File.ReadAllBytesAsync(_umgebung.DocxPfad);

        var lauf = async () => await _umgebung.PdfNachziehenAsync();

        await lauf.Should().NotThrowAsync();
        (await File.ReadAllBytesAsync(_umgebung.DocxPfad)).Should().Equal(docxVorher);
        File.Exists(_umgebung.PdfPfad).Should().BeFalse();
        var meldung = _umgebung.Hub.LetztePdfMeldung;
        meldung.Should().NotBeNull();
        meldung!.Fertig.Should().BeFalse();
        meldung.PdfPfad.Should().BeNull();
        meldung.Fehler.Should().Contain("Word ist nicht verfügbar");
    }

    /// <summary>
    /// Der überholte Auftrag. Zwischen Einreihen und Wandeln kann ein neuerer
    /// Lauf die .docx im Ablageordner ersetzt haben — dann wäre das PDF des
    /// älteren Auftrags genau die Fassung von gestern, die §6.2 verbietet.
    ///
    /// Erspart wird dabei auch die teuerste Minute des Tages: Beim Bestand der
    /// Kanzlei kostet jede Wandlung zwanzig Sekunden, und wer am Feierabend
    /// fünf Vorgänge abschliesst, braucht nur die letzte.
    /// </summary>
    [Fact]
    public async Task Nachzug_UeberspringtEinenUeberholtenAuftrag()
    {
        await BestandAnlegen();
        await _umgebung.Dienst().SchreibeAsync();
        await _umgebung.VorgangAnlegen("02/26 C03", 2);
        await _umgebung.Dienst().SchreibeAsync();

        var abgearbeitet = await _umgebung.PdfNachziehenAsync();

        abgearbeitet.Should().Be(2, "eingereiht waren zwei Aufträge");
        _umgebung.Pdf.Aufrufe.Should().Be(1, "gewandelt wird nur der aktuelle Bestand");
        File.Exists(_umgebung.PdfPfad).Should().BeTrue();
        _umgebung.Hub.Meldungen.Should().HaveCount(
            1, "über einen übersprungenen Auftrag ist der Oberfläche nichts zu sagen");
    }

    public void Dispose() => _umgebung.Dispose();
}
