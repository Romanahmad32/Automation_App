using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Begrenzt die Laenge handgeschriebener C#-Dateien.
///
/// Gemessen wird an <see cref="Quelldatei.Anweisungszeilen"/>, nicht an rohen
/// Zeilen: Kommentare und Leerzeilen zaehlen nicht mit. Das ist eine bewusste
/// Korrektur der frueheren Fassung ("Richtwert 250, hart 300", roh gezaehlt).
/// Die zaehlte das Erklaeren als Kosten -- ausgerechnet in einer Codebasis,
/// deren groesster Vorteil ist, dass ihre Kommentare das *Warum* festhalten.
/// Praktisch fuehrte sie dazu, dass jemand eine Datei aufteilte, um ein paar
/// Zeilen *hinzufuegen* zu koennen: der Schnitt kam dann aus der Zaehlung,
/// nicht aus dem Entwurf. Bei der Umstellung lag keine einzige Datei ueber 250
/// Anweisungszeilen (groesste: 198) -- die Regel wird also schaerfer, nicht
/// weicher: eine harte Zahl statt eines Richtwerts mit Dauerausnahme.
///
/// Die zweite Grenze faengt, was die erste durchliesse: eine Datei aus tausend
/// Zeilen Kommentar ist trotzdem nichts, was man ueberblickt.
///
/// Kommt je eine begruendete Ausnahme dazu, gehoert sie namentlich hierher --
/// mit ihrer damaligen Laenge als Obergrenze, damit sie nur noch schrumpfen
/// kann -- und nicht als hochgesetztes Limit. Auf der Dart-Seite gilt dieselbe
/// Regel mit denselben Zahlen (file_length_test.dart).
/// </summary>
public class DateilaengeTests
{
    const int MaxAnweisungszeilen = 250;
    const int MaxRohzeilen = 450;

    [Fact]
    public void Keine_Datei_ueberschreitet_250_Anweisungszeilen()
    {
        var verstoesse = CsQuelldateien.Alle()
            .Where(datei => datei.Anweisungszeilen > MaxAnweisungszeilen)
            .Select(datei => $"{datei.RelativerPfad} ({datei.Anweisungszeilen} Anweisungszeilen)")
            .ToList();

        verstoesse.Should().BeEmpty(
            $"eine Datei soll hoechstens {MaxAnweisungszeilen} Zeilen Code tragen " +
            "(Kommentare und Leerzeilen zaehlen nicht mit). Was darueber liegt, " +
            "gehoert in eigenstaendige Klassen aufgeteilt -- nicht in weniger Kommentare");
    }

    [Fact]
    public void Keine_Datei_ueberschreitet_450_Zeilen_insgesamt()
    {
        var verstoesse = CsQuelldateien.Alle()
            .Where(datei => datei.Zeilenzahl > MaxRohzeilen)
            .Select(datei => $"{datei.RelativerPfad} ({datei.Zeilenzahl} Zeilen)")
            .ToList();

        verstoesse.Should().BeEmpty(
            $"auch mit vielen Kommentaren bleibt eine Datei unter {MaxRohzeilen} Zeilen. " +
            "Wird sie laenger, ist nicht der Kommentar zu viel, sondern der Gegenstand zu gross");
    }
}
