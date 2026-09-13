namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>
/// Was auf eine Vollmacht kommt (§4.11): die vom Anwalt im Dialog geprüften
/// Kopfdaten. Das Frontend belegt sie vor, der Dienst setzt sie nur ein — er
/// ergänzt nichts aus dem Register, damit auf dem Papier genau steht, was im
/// Dialog stand.
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
    /// Die Werte je Platzhalter. Die Namen sind die des Platzhalterkatalogs der
    /// Anspruchsschreiben (<c>feld_datenquelle.dart</c>), damit eine Vorlage in
    /// beiden Welten gleich geschrieben wird; neu sind nur <c>InSachen</c> und
    /// <c>Wegen</c>. <c>MandantName</c> und <c>MandantAnschrift</c> kommen als
    /// Zusammensetzung dazu, weil die Kanzleivorlagen Name und Anschrift in
    /// einer Zeile führen.
    /// </summary>
    public IReadOnlyDictionary<string, string> Platzhalter()
    {
        var plzOrt = $"{MandantPlz.Trim()} {MandantOrt.Trim()}".Trim();
        var anschrift = string.Join(
            ", ",
            new[] { MandantStrasse.Trim(), plzOrt }.Where(teil => teil.Length > 0));

        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["MandantVorname"] = MandantVorname.Trim(),
            ["MandantNachname"] = MandantNachname.Trim(),
            ["MandantName"] = $"{MandantVorname.Trim()} {MandantNachname.Trim()}".Trim(),
            ["MandantStrasse"] = MandantStrasse.Trim(),
            ["MandantPlz"] = MandantPlz.Trim(),
            ["MandantOrt"] = MandantOrt.Trim(),
            ["MandantAnschrift"] = anschrift,
            ["MandantTelefon"] = MandantTelefon.Trim(),
            ["MandantEmail"] = MandantEmail.Trim(),
            ["Unfalldatum"] = Unfalldatum.Trim(),
            ["InSachen"] = InSachen.Trim(),
            ["Wegen"] = Wegen.Trim(),
        };
    }
}
