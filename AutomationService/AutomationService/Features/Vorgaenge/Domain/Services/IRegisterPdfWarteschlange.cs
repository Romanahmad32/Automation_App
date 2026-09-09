namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Nimmt die PDF-Fassung des Register-Spiegels aus dem Weg des Anwalts
/// (§6.2 „Word sofort, PDF nachgezogen").
///
/// Der Grund steht in der Messung: Beim Bestand der Kanzlei (93 Seiten, rund
/// 2.000 Zeilen) braucht die .docx 0,8 s und die Wandlung durch Word 20 s —
/// bei etwa 0,23 s je Seite wächst nur der zweite Wert. Solange der
/// Vorgangsabschluss darauf wartete, war er ein Knopf, der zwanzig Sekunden
/// hängt, und das ist kein Knopf, den man drückt.
///
/// Als eigene Naht und nicht als <c>Task.Run</c> im Dienst: Der Aufrufer hält
/// einen Scoped-<c>DbContext</c>, der mit seiner Antwort stirbt. Eine
/// abgesetzte Aufgabe, die weiterläuft, muss deshalb *von* diesem Scope
/// getrennt sein und nicht bloß neben ihm liegen — die Warteschlange ist ein
/// Singleton, ihr Abnehmer ein Hintergrunddienst, und im Auftrag steht nichts,
/// was am Scope hängt (siehe <see cref="RegisterPdfAuftrag"/>).
/// </summary>
public interface IRegisterPdfWarteschlange
{
    /// <summary>
    /// Reiht die Wandlung ein und kehrt sofort zurück. Wirft nicht: Ein Auftrag,
    /// der nicht mehr angenommen wird (die App fährt herunter), kostet die
    /// PDF-Fassung — nicht den Spiegel, der als .docx schon liegt.
    /// </summary>
    void Einreihen(RegisterPdfAuftrag auftrag);

    /// <summary>
    /// Ob gerade eine PDF-Fassung entsteht — wartend oder schon in der Wandlung.
    ///
    /// Das ist der Wert hinter „Dass ein PDF gerade entsteht, ist an der
    /// Oberfläche ablesbar" (§6.2). Er hängt bewusst nicht an der Anfrage,
    /// die das Schreiben angestoßen hat, sondern am Prozess: Wer die
    /// Registerseite nach einem Fensterwechsel neu öffnet, soll den laufenden
    /// Lauf weiterhin sehen.
    /// </summary>
    bool Laeuft { get; }
}
