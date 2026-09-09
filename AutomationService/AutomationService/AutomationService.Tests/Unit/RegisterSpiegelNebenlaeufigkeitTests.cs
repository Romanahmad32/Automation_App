using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Zwei Schreibläufe zur selben Zeit (§6.2, #40).
///
/// Das ist kein Sonderfall, sondern der Normalfall am Feierabend: Der Anwalt
/// schliesst einen Vorgang ab — der Abschluss stösst den Spiegel an — und
/// drückt währenddessen auf „Register jetzt schreiben". Der Bauordner trennt
/// die Zwischenstände, aber am Zielort greifen beide auf dieselben zwei
/// Dateien zu, und die Schritte dort sind einzeln atomar, zusammen nicht: Der
/// Schreibschutz, den Lauf B gerade setzt, fällt Lauf A vor die Füsse, und
/// gemeldet wird „Die Datei ist geöffnet" — ein Satz, dessen Ursache der
/// Anwalt vergeblich sucht.
///
/// <b>Der lange Schritt hat den geschützten Abschnitt verlassen</b> (§6.2
/// „Word sofort, PDF nachgezogen"): Gemessen wird die Gleichzeitigkeit
/// deshalb nicht mehr an der Wandlung, sondern am Einreihen — dem letzten
/// Schritt, den die Schleuse noch umschliesst. Warum dafür eine Bremse nötig
/// ist, steht an <see cref="WarteschlangeMitBremse"/>.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelNebenlaeufigkeitTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    /// <summary>
    /// Ohne Schleuse stehen beide Läufe zugleich im geschützten Abschnitt,
    /// während keiner von ihnen am Zielort fertig ist.
    /// </summary>
    [Fact]
    public async Task ZweiLaeufeSchreibenNacheinander()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Bremse.Verzoegerung = TimeSpan.FromMilliseconds(150);

        var ergebnisse = await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));

        _umgebung.Bremse.MaximalGleichzeitig.Should().Be(
            1, "die Schleuse laesst immer nur einen Schreiblauf durch");
        ergebnisse.Should().OnlyContain(e => e.Geschrieben);
        ergebnisse.Should().OnlyContain(e => e.Fehler == null);
    }

    /// <summary>
    /// Und die Wandlungen treffen sich auch nicht: Der Nachzug arbeitet
    /// nacheinander ab. Zwei Wandlungen zugleich sind bei Word über COM keine
    /// halbe Zeit, sondern zwei Instanzen, die sich um denselben unsichtbaren
    /// Prozess streiten.
    /// </summary>
    [Fact]
    public async Task ZweiPdfAuftraegeWandelnNacheinander()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Verzoegerung = TimeSpan.FromMilliseconds(50);

        await _umgebung.Dienst().SchreibeAsync(erzwingen: true);
        await _umgebung.Dienst().SchreibeAsync(erzwingen: true);
        await _umgebung.PdfNachziehenAsync();

        _umgebung.Pdf.Aufrufe.Should().Be(2, "beide Aufträge betreffen denselben Bestand");
        _umgebung.Pdf.MaximalGleichzeitig.Should().Be(1, "der Nachzug hat genau einen Leser");
    }

    /// <summary>
    /// Die Kehrseite: Der zweite Lauf darf nicht ewig warten, sondern muss
    /// hinter dem ersten wirklich durchkommen — und dann den Ordner so
    /// vorfinden, wie der erste ihn verlassen hat.
    ///
    /// <b>Angepasst:</b> Die zwei Dateien werden nach dem Nachzug gezählt. Vor
    /// ihm liegt nur die .docx — das ist ab jetzt der richtige Zeitpunkt, und
    /// die Aussage „keine Zwischenstaende" gilt für beide.
    /// </summary>
    [Fact]
    public async Task DerZweiteLaufSiehtDenOrdnerDesErsten()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Bremse.Verzoegerung = TimeSpan.FromMilliseconds(50);

        await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));
        await _umgebung.PdfNachziehenAsync();

        Directory.EnumerateFiles(_umgebung.Ablage).Select(Path.GetFileName)
            .Should().HaveCount(2, "eine .docx und ein .pdf, keine Zwischenstaende");
        File.Exists(_umgebung.DocxPfad).Should().BeTrue();
        File.Exists(_umgebung.PdfPfad).Should().BeTrue();
    }

    /// <summary>
    /// Und der Stand darf nicht den Bestand des einen mit dem Zeitpunkt des
    /// anderen mischen: Nach beiden Läufen steht dort genau ein lesbarer
    /// Eintrag, sonst schriebe der nächste Abschluss auf Verdacht neu.
    /// </summary>
    [Fact]
    public async Task DerStandBleibtNachZweiLaeufenLesbar()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Bremse.Verzoegerung = TimeSpan.FromMilliseconds(50);

        await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));
        await _umgebung.PdfNachziehenAsync();

        var dritter = await _umgebung.Dienst().SchreibeAsync();

        dritter.Geschrieben.Should().BeFalse("der Bestand hat sich nicht geändert");
        dritter.Grund.Should().Contain("nicht geändert");
    }

    public void Dispose() => _umgebung.Dispose();
}
