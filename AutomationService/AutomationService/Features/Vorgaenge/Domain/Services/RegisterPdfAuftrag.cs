namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Ein Auftrag an die PDF-Warteschlange: alles, was die Wandlung noch braucht,
/// nachdem die Antwort längst hinaus ist (§6.2 „Word sofort, PDF nachgezogen").
///
/// Bewusst nur Pfade und der Stand des Laufs — kein <c>DbContext</c>, keine
/// Zeilen, kein Abbruch-Token des Aufrufs. Der Scope der Anfrage, an dem der
/// Context hängt, ist zu diesem Zeitpunkt abgeräumt; wer ihn hier mitgäbe,
/// bekäme beim ersten Zugriff ein „Cannot access a disposed context instance" —
/// und zwar im Hintergrund, wo niemand hinsieht. Gebraucht wird er auch nicht:
/// Die Zeilen stehen längst in der .docx.
/// </summary>
/// <param name="QuellDocx">
/// Die fertige .docx im Bauordner — die Vorlage der Wandlung, und eine eigene
/// Kopie. Die Fassung im Ablageordner wäre der naheliegendere Weg, aber der
/// Spiegel liest den Zielordner grundsätzlich nicht: Er kann auf „Dateien bei
/// Bedarf" stehen, und dann löste jeder Lesezugriff einen Download aus. Der
/// Auftrag räumt sie weg, wenn er fertig ist.
/// </param>
/// <param name="BauPdf">Wo das PDF entsteht, bevor es in die Ablage umzieht.</param>
/// <param name="Ablage">Die Zielpfade; abgelegt wird von hier aus nur das PDF.</param>
/// <param name="Stand">
/// Der Eintrag, den der Schreiblauf hinterlassen hat. Er sagt dem Auftrag, ob er
/// noch der aktuelle ist: Nennt der Stand inzwischen einen anderen Bestand, hat
/// ein neuerer Lauf die .docx im Ablageordner ersetzt — und dann wäre dieses PDF
/// beim Ablegen genau das, was §6.2 verbietet, eine Fassung von gestern neben
/// einer .docx von heute.
/// </param>
public sealed record RegisterPdfAuftrag(
    string QuellDocx,
    string BauPdf,
    RegisterSpiegelAblage Ablage,
    RegisterSpiegelStand.Eintrag Stand);
