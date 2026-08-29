using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Ein Eintrag im Versandprotokoll eines Vorgangs (§4.7): wann, an wen, mit
/// welchen Anhängen — der Nachweis, dass das Anspruchsschreiben hinaus ist.
/// </summary>
/// <param name="VorgangReferenz">
/// Der Vorgang, zu dem der Versand gehört — die Liste über alle Vorgänge
/// (<c>protokoll/letzte</c>) wäre ohne ihn nicht zuzuordnen.
/// </param>
/// <param name="GesendetAm">Zeitpunkt; beim Entwurfsweg der der Übergabe.</param>
/// <param name="Weg">
/// <c>Direktversand</c>, <c>OutlookEntwurf</c> oder <c>Entwurfsdatei</c>. Beim
/// Entwurfsweg ist die Mail <b>übergeben</b>, nicht nachweislich gesendet —
/// die Oberfläche muss den Unterschied zeigen.
/// </param>
/// <param name="Absender">Die Adresse, von der aus gesendet wurde.</param>
/// <param name="Empfaenger">Die Adressen in „An".</param>
/// <param name="Kopie">Die Adressen in „Kopie".</param>
/// <param name="Betreff">Die Betreffzeile, wie sie hinausging.</param>
/// <param name="Anhaenge">
/// Die Namen, unter denen die Anhänge hinausgingen — nicht die auf Platte.
/// </param>
/// <param name="ImGesendetOrdner">
/// Ob die Kopie im Ordner „Gesendet" des Postfachs landete. Dort — und damit
/// in Outlook am selben Konto — liegt die Mail selbst.
/// </param>
/// <param name="MessageId">
/// Die Message-ID der eingelieferten Nachricht; null beim Entwurfsweg.
/// </param>
public sealed record VersandEintragDto(
    string VorgangReferenz,
    DateTimeOffset GesendetAm,
    string Weg,
    string Absender,
    IReadOnlyList<string> Empfaenger,
    IReadOnlyList<string> Kopie,
    string Betreff,
    IReadOnlyList<string> Anhaenge,
    bool ImGesendetOrdner,
    string? MessageId)
{
    public static VersandEintragDto From(VersandEintrag eintrag) => new(
        eintrag.VorgangReferenz,
        eintrag.GesendetAm,
        eintrag.Weg.ToString(),
        eintrag.Absender,
        eintrag.Empfaenger,
        eintrag.Kopie,
        eintrag.Betreff,
        eintrag.Anhaenge,
        eintrag.ImGesendetOrdner,
        eintrag.MessageId);
}
