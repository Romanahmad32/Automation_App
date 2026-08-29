namespace AutomationService.Tests.Support;

/// <summary>
/// Testdaten für die Signatur (§4.7). Eigener Helfer, weil dieselben Proben in
/// zwei Testklassen gebraucht werden — beim Übernehmen aus Outlook und beim
/// Bau der Nachricht.
/// </summary>
public static class SignaturProben
{
    /// <summary>Ein Bild dieser Größe; der Inhalt spielt keine Rolle.</summary>
    public static byte[] Bild(int bytes) => Enumerable.Repeat((byte)7, bytes).ToArray();

    /// <summary>
    /// Ein echtes, zweibildriges GIF89a mit Schleifen-Erweiterung. Klein, aber
    /// strukturell eine Animation — genau die Sorte Werbebild, die in der
    /// Signatur der Kanzlei steckt.
    /// </summary>
    public static byte[] AnimiertesGif() =>
    [
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61,             // GIF89a
        0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,       // 1x1, globale Farbtabelle
        0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00,             // weiss, schwarz
        0x21, 0xFF, 0x0B,                               // Anwendungserweiterung
        0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30,
        0x03, 0x01, 0x00, 0x00, 0x00,                   // Endlosschleife
        0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00, 0x00, 0x00, // Bild 1: Steuerblock
        0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0x02, 0x02, 0x44, 0x01, 0x00,
        0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00, 0x00, 0x00, // Bild 2: Steuerblock
        0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0x02, 0x02, 0x04, 0x01, 0x00,
        0x3B,                                           // Ende
    ];

    /// <summary>
    /// Legt eine Datei unter <paramref name="ordner"/> an (Unterordner werden
    /// erzeugt) und liefert ihren vollen Pfad.
    /// </summary>
    public static string Datei(string ordner, string name, byte[] inhalt)
    {
        var pfad = Path.Combine(ordner, name);
        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        File.WriteAllBytes(pfad, inhalt);
        return pfad;
    }
}
