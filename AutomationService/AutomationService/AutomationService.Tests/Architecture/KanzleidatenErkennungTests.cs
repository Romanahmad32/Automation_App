using System.IO.Compression;
using System.Text;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Haelt die Erkennung hinter <see cref="KanzleidatenTests"/> scharf. Ohne
/// diese Faelle bliebe der Waechter gruen, auch wenn er nichts mehr erkennt --
/// im Bestand gibt es (hoffentlich) nie einen Fund, an dem das auffiele.
///
/// Alle Werte sind erfunden oder verbreitete Lehrbuchbeispiele: die
/// Beispiel-IBAN DE89 3704 ..., die in jeder IBAN-Erklaerung steht, und die
/// USt-IdNr. zu 12345678 mit der passenden Pruefziffer. Die Dokumente
/// entstehen im Speicher: Eine .docx mit einer IBAN, die hier versioniert
/// laege, fiele selbst unter die Regel.
/// </summary>
public class KanzleidatenErkennungTests
{
    const string WordNamensraum = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    /// <summary>Eine .docx, deren Kopfzeile die Laeufe eines Absatzes traegt.</summary>
    static byte[] DocxMitKopfzeile(params string[] laeufe)
    {
        var absatz = string.Concat(laeufe.Select(lauf =>
            $"<w:r><w:t xml:space=\"preserve\">{lauf}</w:t></w:r>"));
        return Archiv(
            ("word/document.xml", $"<w:document xmlns:w=\"{WordNamensraum}\"><w:body><w:p><w:r><w:t>Sehr geehrte Damen und Herren,</w:t></w:r></w:p></w:body></w:document>"),
            ("word/header1.xml", $"<w:hdr xmlns:w=\"{WordNamensraum}\"><w:p>{absatz}</w:p></w:hdr>"));
    }

    static byte[] Archiv(params (string Name, string Xml)[] teile)
    {
        using var speicher = new MemoryStream();
        using (var archiv = new ZipArchive(speicher, ZipArchiveMode.Create))
        {
            foreach (var (name, xml) in teile)
            {
                using var schreiber = new StreamWriter(archiv.CreateEntry(name).Open(), Encoding.UTF8);
                schreiber.Write(xml);
            }
        }

        return speicher.ToArray();
    }

    static IReadOnlyList<string> Funde(byte[] datei) => Kanzleidaten.Funde(Dokumentinhalt.Text(datei));

    [Fact]
    public void Eine_IBAN_ueber_mehrere_Laeufe_der_Kopfzeile_wird_erkannt()
    {
        Funde(DocxMitKopfzeile("Bankverbindung: IBAN DE8", "9 3704 00", "44 0532 0130 00"))
            .Should().Contain("IBAN");
    }

    [Fact]
    public void Eine_Zeichenfolge_mit_falscher_Pruefziffer_ist_keine_IBAN()
    {
        Funde(DocxMitKopfzeile("IBAN DE88 3704 0044 0532 0130 00")).Should().BeEmpty();
    }

    [Fact]
    public void Platzhalter_eines_Musters_sind_kein_Fund()
    {
        Funde(DocxMitKopfzeile(
                "IBAN: {{IBAN}} BIC: {{BIC}} St.-Nr.: {{Steuernummer}} USt-IdNr.: {{UStId}}"))
            .Should().BeEmpty();
    }

    [Fact]
    public void Steuernummer_und_USt_IdNr_werden_erkannt()
    {
        Funde(DocxMitKopfzeile("St.-Nr. 012/345/67890 · USt-IdNr. DE 123 456 788"))
            .Should().BeEquivalentTo("Steuernummer", "USt-IdNr.");
    }

    [Fact]
    public void Eine_USt_IdNr_mit_falscher_Pruefziffer_ist_kein_Fund()
    {
        Funde(DocxMitKopfzeile("USt-IdNr. DE123456789")).Should().BeEmpty();
    }

    [Fact]
    public void Alte_Bankangaben_werden_erkannt()
    {
        Funde(DocxMitKopfzeile("Kto.-Nr. 1234567 · BLZ 370 400 44 · BIC COBADEFFXXX"))
            .Should().BeEquivalentTo("Kontonummer oder BLZ", "BIC");
    }

    [Fact]
    public void Benachbarte_Zellen_einer_Tabelle_verschmelzen_nicht()
    {
        var mappe = Archiv(("xl/sharedStrings.xml",
            "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
            "<si><t>IBAN</t></si><si><t>DE89370400440532013000</t></si></sst>"));

        Funde(mappe).Should().Contain("IBAN");
    }

    [Fact]
    public void Eine_Mail_wird_als_Text_gelesen()
    {
        Funde(Encoding.Latin1.GetBytes("Subject: Rechnung\r\n\r\nIBAN DE89 3704 0044 0532 0130 00\r\n"))
            .Should().Contain("IBAN");
    }

    [Fact]
    public void Ein_Schreiben_ohne_Kanzleidaten_ist_sauber()
    {
        Funde(DocxMitKopfzeile("Az. 12/26 C05 · Schaden vom 01.09.2026 · Betrag 1.234,56 EUR"))
            .Should().BeEmpty();
    }
}
