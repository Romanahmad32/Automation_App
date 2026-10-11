namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>
/// Was auf eine Vollmacht kommt (§4.11): die vom Anwalt im Dialog geprüften
/// Kopfdaten. Das Frontend belegt sie vor, der Dienst setzt sie ein — er
/// ergänzt nichts aus dem Register, damit auf dem Papier steht, was im Dialog
/// stand. Ergänzt wird nur, wo nichts stand: Ein leeres Feld druckt als
/// <see cref="VollmachtSchreiblinie"/>, damit der Mandant es von Hand ausfüllen
/// kann (#171). Der Dialog sagt das unter jedem solchen Feld.
///
/// Die Bankverbindung fehlt mit Absicht: Sie bleibt auf dem Papier für die
/// Hand des Mandanten frei und wird nirgends gespeichert.
/// </summary>
public sealed record VollmachtAuftrag
{
    public required VollmachtArt Art { get; init; }

    /// <summary>Referenz des Vorgangs; bestimmt den Arbeitsordner der Datei.</summary>
    public string Referenz { get; init; } = string.Empty;

    public string MandantVorname { get; init; } = string.Empty;
    public string MandantNachname { get; init; } = string.Empty;
    public string MandantStrasse { get; init; } = string.Empty;
    public string MandantPlz { get; init; } = string.Empty;
    public string MandantOrt { get; init; } = string.Empty;
    public string MandantTelefon { get; init; } = string.Empty;
    public string MandantEmail { get; init; } = string.Empty;
    public string Unfalldatum { get; init; } = string.Empty;
    public string InSachen { get; init; } = string.Empty;
    public string Wegen { get; init; } = string.Empty;

    /// <summary>
    /// Die Werte je Platzhalter — der einzige Weg für Druck, „In Word öffnen"
    /// und Vorschau, damit alle drei dasselbe zeigen. Die Namen sind die des
    /// Platzhalterkatalogs der Anspruchsschreiben (<c>feld_datenquelle.dart</c>),
    /// damit eine Vorlage in beiden Welten gleich geschrieben wird; neu sind nur
    /// <c>InSachen</c> und <c>Wegen</c>. <c>MandantName</c> und
    /// <c>MandantAnschrift</c> kommen als Zusammensetzung dazu.
    ///
    /// Jeder Wert ohne Leerraum am Rand; ein leerer wird zur Schreiblinie, mit
    /// zwei Ausnahmen. <c>InSachen</c> und <c>Wegen</c> bleiben leer: Sie sind
    /// Freitext, den das Frontend je Art vorbelegt, und bei Unfall- und
    /// Strafsachen ist „in Sachen" absichtlich leer — eine Linie dort sähe aus
    /// wie eine vergessene Angabe. Und ein ganz leerer Name ist eine einzige
    /// Linie im Nachnamen (<see cref="VollmachtSchreiblinie.Name"/>), der
    /// Vorname bleibt leer.
    ///
    /// <c>MandantName</c> und <c>MandantAnschrift</c> entstehen aus den Teilen
    /// samt deren Linien, genau so, wie eine Vorlage mit den Einzelplatzhaltern
    /// sie zeigte („Vorname Nachname", „Straße, PLZ Ort"). Weil kein Teil mehr
    /// leer ist, hängt nie ein Komma allein.
    /// </summary>
    public IReadOnlyDictionary<string, string> Platzhalter()
    {
        var (vorname, nachname) = NameMitLinien();
        var strasse = VollmachtSchreiblinie.WertOderLinie(MandantStrasse, VollmachtSchreiblinie.Strasse);
        var plz = VollmachtSchreiblinie.WertOderLinie(MandantPlz, VollmachtSchreiblinie.Plz);
        var ort = VollmachtSchreiblinie.WertOderLinie(MandantOrt, VollmachtSchreiblinie.Ort);

        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["MandantVorname"] = vorname,
            ["MandantNachname"] = nachname,
            // Trim nur für den ganz leeren Namen: Dort ist der Vorname leer,
            // und vor der Linie stünde sonst ein Leerzeichen.
            ["MandantName"] = $"{vorname} {nachname}".Trim(),
            ["MandantStrasse"] = strasse,
            ["MandantPlz"] = plz,
            ["MandantOrt"] = ort,
            ["MandantAnschrift"] = $"{strasse}, {plz} {ort}",
            ["MandantTelefon"] = VollmachtSchreiblinie.WertOderLinie(MandantTelefon, VollmachtSchreiblinie.Telefon),
            ["MandantEmail"] = VollmachtSchreiblinie.WertOderLinie(MandantEmail, VollmachtSchreiblinie.Email),
            ["Unfalldatum"] = VollmachtSchreiblinie.WertOderLinie(Unfalldatum, VollmachtSchreiblinie.Datum),
            ["InSachen"] = InSachen.Trim(),
            ["Wegen"] = Wegen.Trim(),
        };
    }

    /// <summary>
    /// Vor- und Nachname, ein leerer Teil als Linie. Fehlen beide, steht eine
    /// einzige lange Linie im Nachnamen.
    ///
    /// Die Vorlagen schreiben „ich, {{MandantVorname}} {{MandantNachname}},";
    /// beim ganz leeren Namen bleibt so vor der Linie ein doppeltes
    /// Leerzeichen stehen. Das bleibt so: Auf Papier und Vorschau rückt es die
    /// Linie nur um eine Leerzeichenbreite ein. Stünde die Linie dagegen im
    /// Vornamen, folgte ihr ein Leerzeichen vor dem Komma — ein sichtbarer
    /// Satzfehler. Wegschneiden ließe sich das Leerzeichen nur in der Vorlage
    /// oder im gemeinsamen Ausfüller, und beide bleiben unverändert.
    /// </summary>
    private (string Vorname, string Nachname) NameMitLinien()
    {
        if (MandantVorname.Trim().Length == 0 && MandantNachname.Trim().Length == 0)
        {
            return (string.Empty, VollmachtSchreiblinie.Linie(VollmachtSchreiblinie.Name));
        }

        return (
            VollmachtSchreiblinie.WertOderLinie(MandantVorname, VollmachtSchreiblinie.Vorname),
            VollmachtSchreiblinie.WertOderLinie(MandantNachname, VollmachtSchreiblinie.Nachname));
    }
}
