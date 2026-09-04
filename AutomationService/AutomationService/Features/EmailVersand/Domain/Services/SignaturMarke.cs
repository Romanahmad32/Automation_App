using System.Security.Cryptography;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die Kennmarke eines Signaturbildes (§4.7): ein kurzes Kennzeichen seines
/// <b>Inhalts</b>, das mit dem Bild in die Oberfläche geht und dort an seine
/// Adresse gehängt wird.
///
/// Der Grund liegt in Outlooks Namensgebung. Es nennt das erste Bild jeder
/// Signatur <c>image001.png</c> — jeder. Die Ablage kennt aber nur den blanken
/// Dateinamen, also liegt jedes übernommene Logo unter demselben Namen und
/// wird unter derselben Adresse ausgeliefert. Flutter merkt sich geladene
/// Bilder je Adresse: Nach einem Signaturwechsel fragte die Oberfläche gar
/// nicht mehr nach, sondern zeigte weiter das Logo der vorigen Signatur — bis
/// zum Neustart der App, in jedem Reiter (behoben am 04.09.2026).
///
/// Mit der Marke ändert sich die Adresse genau dann, wenn sich das Bild
/// ändert. Der Dienst braucht sie nicht, um das Bild zu finden; sie steht nur
/// dort, damit ein anderes Bild eine andere Adresse hat.
///
/// Warum aus dem Inhalt und nicht aus dem Änderungszeitpunkt: Das Bild kommt
/// in der Vorschau aus Outlooks Beiordner und nach dem Übernehmen aus der
/// Ablage — zwei Dateien mit zwei Zeitstempeln, aber demselben Inhalt. Eine
/// Marke aus dem Inhalt bleibt über die Übernahme hinweg dieselbe und lässt
/// die Oberfläche das schon geladene Bild behalten.
/// </summary>
public static class SignaturMarke
{
    /// <summary>
    /// Acht Byte reichen: Die Marke unterscheidet eine Handvoll Bilder
    /// derselben Kanzlei, sie sichert nichts ab. Ein vollständiger SHA-256
    /// machte jede Bildadresse um 48 Zeichen länger, ohne dass irgendwer
    /// davon etwas hätte.
    /// </summary>
    private const int Bytes = 8;

    /// <summary>Die Marke zu einem Bild, das schon im Speicher liegt.</summary>
    public static string Von(byte[] inhalt) => Kurz(SHA256.HashData(inhalt));

    /// <summary>
    /// Die Marke zu einer abgelegten Datei. Leer, wenn sie sich nicht lesen
    /// lässt — dann fehlt der Oberfläche nur die Unterscheidung, und das ist
    /// kein Grund, die Signatur gar nicht erst zu melden.
    /// </summary>
    public static string Von(FileInfo datei)
    {
        try
        {
            using var strom = datei.OpenRead();
            return Kurz(SHA256.HashData(strom));
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return string.Empty;
        }
    }

    private static string Kurz(byte[] hash) =>
        Convert.ToHexString(hash.AsSpan(0, Bytes)).ToLowerInvariant();
}
