namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Plausibilitätsprüfungen für die Zuordnung einer Antwort zum Vorgang (Req. 3.3).
/// Gemeinsam genutzt vom manuellen Parse-Endpunkt und vom Postfach-Monitor,
/// damit beide Wege dieselben Hinweise erzeugen.
/// </summary>
public static class ZentralrufReplyWarnings
{
    public static List<string> Collect(ZentralrufReplyData data)
    {
        ArgumentNullException.ThrowIfNull(data);
        var warnings = new List<string>();

        if (data.Zwischennachricht)
        {
            warnings.Add(
                "Dies ist eine Zwischennachricht des Zentralrufs: die Auskunft war nicht sofort " +
                "möglich (z. B. manuelle Prüfung oder ausländisches Kennzeichen). Die endgültige " +
                "Antwort folgt in einer weiteren E-Mail — bitte abwarten, keine Daten übernehmen.");
        }

        if (data.KeinVersichererErmittelt)
        {
            warnings.Add(
                "Der Zentralruf konnte zu dieser Anfrage keinen Versicherer ermitteln. " +
                "Bitte Kennzeichen und Unfalldatum prüfen und die Anfrage ggf. wiederholen.");
        }

        // Die Referenz trägt das Kennzeichen des Vorgangs in sich — weicht es vom
        // angefragten Kennzeichen ab, ist die Antwort womöglich falsch zugeordnet.
        if (data.Kennzeichen is not null
            && data.ReferenzKennzeichen is not null
            && !string.Equals(data.Kennzeichen, data.ReferenzKennzeichen, StringComparison.OrdinalIgnoreCase))
        {
            warnings.Add(
                $"Das angefragte Kennzeichen ({data.Kennzeichen}) stimmt nicht mit dem Kennzeichen " +
                $"in Ihrer Referenz ({data.ReferenzKennzeichen}) überein — bitte Zuordnung prüfen.");
        }

        if (data.Referenz is not null && data.ReferenzAuftragsnummer is null)
        {
            warnings.Add(
                $"Die Referenz \"{data.Referenz}\" folgt nicht dem Schema " +
                "\"Nr/Jahr Abteilung_Kennzeichen\" — Zuordnung zum Vorgang bitte manuell prüfen.");
        }

        return warnings;
    }
}
