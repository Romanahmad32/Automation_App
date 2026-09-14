using System.Text.RegularExpressions;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Entschärft die HTML-Fassung einer fremden Nachricht, <b>bevor</b> sie den
/// Dienst verlässt (§4.3).
///
/// Der Posteingang zeigt Post von Versicherern, Werkstätten und Unbekannten.
/// Zwei Dinge darf eine solche Nachricht in der Anwaltssoftware nicht können:
/// etwas ausführen und etwas nachladen. Das Erste ist offensichtlich; das
/// Zweite ist der Zählpixel — ein externes Bild meldet dem Absender Zeitpunkt
/// und IP-Adresse des Lesens, und in einer Kanzlei ist das eine Auskunft über
/// Mandatsarbeit, die niemand erteilt hat.
///
/// <b>Gefiltert wird hier und nicht im Frontend.</b> Was die Oberfläche gar
/// nicht erst bekommt, kann sie auch nicht versehentlich darstellen — und der
/// Filter gilt damit für jede künftige Ansicht, nicht nur für die heutige.
///
/// <b>Nicht</b> der <c>SignaturHtmlFilter</c> aus der Versand-Slice: Der nimmt
/// abgewählte Bilder aus der <em>eigenen</em> Signatur heraus, kennt also einen
/// ganz anderen Zweck — und ein Verweis dorthin verstieße gegen die
/// Schnittregel (<c>SliceIsolationTests</c>).
///
/// Eingebettete Bilder (<c>cid:</c>) fallen mit: Der Dienst liefert die
/// zugehörigen Teile nicht aus, und ein Verweis ins Leere zeigt beim Anwalt
/// nur ein Platzhalterkreuz.
/// </summary>
public static partial class PosteingangHtmlFilter
{
    /// <summary>Entfernt alles Aktive und jeden Verweis, der beim Anzeigen nachlädt.</summary>
    public static string FuerAnzeige(string html) => FuerAnzeigeMitErgebnis(html).Html;

    /// <summary>
    /// Wie <see cref="FuerAnzeige"/>, meldet aber zusätzlich, ob dabei etwas
    /// Nachladendes entfernt wurde — ein <c>&lt;base&gt;</c> eingeschlossen: Es
    /// lädt selbst nichts nach, biegt aber jeden folgenden relativen Verweis
    /// (<c>&lt;img src="bild.png"&gt;</c>) auf eine fremde Adresse um und ist
    /// damit derselbe Zählpixel, nur über einen Umweg. Die Oberfläche zeigt
    /// darüber den Hinweis „externe Bilder blockiert", ohne den Text nach der
    /// Marke <c>data-blockiert</c> absuchen zu müssen.
    /// </summary>
    public static PosteingangHtmlFilterErgebnis FuerAnzeigeMitErgebnis(string html)
    {
        if (string.IsNullOrEmpty(html))
        {
            return new PosteingangHtmlFilterErgebnis(html, false);
        }

        var gefiltert = AktiveBloecke().Replace(html, string.Empty);
        var bilderBlockiert = Basiselement().IsMatch(gefiltert);
        gefiltert = Basiselement().Replace(gefiltert, string.Empty);
        gefiltert = AktiveMarken().Replace(gefiltert, string.Empty);
        // Nur innerhalb einer Marke ersetzt, nicht über das ganze Dokument:
        // "Ereignisse" allein auf den Fließtext losgelassen träfe auch Wörter
        // wie "online" ("on" + Buchstaben) und risse "Abrechnung online = 1"
        // zu "Abrechnung" ab.
        gefiltert = Marke().Replace(gefiltert, treffer => Ereignisse().Replace(treffer.Value, string.Empty));

        bilderBlockiert |= NachladendeQuelle().IsMatch(gefiltert);
        // Das Element bleibt stehen und wird markiert: Die Oberfläche sagt dem
        // Anwalt dann, dass Bilder zurückgehalten wurden, statt ihn vor einer
        // lückenhaften Nachricht ohne Erklärung sitzen zu lassen.
        gefiltert = NachladendeQuelle().Replace(
            gefiltert, treffer => $" {treffer.Groups["attribut"].Value}=\"\" data-blockiert=\"1\"");

        bilderBlockiert |= NachladenderStil().IsMatch(gefiltert);
        gefiltert = NachladenderStil().Replace(gefiltert, "none");

        gefiltert = AktiverVerweis().Replace(gefiltert, " href=\"\"");
        return new PosteingangHtmlFilterErgebnis(gefiltert, bilderBlockiert);
    }

