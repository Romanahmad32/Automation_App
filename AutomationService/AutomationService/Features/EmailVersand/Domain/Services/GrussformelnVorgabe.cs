namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die Grüße, mit denen der Bestand ab Werk startet (§4.7, §7.1).
///
/// Es sind genau die beiden, die in der übernommenen Kanzlei-Mail vom
/// 25.08.2026 stehen (<c>Beispiele/E-Mail Vorlage Text für Mandanten.eml</c>);
/// dort standen sie zur Ansicht nebeneinander, in einer echten Mail steht
/// höchstens einer. Bewusst **keine** darüber hinausgehende Aufzählung: Eine
/// von uns zusammengestellte Liste von Grüßen wäre der Anfang eines Katalogs
/// von Zugehörigkeiten. Was die Kanzlei sonst braucht, legt sie selbst an.
/// </summary>
public static class GrussformelnVorgabe
{
    public static readonly IReadOnlyList<string> Ausgangsbestand =
    [
        "Salamu aleikum",
        "Sat Sri Akal",
    ];
}
