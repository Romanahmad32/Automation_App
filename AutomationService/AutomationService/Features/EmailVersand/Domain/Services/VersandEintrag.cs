namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>Auf welchem Weg die Nachricht das Haus verließ (§4.7).</summary>
public enum VersandWeg
{
    /// <summary>Die App hat über das Postfach der Kanzlei gesendet.</summary>
    Direktversand,

    /// <summary>
    /// An Outlook übergeben. <b>Nicht</b> „gesendet": Ob dort abgeschickt
    /// wurde, weiß die App nicht (§4.8) — und das Protokoll darf nichts
    /// behaupten, was es nicht weiß.
    /// </summary>
    OutlookEntwurf,

    /// <summary>Als Entwurfsdatei abgelegt, weil Outlook nicht erreichbar war.</summary>
    Entwurfsdatei,
}

/// <summary>
/// Ein Eintrag im Versandprotokoll (§4.7): wann, an wen, mit welchen Anhängen.
///
/// Für eine Kanzlei ist das der Nachweis, dass das Anspruchsschreiben hinaus
/// ist. Bis hierher hielt die App ihn nur für die Dauer eines Dialogs — danach
/// stand er nirgends mehr, und die Frage „wann ging das raus?" war nur noch im
/// Postfach zu beantworten.
/// </summary>
/// <param name="VorgangReferenz">Der Vorgang, unter dem der Eintrag hängt.</param>
/// <param name="GesendetAm">
/// Zeitpunkt der Einlieferung — beim Entwurfsweg der der Übergabe.
/// </param>
/// <param name="Weg">Direktversand, Outlook-Entwurf oder Entwurfsdatei.</param>
/// <param name="Absender">Die Adresse, von der aus gesendet wurde.</param>
/// <param name="Empfaenger">Die Adressen in „An".</param>
/// <param name="Kopie">Die Adressen in „Kopie".</param>
/// <param name="Betreff">Die Betreffzeile, wie sie hinausging.</param>
/// <param name="Anhaenge">
/// Die Namen, unter denen sie hinausgingen — nicht die auf Platte.
/// </param>
/// <param name="ImGesendetOrdner">
/// Ob die Kopie im Ordner "Gesendet" des Postfachs landete. Dort — und damit
/// in Outlook am selben Konto — liegt die Mail selbst; dieses Protokoll ist
/// der Index darüber, nicht ihr Ersatz.
/// </param>
/// <param name="MessageId">
/// Die Message-ID der eingelieferten Nachricht; null beim Entwurfsweg, wo sie
/// erst das Mailprogramm vergibt.
/// </param>
public sealed record VersandEintrag(
    string VorgangReferenz,
    DateTimeOffset GesendetAm,
    VersandWeg Weg,
    string Absender,
    IReadOnlyList<string> Empfaenger,
    IReadOnlyList<string> Kopie,
    string Betreff,
    IReadOnlyList<string> Anhaenge,
    bool ImGesendetOrdner = false,
    string? MessageId = null);
