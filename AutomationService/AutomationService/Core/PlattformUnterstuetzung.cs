using System.Runtime.Versioning;

// Der Dienst laeuft ausschliesslich auf Windows und ist auch nicht dafuer
// gedacht, woanders zu laufen: die Dokumenterzeugung und die PDF-Wandlung
// gehen ueber Word-COM-Interop, der MSAL-Token-Cache wird per DPAPI
// verschluesselt, und das Zentralruf-Formular wird in einem installierten
// Edge/Chrome bedient.
//
// Ohne diese Deklaration meldet CA1416 zu Recht, dass windows-only-Aufrufe von
// plattformneutralem Code aus erreichbar sind. Die Angabe macht die ohnehin
// bestehende Einschraenkung explizit, statt die Warnung zu unterdruecken --
// und laesst den Analyzer weiterhin melden, wenn irgendwann Code hinzukommt,
// der auch auf anderen Plattformen laufen soll.
[assembly: SupportedOSPlatform("windows")]
