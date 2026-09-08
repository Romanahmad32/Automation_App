namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Was mit einer Zeile der Registerdatei geschieht. Als Zeichenkette statt als
/// Enum — aus demselben Grund wie bei <c>ImportArten</c> im Mandantenimport:
/// Der Dienst serialisiert Enums als Zahlen, und eine Zahl im Vertrag koppelte
/// die Dart-Seite an die Deklarationsreihenfolge.
///
/// Es gibt bewusst kein „ergaenzt": Die Datei überschreibt nie. Steht die
/// Nummer schon im Bestand, bleibt die gespeicherte Zeile mitsamt zugeordnetem
/// Mandanten und den Änderungen des Anwalts, wie sie ist — sonst machte ein
/// versehentlich zweimal eingelesener Jahrgang die Nacharbeit zunichte.
/// </summary>
public static class RegisterImportArten
{
    /// <summary>Die Zeile ist neu und wird angelegt.</summary>
    public const string Neu = "neu";

    /// <summary>Die Nummer steht schon im Bestand — die Datei ändert nichts.</summary>
    public const string Unveraendert = "unveraendert";

    /// <summary>Die Zeile wird nicht übernommen; der Grund steht in den Befunden.</summary>
    public const string Abgelehnt = "abgelehnt";
}
