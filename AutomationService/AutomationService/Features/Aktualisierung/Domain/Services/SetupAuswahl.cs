using System.Globalization;
using System.Text.RegularExpressions;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Sucht im neuesten Release die Setup-Datei heraus (#196). Streng, weil der
/// Dienst die Datei anschließend ausführt: nur der genaue Name
/// <c>Automation_App_Setup_&lt;x.y.z&gt;.exe</c>, nur mit der Version des Tags,
/// nur mit Größe und <c>sha256</c>-Prüfsumme aus der API. Eine weitere Datei
/// am Release (Prüfsummenliste, ZIP, <c>….exe.sig</c>) wird nie genommen, eine
/// Setup-Datei einer anderen Version auch nicht.
/// </summary>
public static partial class SetupAuswahl
{
    private const string DigestPraefix = "sha256:";

    /// <summary>
    /// <c>^Automation_App_Setup_\d+\.\d+\.\d+\.exe$</c>, mit <c>\z</c> statt <c>$</c>:
    /// In .NET ließe <c>$</c> noch ein abschließendes <c>\n</c> zu. Ziffern außerhalb
    /// von 0–9, die <c>\d</c> auch nimmt, scheitern danach an <see cref="Versionsnummer.Lies"/>.
    /// </summary>
    [GeneratedRegex(@"^Automation_App_Setup_(\d+\.\d+\.\d+)\.exe\z", RegexOptions.CultureInvariant)]
    public static partial Regex DateinameMuster();

    public static SetupAuswahlErgebnis Waehle(ReleaseBeschreibung release, string laufendeVersion)
    {
        ArgumentNullException.ThrowIfNull(release);

        var neu = Versionsnummer.Lies(release.TagName);
        var laufend = Versionsnummer.Lies(laufendeVersion);
        if (neu is null || laufend is null || !neu.IstHoeherAls(laufend))
        {
            return SetupAuswahlErgebnis.KeinUpdate;
        }

        var passend = (release.Assets ?? [])
            .Where(datei => PasstZu(datei, neu))
            .ToList();

        // Mehrere Treffer sind nur über Schreibweisen wie „01.3.0" möglich —
        // welcher davon gemeint ist, rät der Dienst nicht.
        if (passend.Count != 1 || Adresse(passend[0].BrowserDownloadUrl) is not { } adresse)
        {
            return new SetupAuswahlErgebnis(AuswahlArt.OhneSetup, neu, null, null);
        }

        var datei = passend[0];
        if (datei.Size is not > 0 || Sha256AusDigest(datei.Digest) is not { } sha256)
        {
            return new SetupAuswahlErgebnis(AuswahlArt.OhnePruefsumme, neu, null, FuerDenBrowser(adresse));
        }

        return new SetupAuswahlErgebnis(
            AuswahlArt.Verfuegbar,
            neu,
            new SetupDatei(neu, adresse, datei.Size.Value, sha256),
            FuerDenBrowser(adresse));
    }

    /// <summary>
    /// Die Adresse für „Lieber selbst herunterladen" (<c>downloadUrl</c>) — nur
    /// <c>https://github.com/…</c>, sonst <c>null</c>. Das Frontend reicht sie an
    /// den Browser weiter, und was dort ankommt, soll nicht davon abhängen, was
    /// eine API-Antwort oder eine umgestellte <c>Aktualisierung:Quelle</c>
    /// hineinschreibt; das Frontend prüft dasselbe noch einmal
    /// (<c>BrowserOeffner.istErlaubt</c>). Laden darf der Dienst die Datei
    /// trotzdem auch von anderswo — er prüft Größe und SHA256 selbst.
    /// </summary>
    public static string? FuerDenBrowser(Uri adresse)
    {
        ArgumentNullException.ThrowIfNull(adresse);
        return adresse.Scheme == Uri.UriSchemeHttps
            && string.Equals(adresse.Host, "github.com", StringComparison.OrdinalIgnoreCase)
            && adresse.IsDefaultPort
            && adresse.UserInfo.Length == 0
                ? adresse.AbsoluteUri
                : null;
    }

    /// <summary><c>sha256:&lt;64 hex&gt;</c> → das Hex kleingeschrieben; alles andere → <c>null</c>.</summary>
    public static string? Sha256AusDigest(string? digest)
    {
        if (digest is null || !digest.StartsWith(DigestPraefix, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var hex = digest[DigestPraefix.Length..];
        return hex.Length == 64 && hex.All(Uri.IsHexDigit)
            ? hex.ToLower(CultureInfo.InvariantCulture)
            : null;
    }

    private static bool PasstZu(ReleaseDatei datei, Versionsnummer version) =>
        datei.Name is { } name
        && DateinameMuster().Match(name) is { Success: true } treffer
        && Versionsnummer.Lies(treffer.Groups[1].Value) == version;

    /// <summary>Nur eine absolute http(s)-Adresse — ein <c>file:</c> oder Relatives lädt der Dienst nicht.</summary>
    private static Uri? Adresse(string? text) =>
        Uri.TryCreate(text, UriKind.Absolute, out var adresse)
        && (adresse.Scheme == Uri.UriSchemeHttps || adresse.Scheme == Uri.UriSchemeHttp)
            ? adresse
            : null;
}
