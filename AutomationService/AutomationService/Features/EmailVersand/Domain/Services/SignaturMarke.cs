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
/// Je Quelle ein Weg, und beide beantworten dieselbe Frage — „sind das noch
/// dieselben Bytes?":
///
/// * Aus dem <b>Inhalt</b>, wo er ohnehin im Speicher liegt: beim Lesen aus
///   Outlook, wo es noch gar keine Datei von uns gibt.
/// * Aus <b>Größe und Änderungszeitpunkt</b> für eine abgelegte Datei. Sie
///   noch einmal zu lesen, nur um sie zu kennzeichnen, wäre teuer an der
///   falschen Stelle: <see cref="SignaturAblage.Bilder"/> hängt über
///   <c>KanzleiSignatur.BlockAsync</c> auch am Versand und an der
///   Bereitschaftsabfrage, die die Marke gar nicht brauchen — ein 25-MB-Bild
///   ginge dort bei jeder Mail durch den Hash. Beide Angaben stehen im
///   Verzeichniseintrag, den die Ablage ohnehin schon gelesen hat, und sie
///   können damit auch nicht fehlschlagen.
///
/// Der Preis: Beim Übernehmen wechselt die Marke desselben Bildes einmal von
/// der einen Form in die andere, und die Oberfläche lädt es ein weiteres Mal.
/// Das ist ein Abruf über localhost — gegen einen Hash über 25 MB bei jedem
/// Versand ist das kein Handel, über den man lange nachdenkt.
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
    /// Die Marke zu einer abgelegten Datei, aus ihrem Verzeichniseintrag —
    /// ohne sie zu öffnen. Ein Neuschreiben ändert den Zeitstempel, und mehr
    /// muss sie nicht unterscheiden: Es geht um dieselbe Datei vorher und
    /// nachher, nicht um zwei fremde Dateien.
    /// </summary>
    public static string Von(FileInfo datei) =>
        $"{datei.Length:x}-{datei.LastWriteTimeUtc.Ticks:x}";

    private static string Kurz(byte[] hash) =>
        Convert.ToHexString(hash.AsSpan(0, Bytes)).ToLowerInvariant();
}
