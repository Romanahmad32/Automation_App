namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Ein Bild, das in der formatierten Signatur steckt: Kanzleilogo,
/// Zertifikatssiegel, das animierte Werbebild (§4.7).
///
/// Die Größe steht bewusst dabei. Genau sie ist der Grund, warum solche Bilder
/// nicht unter jede Mail gehören: Ein animiertes GIF von mehreren Megabyte
/// wächst mit jeder Nachricht mit, und der Anwalt entscheidet je Mail, ob es
/// mitgeht.
/// </summary>
public sealed record SignaturBild(string Dateiname, long Bytes);
