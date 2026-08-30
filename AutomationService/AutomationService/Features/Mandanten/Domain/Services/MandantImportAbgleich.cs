using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Gleicht einen Datei-Eintrag gegen einen vorhandenen Mandanten ab.
///
/// Die Regel ist überall dieselbe und bewusst einseitig: <b>ergänzen, nie
/// überschreiben</b>. Ein leeres Feld im Register wird aus der Datei gefüllt,
/// ein belegtes bleibt stehen — und wenn die Datei etwas anderes behauptet,
/// steht das als Hinweis in der Vorschau, statt still zu gewinnen. Die Datei
/// entsteht maschinell aus Aktentexten; sie darf Lücken schließen, aber nicht
/// gepflegte Stammdaten durch eine Lesart aus einem alten Schreiben ersetzen.
/// Nur so ist ein zweiter Lauf derselben Datei harmlos.
/// </summary>
public static class MandantImportAbgleich
{
    /// <summary>
    /// Übernimmt, was übernehmbar ist, und hängt jede Abweichung an
    /// <paramref name="hinweise"/>. true, wenn sich am Mandanten etwas geändert hat.
    /// </summary>
    /// <param name="ziel">Der vorhandene Mandant, der ergänzt wird.</param>
    /// <param name="quelle">Die Zeile der Importdatei.</param>
    /// <param name="hinweise">Sammelt, was nicht übernommen wurde.</param>
    /// <param name="woher">
    /// Woher der stehenbleibende Wert stammt — „Register" oder „frühere Zeile".
    /// Ein Mandant kann in derselben Datei zweimal vorkommen; dann widerspricht
    /// die Datei sich selbst, und „Register" wäre schlicht falsch.
    /// </param>
    public static bool Uebernimm(
        MandantEntity ziel,
        ImportMandant quelle,
        List<string> hinweise,
        string woher = "Register")
    {
        var geaendert = false;
        foreach (var feld in Felder(ziel, quelle))
        {
            geaendert |= Fuelle(feld, hinweise, woher);
        }

        return UebernimmKennzeichen(ziel, quelle) || geaendert;
    }

    /// <summary>Ein abzugleichendes Feld: Anzeigename, beide Werte, und wohin der neue gehört.</summary>
    sealed record Feld(string Name, string Alt, string Neu, Action<string> Setze);

    static IEnumerable<Feld> Felder(MandantEntity z, ImportMandant q) =>
    [
        // „keine" ist die Nicht-Angabe der Anrede und zählt hier als leer,
        // sonst gälte jede erkannte Anrede als Widerspruch zum Vorbelegten.
        new("Anrede", OhneKeine(z.Anrede), OhneKeine(q.Anrede), w => z.Anrede = w),
        new("Anschrift", z.StrasseHausnummer, q.StrasseHausnummer, w => z.StrasseHausnummer = w),
        new("Postleitzahl", z.Postleitzahl, q.Postleitzahl, w => z.Postleitzahl = w),
        new("Ort", z.Ort, q.Ort, w => z.Ort = w),
        new("E-Mail", z.EmailAdresse, q.EmailAdresse, w => z.EmailAdresse = w),
        new("Telefon", z.Telefonnummer, q.Telefonnummer, w => z.Telefonnummer = w),
        new("Notiz", z.Notiz, q.Notiz, w => z.Notiz = w),
    ];

    static string OhneKeine(string? anrede) =>
        string.Equals(anrede?.Trim(), "keine", StringComparison.OrdinalIgnoreCase)
            ? string.Empty
            : anrede ?? string.Empty;

    static bool Fuelle(Feld feld, List<string> hinweise, string woher)
    {
        var neu = feld.Neu.Trim();
        if (neu.Length == 0) return false;

        var alt = feld.Alt.Trim();
        if (alt.Length == 0)
        {
            feld.Setze(neu);
            return true;
        }

        if (string.Equals(alt, neu, StringComparison.OrdinalIgnoreCase)) return false;

        hinweise.Add($"{feld.Name} weicht ab ({woher}: „{alt}“, Datei: „{neu}“) — nicht geändert.");
        return false;
    }

    /// <summary>
    /// Kennzeichen sind eine Menge, kein Feld: ein Mandant kann mehrere Fahrzeuge
    /// halten, also kommt hinzu, was fehlt, und nichts fällt weg.
    /// </summary>
    static bool UebernimmKennzeichen(MandantEntity ziel, ImportMandant quelle)
    {
        var vorhanden = MandantListen.Lies(ziel.KennzeichenJson);
        var bekannt = new HashSet<string>(vorhanden, StringComparer.OrdinalIgnoreCase);

        var neue = quelle.Kennzeichen
            .Select(k => k.Trim())
            .Where(k => k.Length > 0 && bekannt.Add(k))
            .ToList();

        if (neue.Count == 0) return false;

        ziel.KennzeichenJson = MandantListen.Schreib(vorhanden.Concat(neue));
        return true;
    }
}
