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
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelNebenlaeufigkeitTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    /// <summary>
    /// Die Wandlung ist im Betrieb der lange Schritt — dort treffen sich zwei
    /// Läufe. Ohne Schleuse steht der zweite mitten darin, während der erste
    /// noch nicht am Zielort war.
    /// </summary>
    [Fact]
    public async Task ZweiLaeufeSchreibenNacheinander()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Verzoegerung = TimeSpan.FromMilliseconds(150);

        var ergebnisse = await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));

        _umgebung.Pdf.MaximalGleichzeitig.Should().Be(
            1, "die Schleuse laesst immer nur einen Schreiblauf durch");
        ergebnisse.Should().OnlyContain(e => e.Geschrieben);
        ergebnisse.Should().OnlyContain(e => e.Fehler == null);
    }

    /// <summary>
    /// Die Kehrseite: Der zweite Lauf darf nicht ewig warten, sondern muss
    /// hinter dem ersten wirklich durchkommen — und dann den Ordner so
    /// vorfinden, wie der erste ihn verlassen hat.
    /// </summary>
    [Fact]
    public async Task DerZweiteLaufSiehtDenOrdnerDesErsten()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Verzoegerung = TimeSpan.FromMilliseconds(50);

        await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));

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
        _umgebung.Pdf.Verzoegerung = TimeSpan.FromMilliseconds(50);

        await Task.WhenAll(
            _umgebung.Dienst().SchreibeAsync(erzwingen: true),
            _umgebung.Dienst().SchreibeAsync(erzwingen: true));

        var dritter = await _umgebung.Dienst().SchreibeAsync();

        dritter.Geschrieben.Should().BeFalse("der Bestand hat sich nicht geändert");
        dritter.Grund.Should().Contain("nicht geändert");
    }

    public void Dispose() => _umgebung.Dispose();
}
