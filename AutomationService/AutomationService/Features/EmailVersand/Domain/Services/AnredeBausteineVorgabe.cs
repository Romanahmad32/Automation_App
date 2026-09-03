namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die Anredeanfänge, mit denen der Bestand ab Werk startet (§4.7, §7.1).
///
/// Der erste ist <b>kein Vorschlag, sondern der Bestand</b>: „Sehr geehrter /
/// Sehr geehrte / Sehr geehrte" ergibt genau die Anrede, die die App vor dem
/// 02.09.2026 fest erzeugt hat (<c>Anrede.briefanrede</c> im Frontend). Ohne
/// ihn wäre die Wahl beim ersten Start leer und jede Mail ohne Anrede — die
/// Umstellung von „fest" auf „wählbar" darf nichts wegnehmen.
///
/// Der zweite ist der Beleg dafür, dass die drei Formen auch gleich lauten
/// dürfen: „Guten Tag" beugt nicht. Mehr wird nicht mitgeliefert — was die
/// Kanzlei sonst schreibt, legt sie selbst an (§7.1).
/// </summary>
public static class AnredeBausteineVorgabe
{
    /// <summary>
    /// Feste Id des Standardanfangs. Sie steht hier, damit Migration, Seed und
    /// ein späterer Test dieselbe Zeile meinen.
    /// </summary>
    public const int SehrGeehrtId = 1;

    public static readonly IReadOnlyList<(string Maennlich, string Weiblich, string Neutral)>
        Ausgangsbestand =
        [
            ("Sehr geehrter", "Sehr geehrte", "Sehr geehrte"),
            ("Guten Tag", "Guten Tag", "Guten Tag"),
        ];
}
