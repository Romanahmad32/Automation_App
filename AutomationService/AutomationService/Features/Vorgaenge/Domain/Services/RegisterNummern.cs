namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Die Nummernvergabe eines Jahrgangs (§6.3): der Vorschlag für die nächste
/// laufende Nummer und die im Jahrgang schon belegten — quellenübergreifend
/// über die Vorgänge der App <b>und</b> die übernommene Registerhistorie.
///
/// Reine Funktion auf den bereits gemischten <see cref="RegisterZeile"/>,
/// genau wie <see cref="RegisterZeilenBau"/>: Beide Quellen liegen darin schon
/// zusammen, die Rechnung braucht deshalb weder Datenbank noch eine eigene
/// Abfrage je Quelle und lässt sich ohne beides prüfen.
/// </summary>
public static class RegisterNummern
{
    /// <summary>
    /// Der Nummernstand des Jahrgangs <paramref name="jahr"/> innerhalb
    /// <paramref name="zeilen"/> — andere Jahrgänge in derselben Liste bleiben
    /// unberücksichtigt, die Aufrufstelle darf also gemischt übergeben.
    ///
    /// Vorgeschlagen wird die höchste belegte Nummer <b>+ 1</b>, nie die
    /// kleinste freie: Eine Lücke im Bestand bleibt Lücke (§6.3) und wird nur
    /// als solche gemeldet (siehe 6.2 „Stand je Jahrgang"), nicht
    /// stillschweigend wieder aufgefüllt. Zeilen ohne laufende Nummer — ein
    /// noch nicht abgeschlossener Vorgang kann eine haben oder nicht — zählen
    /// deshalb nicht als belegte <c>0</c>, sondern werden übersprungen. Eine
    /// doppelt vergebene Nummer (der gewachsene Bestand kennt solche, siehe
    /// 6.2) steht in <see cref="RegisterNummernStand.Belegte"/> trotzdem nur
    /// einmal.
    /// </summary>
    public static RegisterNummernStand Stand(IReadOnlyList<RegisterZeile> zeilen, string jahr)
    {
        ArgumentNullException.ThrowIfNull(zeilen);
        ArgumentNullException.ThrowIfNull(jahr);

        var belegte = zeilen
            .Where(zeile => string.Equals(zeile.Jahr, jahr, StringComparison.Ordinal))
            .Select(zeile => zeile.LaufendeNummer)
            .OfType<int>()
            .Distinct()
            .Order()
            .ToList();

        var hoechste = belegte.Count == 0 ? 0 : belegte[^1];
        return new RegisterNummernStand(jahr, hoechste, hoechste + 1, belegte);
    }
}
