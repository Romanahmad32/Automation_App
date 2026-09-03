namespace AutomationService.Core.ErrorHandling;

/// <summary>
/// Die deutschen Meldungen der DTO-Schranken, an einer Stelle.
///
/// Warum als Konstanten und nicht zentral am Filter: ASP.NET Core uebersetzt
/// Validierungsmeldungen nur ueber <c>AddDataAnnotationsLocalization</c>, und
/// dieser Haken greift ausschliesslich bei Attributen, an denen
/// <c>ErrorMessage</c> ausdruecklich gesetzt ist — genau das, was er ersparen
/// sollte. Die Vorgabetexte der Attribute sind englisch und nicht austauschbar
/// ("The {0} field is required."). Also traegt jedes Attribut seinen Text, und
/// damit die Formulierung trotzdem nur einmal existiert, steht sie hier.
///
/// <c>{0}</c> ist der Anzeigename des Feldes: der Text aus <c>[Display]</c>,
/// sonst der C#-Eigenschaftsname. Jedes Feld mit einer Schranke bekommt
/// deshalb ein <c>[Display]</c> — "KennzeichenSchaediger muss ausgefuellt
/// sein" ist kein Satz, den ein Anwalt lesen soll.
/// </summary>
public static class Validierungstexte
{
    public const string Pflicht = "{0} muss ausgefüllt sein.";

    public const string Bereich = "{0} muss zwischen {1} und {2} liegen.";

    public const string BereichEuro = "{0} muss zwischen {1} und {2} € liegen.";

    public const string MaxZeichen = "{0} darf höchstens {1} Zeichen haben.";

    public const string MaxEintraege = "{0} darf höchstens {1} Einträge enthalten.";

    public const string MindestensEinEintrag = "{0} muss mindestens einen Eintrag enthalten.";

    public const string EmailForm = "{0} ist keine gültige E-Mail-Adresse.";
}
