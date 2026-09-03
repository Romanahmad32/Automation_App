using System.Globalization;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Core.ErrorHandling;

/// <summary>
/// Sorgt dafuer, dass eine verletzte DTO-Schranke beim Anwalt als deutscher Satz
/// ankommt und nicht als Achselzucken.
///
/// <c>[ApiController]</c> beantwortet ein ungueltiges Modell selbst, noch bevor
/// die Action laeuft — mit <see cref="ValidationProblemDetails"/>. Deren
/// Meldungen stehen ausschliesslich in <c>errors</c>, je Feld; <c>detail</c>
/// bleibt leer und <c>title</c> traegt das englische "One or more validation
/// errors occurred.". Genau das las die Oberflaeche bisher vor
/// (<c>backendFehlertext</c> nimmt detail, dann title, dann message) — welches
/// Feld klemmt, erfuhr der Anwalt nie.
///
/// Diese eine Stelle fuellt <c>detail</c> aus den Feldmeldungen und setzt einen
/// deutschen Titel; die Form bleibt RFC 7807 wie bei
/// <see cref="FachExceptionHandler"/>. Weil sie am Filter haengt und nicht an
/// einer Action, gilt sie fuer jeden Controller — auch fuer die, deren DTOs
/// erst spaeter Schranken bekommen. Die Texte selbst stehen an den Attributen
/// (<see cref="Validierungstexte"/>), die Bindungsmeldungen des Rahmenwerks
/// setzt <see cref="DeutscheBindungstexte"/>.
///
/// Der andere Weg ist bewusst nicht gegangen (#53): den Filter abzuschalten
/// (<c>SuppressModelStateInvalidFilter</c>), um in jeder Action ein eigenes
/// "errorCode"-DTO zu bauen, nimmt allen Controllern die automatische Pruefung
/// ab — auch denen, die ModelState nie selbst ansehen.
/// </summary>
public static class ValidierungsAntwort
{
    // Eine Schadensaufstellung darf 100 Positionen tragen (DamageListingDto.Items),
    // jede mit zwei Schranken. Ohne Deckel entstuende daraus ein Fliesstext aus
    // zweihundert Meldungen — in einer Snackbar unlesbar und im Log nur Ballast.
    private const int MaxMeldungen = 5;

    public static IServiceCollection AddValidierungsAntwort(this IServiceCollection services)
    {
        services.Configure<MvcOptions>(DeutscheBindungstexte.Setzen);

        services.Configure<ApiBehaviorOptions>(options =>
        {
            var standard = options.InvalidModelStateResponseFactory;
            options.InvalidModelStateResponseFactory = context =>
            {
                var antwort = standard(context);
                if (antwort is ObjectResult { Value: ValidationProblemDetails problem })
                {
                    var meldung = Zusammengefasst(problem.Errors);
                    problem.Title = "Ungültige Anfrage";
                    if (meldung.Length > 0)
                    {
                        problem.Detail = meldung;
                    }
                }

                return antwort;
            };
        });

        return services;
    }

    /// <summary>
    /// Die Meldungen nennen ihr Feld selbst (<c>[Display]</c> an den DTOs), der
    /// Schluessel aus ModelState taucht deshalb nicht auf — "TemplateFilePath"
    /// oder "DamageListing.Items[0].Amount" ist kein Begriff des Anwalts. Nur
    /// die laufende Nummer aus einem Listenschluessel bleibt erhalten: bei einer
    /// Schadensaufstellung ist sie das Einzige, was die gemeinte Zeile findet.
    /// </summary>
    private static string Zusammengefasst(IDictionary<string, string[]> fehler)
    {
        var unlesbar = fehler.Keys.Where(schluessel => schluessel.StartsWith('$')).ToList();
        if (unlesbar.Count > 0)
        {
            return Lesefehler(unlesbar);
        }

        var meldungen = fehler
            .SelectMany(eintrag => eintrag.Value
                .Where(text => !IstRumpfParameter(eintrag.Key, text))
                .Select(text => MitPosition(eintrag.Key, text)))
            .ToList();

        var gezeigt = string.Join(" | ", meldungen.Take(MaxMeldungen));
        return meldungen.Count <= MaxMeldungen
            ? gezeigt
            : $"{gezeigt} (… und {meldungen.Count - MaxMeldungen} weitere)";
    }

    /// <summary>
    /// Schluessel, die mit <c>$</c> beginnen, kommen nicht von einer Schranke,
    /// sondern vom JSON-Leser: Die Nachricht selbst ist kaputt oder ein Feld hat
    /// einen Wert der falschen Art. Deren Meldungen sind englisch und tragen
    /// Zeilen- und Byte-Nummern — nichts davon hilft dem Anwalt, und beheben kann
    /// er es ohnehin nicht: Den Rumpf baut die App, nicht er. Also ein Satz statt
    /// des Innenlebens. Die uebrigen Eintraege fallen mit weg; sie sind Folge
    /// desselben Lesefehlers (das Modell blieb leer) und nicht ein zweiter Befund.
    /// </summary>
    private static string Lesefehler(List<string> schluessel)
    {
        var felder = schluessel
            .Select(s => s.TrimStart('$', '.'))
            .Where(s => s.Length > 0)
            .ToList();

        var wo = felder.Count == 0 ? string.Empty : $" (betroffen: {string.Join(", ", felder)})";
        return $"Die Anfrage konnte nicht gelesen werden{wo}. Das ist ein Fehler im Programm " +
               "und keine falsche Eingabe — bitte melden Sie ihn.";
    }

    /// <summary>
    /// Die einzige englische Meldung, die uebrig bliebe: <c>[ApiController]</c> haengt
    /// an einen nicht-nullbaren <c>[FromBody]</c>-Parameter ein stillschweigendes
    /// <c>[Required]</c>, und dessen Text ist der Vorgabetext des Rahmenwerks — ein
    /// <c>ErrorMessage</c> laesst sich daran nicht setzen. Sie steht immer neben der
    /// eigentlichen Meldung ("Die Anfrage kam ohne Inhalt an.") und sagt nichts, was
    /// die nicht schon sagt.
    ///
    /// Bewusst nicht ueber <c>SuppressImplicitRequiredAttributeForNonNullableReferenceTypes</c>
    /// abgeschaltet: der Schalter gilt fuer jede nicht-nullbare Eigenschaft jedes DTOs
    /// und wuerde die Pruefung lockern statt nur die Anzeige.
    /// </summary>
    private static bool IstRumpfParameter(string schluessel, string text) =>
        text == $"The {schluessel} field is required.";

    /// <summary>"DamageListing.Items[2].Amount" wird zu "Position 3: …".</summary>
    private static string MitPosition(string schluessel, string meldung)
    {
        var offen = schluessel.IndexOf('[', StringComparison.Ordinal);
        var zu = offen < 0 ? -1 : schluessel.IndexOf(']', offen);
        if (offen < 0 || zu <= offen)
        {
            return meldung;
        }

        var ziffern = schluessel.AsSpan(offen + 1, zu - offen - 1);
        return int.TryParse(ziffern, CultureInfo.InvariantCulture, out var index)
            ? $"Position {index + 1}: {meldung}"
            : meldung;
    }
}
