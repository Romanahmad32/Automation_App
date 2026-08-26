namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Ob gesendet werden kann, und von welcher Adresse aus. Die Oberfläche fragt
/// das ab, <b>bevor</b> der Anwalt eine Mail verfasst — einen fertig getippten
/// Text an einer fehlenden Anmeldung scheitern zu lassen, ist die teuerste Art,
/// diese Auskunft zu geben.
/// </summary>
/// <param name="Bereit">True, wenn ein Sendeversuch überhaupt Sinn hat.</param>
/// <param name="Absender">Adresse des hinterlegten Postfachs, sonst leer.</param>
/// <param name="Hinweis">
/// Grund im Klartext, wenn nicht bereit (kein Zugang hinterlegt, Microsoft-
/// Anmeldung abgelaufen). Null, wenn alles steht.
/// </param>
/// <param name="Signatur">
/// Der Signaturblock aus den Einstellungen, den der Direktversand anfuegt
/// (§4.7). Die Oberflaeche zeigt ihn in der Vorschau — was unter der Mail
/// steht, soll der Anwalt sehen, bevor sie hinausgeht, und nicht erst im
/// Ordner "Gesendet".
/// </param>
public sealed record EmailVersandBereitschaft(
    bool Bereit,
    string Absender,
    string? Hinweis,
    string Signatur = "")
{
    public static EmailVersandBereitschaft Nicht(string hinweis) => new(false, string.Empty, hinweis);
}
