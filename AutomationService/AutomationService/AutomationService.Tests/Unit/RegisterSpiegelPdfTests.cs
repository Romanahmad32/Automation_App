using AutomationService.Core.Ablage;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Register-Spiegel und seine PDF-Fassung (§6.2, #40).
///
/// Eigene Datei, weil hier eine eigene Frage geprüft wird: Die .docx ist die
/// verbindliche Fassung, das PDF die bequeme — und beide müssen im
/// Ablageordner immer dasselbe sagen. Ein PDF von gestern neben einer .docx
/// von heute ist der Fall, der einen Spiegel unbemerkt zur Lüge macht, denn
/// unterwegs liest man das PDF.
///
/// Seit §6.2 („Word sofort, PDF nachgezogen") entsteht das PDF <b>nach</b> der
/// Antwort. Damit gibt es einen Zwischenzustand, und er ist der eigentliche
/// Gegenstand dieser Datei: Was in ihm im Ablageordner liegen darf, und was
/// nicht. Was am Nachzug selbst hängt — Warteschlange, Meldung, überholte
/// Aufträge — steht in <see cref="RegisterPdfNachzugTests"/>.
///
/// Teilt sich <see cref="RegisterSpiegelUmgebung"/> mit
/// <see cref="RegisterSpiegelServiceTests"/>.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelPdfTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    RegisterSpiegelService Dienst() => _umgebung.Dienst();

    Task EinstellungenAnlegen() => _umgebung.EinstellungenAnlegen();

    Task VorgangAnlegen(string referenz, int nummer) => _umgebung.VorgangAnlegen(referenz, nummer);

    string Docx => _umgebung.DocxPfad;

    string Pdf => _umgebung.PdfPfad;

    static InvalidOperationException OhneWord() => new("Word ist nicht verfügbar.");

    /// <summary>
    /// Der Zeitpunkt, um den es in §6.2 geht: Die .docx liegt, bevor das PDF
    /// entsteht. Vorher war das eine Aussage über die Reihenfolge zweier
    /// Schritte in einem Lauf; jetzt ist es der Zustand, in dem der Anwalt
    /// weiterarbeitet, während Word noch zwanzig Sekunden rechnet.
    /// </summary>
    [Fact]
    public async Task Schreibe_LegtDieWordDateiAn_BevorDasPdfEntsteht()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeTrue();
        File.Exists(Docx).Should().BeTrue("die verbindliche Fassung ist sofort da");
        File.Exists(Pdf).Should().BeFalse("die bequeme Fassung entsteht danach");
        ergebnis.PdfPfad.Should().BeNull();
        ergebnis.PdfFehler.Should().BeNull("„noch nicht da\" ist kein Fehler");
        ergebnis.PdfLaeuft.Should().BeTrue();

        await _umgebung.PdfNachziehenAsync();

        File.Exists(Pdf).Should().BeTrue();
    }

    /// <summary>
    /// Ohne installiertes Word gibt es kein PDF — die .docx ist trotzdem die
    /// verbindliche Fassung und muss geschrieben werden.
    ///
    /// <b>Angepasst:</b> Der <c>PdfFehler</c> stand vorher im Ergebnis von
    /// <c>SchreibeAsync</c>. Dort kann er nicht mehr stehen — zu diesem
    /// Zeitpunkt hat noch niemand versucht zu wandeln. Gemeldet wird er, wo er
    /// jetzt entsteht: über den Hub, nach dem Nachzug.
    /// </summary>
    [Fact]
    public async Task Schreibe_LegtDieWordDateiAn_AuchWennDieWandlungScheitert()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Wirft = OhneWord();

        var ergebnis = await Dienst().SchreibeAsync();
        await _umgebung.PdfNachziehenAsync();

        ergebnis.Geschrieben.Should().BeTrue();
        _umgebung.Hub.LetztePdfMeldung!.Fehler.Should().Contain("Word ist nicht verfügbar");
        File.Exists(Docx).Should().BeTrue();
        File.Exists(Pdf).Should().BeFalse();
    }

    /// <summary>
    /// Beim ersten Lauf entstand ein PDF, beim zweiten scheitert die Wandlung.
    /// Bliebe das alte liegen, läse der Anwalt unterwegs ein Register ohne den
    /// neuen Vorgang — und die .docx daneben behauptete das Gegenteil.
    ///
    /// <b>Angepasst und dabei schärfer:</b> Geprüft wird jetzt schon im
    /// Zwischenzustand, also <em>vor</em> dem Nachzug. Genau das fordert §6.2
    /// („Solange kein neues PDF liegt, liegt auch kein altes"): Das veraltete
    /// PDF darf nicht die zwanzig Sekunden lang neben der neuen .docx stehen
    /// bleiben und erst am Ende verschwinden.
    /// </summary>
    [Fact]
    public async Task Schreibe_RaeumtDasVeraltetePdfWeg_WennDieWandlungScheitert()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await _umgebung.VollstaendigSchreibenAsync();
        File.Exists(Pdf).Should().BeTrue("die Ausgangslage ist ein vollständiger Spiegel");

        await VorgangAnlegen("02/26 C03", 2);
        _umgebung.Pdf.Wirft = OhneWord();
        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeTrue();
        zweiter.PdfPfad.Should().BeNull();
        File.Exists(Pdf).Should().BeFalse("ein PDF von gestern ist schlimmer als gar keins");

        await _umgebung.PdfNachziehenAsync();

        File.Exists(Pdf).Should().BeFalse("und es kommt auch nicht zurück");
        _umgebung.Hub.LetztePdfMeldung!.Fertig.Should().BeFalse();
    }

    /// <summary>
    /// Dasselbe, wenn die Wandlung gelingt: Auch dann liegt zwischen den
    /// beiden Läufen kein PDF — sonst wäre für die Dauer der Wandlung das
    /// alte neben der neuen .docx zu sehen, und gerade dieser Moment ist der
    /// gefährliche, weil eben etwas geändert wurde.
    /// </summary>
    [Fact]
    public async Task Schreibe_RaeumtDasVeraltetePdfWeg_SchonBevorDasNeueEntsteht()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await _umgebung.VollstaendigSchreibenAsync();
        var altesPdf = await File.ReadAllBytesAsync(Pdf);

        await VorgangAnlegen("02/26 C03", 2);
        await Dienst().SchreibeAsync();

        File.Exists(Docx).Should().BeTrue();
        File.Exists(Pdf).Should().BeFalse("solange kein neues PDF liegt, liegt auch kein altes");

        await _umgebung.PdfNachziehenAsync();

        File.Exists(Pdf).Should().BeTrue();
        altesPdf.Should().NotBeEmpty("die Ausgangslage war ein echtes PDF und nicht nichts");
    }

    /// <summary>
    /// Auf einem Rechner ohne Word entsteht nie ein PDF — „da liegt keins" ist
    /// dort der erwartete Zustand und darf nicht bei jedem Lauf als Änderung
    /// gelten. Sonst käme Revision 5341 durch die Hintertür zurück.
    /// </summary>
    [Fact]
    public async Task Schreibe_SchreibtNichtZweimalDenselbenBestand_AuchOhnePdfFassung()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Wirft = OhneWord();
        await _umgebung.VollstaendigSchreibenAsync();
        var ersterStand = File.GetLastWriteTimeUtc(Docx);

        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeFalse();
        zweiter.Grund.Should().Contain("nicht geändert");
        File.GetLastWriteTimeUtc(Docx).Should().Be(ersterStand);
    }

    /// <summary>
    /// Das PDF ist offen, die .docx nicht. Die .docx zieht dann um — gemeldet
    /// werden muss genau das, was auf der Platte steht, und nicht „nichts
    /// geschrieben".
    ///
    /// <b>Angepasst:</b> Dass das PDF nicht abgelegt werden konnte, steht
    /// nicht mehr im Ergebnis des Schreiblaufs — dort ist noch nichts
    /// versucht. Es steht in der Meldung des Nachzugs.
    /// </summary>
    [Fact]
    public async Task Schreibe_MeldetDieGeschriebeneWordDatei_WennNurDasPdfGesperrtIst()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await _umgebung.VollstaendigSchreibenAsync();

        await VorgangAnlegen("02/26 C03", 2);
        AtomareAblage.SchreibschutzLoesen(Pdf);
        using (new FileStream(Pdf, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var zweiter = await Dienst().SchreibeAsync();
            await _umgebung.PdfNachziehenAsync();

            zweiter.Geschrieben.Should().BeTrue();
            zweiter.DocxPfad.Should().Be(Docx);
            zweiter.PdfPfad.Should().BeNull();
            _umgebung.Hub.LetztePdfMeldung!.Fertig.Should().BeFalse();
            _umgebung.Hub.LetztePdfMeldung!.Fehler.Should().NotBeNull();
        }
    }

    public void Dispose() => _umgebung.Dispose();
}
