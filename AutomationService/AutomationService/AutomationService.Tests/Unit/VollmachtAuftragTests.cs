using AutomationService.Features.Vollmacht.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Werte, mit denen die Vollmacht gefüllt wird (§4.11, #171): Ein leeres
/// Feld druckt als Schreiblinie fester Länge, damit der Mandant auf dem Papier
/// ergänzen kann — statt einer Lücke, neben der die Kommas der Vorlage allein
/// stehen. Ohne Word: <see cref="VollmachtAuftrag.Platzhalter"/> ist der einzige
/// Weg für Druck, Öffnen und Vorschau.
/// </summary>
public sealed class VollmachtAuftragTests
{
    /// <summary>Die Zeile der Vorlagen, in der Name und Anschrift stehen.</summary>
    private const string Kopfzeile =
        "Hiermit erteile ich, {{MandantVorname}} {{MandantNachname}}, {{MandantStrasse}}, {{MandantPlz}} {{MandantOrt}}";

    private static VollmachtAuftrag Gefuellt() => new()
    {
        Art = VollmachtArt.Unfallsachen,
        MandantVorname = "Anna",
        MandantNachname = "Mustermann",
        MandantStrasse = "Musterweg 4",
        MandantPlz = "12345",
        MandantOrt = "Musterstadt",
        MandantTelefon = "0170 1234567",
        MandantEmail = "anna@example.org",
        Unfalldatum = "02.08.2026",
        InSachen = "Bußgeldsache Anna Mustermann",
        Wegen = "Schadensersatz nach Verkehrsunfall vom 02.08.2026",
    };

    private static string Linie(int laenge) => new('_', laenge);

    /// <summary>Setzt die Werte in die Kopfzeile ein, wie der Ausfüller es tut.</summary>
    private static string Fuelle(string vorlage, IReadOnlyDictionary<string, string> werte) =>
        werte.Aggregate(vorlage, (text, wert) => text.Replace($"{{{{{wert.Key}}}}}", wert.Value));

    [Fact]
    public void Gefuellte_Werte_kommen_unveraendert_und_ohne_Rand_an()
    {
        var auftrag = Gefuellt() with { MandantVorname = "  Anna ", MandantOrt = "Musterstadt\t" };

        var werte = auftrag.Platzhalter();

        werte["MandantVorname"].Should().Be("Anna");
        werte["MandantNachname"].Should().Be("Mustermann");
        werte["MandantName"].Should().Be("Anna Mustermann");
        werte["MandantStrasse"].Should().Be("Musterweg 4");
        werte["MandantPlz"].Should().Be("12345");
        werte["MandantOrt"].Should().Be("Musterstadt");
        werte["MandantAnschrift"].Should().Be("Musterweg 4, 12345 Musterstadt");
        werte["MandantTelefon"].Should().Be("0170 1234567");
        werte["MandantEmail"].Should().Be("anna@example.org");
        werte["Unfalldatum"].Should().Be("02.08.2026");
        werte["InSachen"].Should().Be("Bußgeldsache Anna Mustermann");
        werte["Wegen"].Should().Be("Schadensersatz nach Verkehrsunfall vom 02.08.2026");
        werte.Values.Should().NotContain(wert => wert.Contains('_'), "kein Feld ist leer");
    }

    /// <summary>
    /// Jedes leere Feld bekommt seine eigene Länge. Ein Wert nur aus
    /// Leerzeichen gilt als leer — auf dem Papier wäre er unsichtbar.
    /// </summary>
    [Theory]
    [InlineData("MandantVorname", 14)]
    [InlineData("MandantNachname", 18)]
    [InlineData("MandantStrasse", 26)]
    [InlineData("MandantPlz", 9)]
    [InlineData("MandantOrt", 18)]
    [InlineData("MandantTelefon", 24)]
    [InlineData("MandantEmail", 28)]
    [InlineData("Unfalldatum", 12)]
    public void Ein_leeres_Feld_wird_zur_Linie_seiner_Laenge(string platzhalter, int laenge)
    {
        var auftrag = Leere(Gefuellt(), platzhalter, "   ");

        var werte = auftrag.Platzhalter();

        werte[platzhalter].Should().Be(Linie(laenge));
        werte.Where(wert => wert.Key != platzhalter && wert.Key is not ("MandantName" or "MandantAnschrift"))
            .Should().OnlyContain(wert => !wert.Value.Contains('_'), "nur das leere Feld wird zur Linie");
    }

    /// <summary>
    /// Ohne jeden Namen eine einzige lange Linie im Nachnamen statt zweier
    /// kurzer — der Mandant schreibt seinen Namen in einem Zug. Der Vorname
    /// bleibt leer; das doppelte Leerzeichen davor bleibt bewusst stehen (siehe
    /// <see cref="VollmachtAuftrag"/>).
    /// </summary>
    [Fact]
    public void Ein_ganz_leerer_Name_ist_eine_einzige_lange_Linie()
    {
        var auftrag = Gefuellt() with { MandantVorname = "", MandantNachname = "  " };

        var werte = auftrag.Platzhalter();

        werte["MandantVorname"].Should().BeEmpty();
        werte["MandantNachname"].Should().Be(Linie(32));
        werte["MandantName"].Should().Be(Linie(32), "ohne Leerzeichen vor der Linie");
        Fuelle(Kopfzeile, werte).Should().Be(
            $"Hiermit erteile ich,  {Linie(32)}, Musterweg 4, 12345 Musterstadt");
    }

    [Fact]
    public void Fehlt_nur_ein_Namensteil_steht_seine_Linie_im_Namen()
    {
        var ohneVorname = (Gefuellt() with { MandantVorname = "" }).Platzhalter();
        var ohneNachname = (Gefuellt() with { MandantNachname = "" }).Platzhalter();

        ohneVorname["MandantName"].Should().Be($"{Linie(14)} Mustermann");
        ohneNachname["MandantName"].Should().Be($"Anna {Linie(18)}");
    }

    /// <summary>
    /// <c>MandantAnschrift</c> zeigt dasselbe wie eine Vorlage mit den
    /// Einzelplatzhaltern: Straße, Komma, PLZ und Ort — mit Linien, wo etwas
    /// fehlt. Früher fiel ein leerer Teil samt Komma weg; jetzt gibt es keinen
    /// leeren Teil mehr, also auch kein allein hängendes Komma.
    /// </summary>
    [Fact]
    public void Die_Anschrift_entsteht_aus_den_Teilen_samt_Linien()
    {
        var ohneStrasse = (Gefuellt() with { MandantStrasse = "" }).Platzhalter();
        var ohneAlles = (Gefuellt() with { MandantStrasse = "", MandantPlz = "", MandantOrt = "" }).Platzhalter();

        ohneStrasse["MandantAnschrift"].Should().Be($"{Linie(26)}, 12345 Musterstadt");
        ohneAlles["MandantAnschrift"].Should().Be($"{Linie(26)}, {Linie(9)} {Linie(18)}");
    }

    /// <summary>
    /// „in Sachen" und „wegen" sind Freitext, den das Frontend je Art
    /// vorbelegt. Bei Unfall- und Strafsachen ist „in Sachen" absichtlich
    /// leer — eine Linie dort sähe aus wie eine vergessene Angabe.
    /// </summary>
    [Fact]
    public void In_Sachen_und_wegen_bleiben_leer()
    {
        var werte = (Gefuellt() with { InSachen = "", Wegen = "  " }).Platzhalter();

        werte["InSachen"].Should().BeEmpty();
        werte["Wegen"].Should().BeEmpty();
    }

    /// <summary>
    /// Der Fall aus dem Issue: Ohne Mandant druckte die App „Hiermit erteile
    /// ich, , ,". Jetzt steht an jeder Stelle eine Linie.
    /// </summary>
    [Fact]
    public void Ohne_Mandant_haengt_kein_Komma_allein()
    {
        var werte = new VollmachtAuftrag { Art = VollmachtArt.Strafsache }.Platzhalter();

        var zeile = Fuelle(Kopfzeile, werte);

        zeile.Should().Be($"Hiermit erteile ich,  {Linie(32)}, {Linie(26)}, {Linie(9)} {Linie(18)}");
        zeile.Should().NotContain(", ,");
        werte["MandantName"].Should().Be(Linie(32));
        werte["MandantAnschrift"].Should().Be($"{Linie(26)}, {Linie(9)} {Linie(18)}");
    }

    /// <summary>Der Auftrag mit einem Feld auf <paramref name="wert"/> gesetzt.</summary>
    private static VollmachtAuftrag Leere(VollmachtAuftrag auftrag, string platzhalter, string wert) =>
        platzhalter switch
        {
            "MandantVorname" => auftrag with { MandantVorname = wert },
            "MandantNachname" => auftrag with { MandantNachname = wert },
            "MandantStrasse" => auftrag with { MandantStrasse = wert },
            "MandantPlz" => auftrag with { MandantPlz = wert },
            "MandantOrt" => auftrag with { MandantOrt = wert },
            "MandantTelefon" => auftrag with { MandantTelefon = wert },
            "MandantEmail" => auftrag with { MandantEmail = wert },
            "Unfalldatum" => auftrag with { Unfalldatum = wert },
            _ => throw new ArgumentOutOfRangeException(nameof(platzhalter), platzhalter, null),
        };
}
