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
/// <param name="SignaturBilder">
/// Die Bilder der formatierten Signatur mit ihrer Groesse. Der Anwalt laesst
/// einzelne davon je Mail weg — das schwere Werbebild etwa —, und dafuer muss
/// er sehen, was sie wiegen.
/// </param>
/// <param name="MaxAnhangMb">
/// Obergrenze der ganzen Nachricht. Sie steht hier, damit die Oberflaeche beim
/// Anhaengen mitzaehlen kann: Die Grenze erst beim Senden zu nennen, hiesse sie
/// nach dem einen unumkehrbaren Klick zu nennen.
/// </param>
public sealed record EmailVersandBereitschaft(
    bool Bereit,
    string Absender,
    string? Hinweis,
    string Signatur = "",
    IReadOnlyList<SignaturBild>? SignaturBilder = null,
    int MaxAnhangMb = 0)
{
    public IReadOnlyList<SignaturBild> Bilder => SignaturBilder ?? [];

    public static EmailVersandBereitschaft Nicht(string hinweis) => new(false, string.Empty, hinweis);
}