    /// <summary>Marken, deren <b>Inhalt</b> mit muss — sonst stünde der Skripttext als Fließtext da.</summary>
    [GeneratedRegex(@"<(script|style|iframe|object)\b[^>]*>.*?</\s*\1\s*>",
        RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex AktiveBloecke();

    /// <summary>
    /// Was übrig bleibt: unpaarige oder selbstschließende Marken derselben Art,
    /// dazu <c>&lt;embed&gt;</c>, <c>&lt;link&gt;</c> (lädt nach, gleich
    /// welches <c>rel</c> — Stylesheet, Preload, Icon …) und
    /// <c>&lt;meta http-equiv&gt;</c> (leitet weiter).
    /// </summary>
    [GeneratedRegex(@"</?\s*(?:script|style|iframe|object|embed|link)\b[^>]*>|<meta\b[^>]*http-equiv[^>]*>",
        RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex AktiveMarken();

    /// <summary>
    /// <c>&lt;base href&gt;</c> — setzt die Adresse, gegen die jeder folgende
    /// <b>relative</b> Verweis aufgelöst wird. Ohne dieses Element ist ein
    /// relativer Verweis harmlos (er zeigt auf die eigene, nicht auf eine
    /// fremde Adresse); mit ihm wird aus einem gewöhnlichen
    /// <c>&lt;img src="bild.png"&gt;</c> derselbe Zählpixel wie ein absoluter
    /// Verweis auf ein fremdes Bild — <see cref="NachladendeQuelle"/> allein
    /// sieht das nicht, weil <c>bild.png</c> selbst kein Protokoll trägt.
    /// </summary>
    [GeneratedRegex(@"<base\b[^>]*>", RegexOptions.IgnoreCase)]
    private static partial Regex Basiselement();

    /// <summary>
    /// Eine einzelne Marke von der öffnenden bis zur schließenden spitzen
    /// Klammer — der Rahmen, innerhalb dessen <see cref="Ereignisse"/> nach
    /// <c>on…</c>-Attributen sucht. Ohne diesen Rahmen träfe die Regel auch
    /// Fließtext (siehe dort).
    /// </summary>
    [GeneratedRegex(@"<[^>]*>")]
    private static partial Regex Marke();

    /// <summary>
    /// Jedes <c>on…="…"</c>-Attribut — der zweite Weg, Code auszuführen. Der
    /// Trenner davor ist <c>[\s/]+</c>, nicht nur Leerraum: HTML5 erlaubt einen
    /// Schrägstrich statt eines Leerzeichens zwischen Attributen
    /// (<c>&lt;img/onerror=…&gt;</c>), und genau das nutzte ein Testfall, um
    /// den Filter zu umgehen.
    /// </summary>
    [GeneratedRegex(@"[\s/]+on[a-zA-Z]+\s*=\s*(?:""[^""]*""|'[^']*'|[^\s>]+)", RegexOptions.IgnoreCase)]
    private static partial Regex Ereignisse();

    /// <summary>
    /// <c>src</c>, <c>background</c>, <c>srcset</c> (mehrere Quellen für ein
    /// responsives Bild), <c>poster</c> (Vorschaubild eines Videos) und
    /// <c>data</c> (bei <c>&lt;object&gt;</c>) — allesamt Attribute, die ins
    /// Netz oder auf einen eingebetteten Teil zeigen.
    ///
    /// Zwei Umgehungen extra abgefangen: <c>[\s/]+</c> statt nur Leerraum vor
    /// dem Attributnamen (HTML5 erlaubt <c>&lt;img/src="…"&gt;</c>), und
    /// <c>&amp;#</c> als eigene Quelle neben <c>https?:</c>, <c>//</c> und
    /// <c>cid:</c> — eine entitätskodierte Adresse wie
    /// <c>&amp;#104;ttps://…</c> beginnt mit keinem der drei Präfixe, ist aber
    /// nach der Dekodierung durch den Browser derselbe externe Verweis.
    /// </summary>
    [GeneratedRegex(
        @"[\s/]+(?<attribut>srcset|src|background|poster|data)\s*=\s*"
        + @"(?:(?<q>[""'])\s*(?:https?:|//|cid:|&#)[^""']*\k<q>|(?:https?:|//|cid:|&#)[^\s>]*)",
        RegexOptions.IgnoreCase)]
    private static partial Regex NachladendeQuelle();

    /// <summary>
    /// Dieselben Verweise, versteckt in einem <c>style</c>-Attribut oder
    /// -Block — <c>@import url(…)</c> eingeschlossen, das dieselbe
    /// Schreibweise benutzt. Ein <c>@import</c> ohne <c>url(…)</c>
    /// (<c>@import "…";</c>) ist nur innerhalb eines <c>&lt;style&gt;</c>-Blocks
    /// gültig, und der fällt bereits vollständig samt Inhalt.
    /// </summary>
    [GeneratedRegex(@"url\(\s*[""']?\s*(?:https?:|//|cid:)[^)]*\)", RegexOptions.IgnoreCase)]
    private static partial Regex NachladenderStil();

    /// <summary>Ein Verweis, der beim Anklicken Code ausführt statt zu einer Seite zu führen.</summary>
    [GeneratedRegex(@"\s+href\s*=\s*(?:(?<q>[""'])\s*javascript:[^""']*\k<q>|javascript:[^\s>]*)",
        RegexOptions.IgnoreCase)]
    private static partial Regex AktiverVerweis();
}
