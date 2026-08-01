using System.Runtime.Versioning;

// Die Tests pruefen einen Dienst, der ausschliesslich unter Windows laeuft
// (Word-COM, DPAPI, installierter Browser). Ohne diese Deklaration meldet
// CA1416 jeden Aufruf in den getesteten Code als plattformuebergreifend
// erreichbar. Siehe Core/PlattformUnterstuetzung.cs im Web-Projekt.
[assembly: SupportedOSPlatform("windows")]
