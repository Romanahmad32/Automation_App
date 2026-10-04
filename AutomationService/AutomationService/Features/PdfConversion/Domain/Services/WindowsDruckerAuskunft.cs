using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Fragt den Standarddrucker über die Druckwarteschlange von Windows ab
/// (<c>winspool.drv</c>: <c>GetDefaultPrinter</c>, <c>GetPrinter</c> Stufe 2).
/// Ohne Paket und in Millisekunden — WMI (<c>Win32_Printer</c>) bräuchte
/// <c>System.Management</c> und braucht beim ersten Aufruf spürbar länger,
/// gerade beim Öffnen des Dialogs.
///
/// Viele Netzwerkdrucker melden auch offline den Status 0. Verlässlich ist vor
/// allem das Attribut „Drucker offline verwenden", das Windows selbst setzt,
/// wenn es den Drucker nicht erreicht. Der Zustand ist deshalb ein Hinweis,
/// keine Sperre.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsDruckerAuskunft(ILogger<WindowsDruckerAuskunft> logger) : IDruckerAuskunft
{
    // PRINTER_STATUS_* und PRINTER_ATTRIBUTE_* aus winspool.h.
    private const uint StatusAngehalten = 0x1;
    private const uint StatusFehler = 0x2;
    private const uint StatusPapierstau = 0x8;
    private const uint StatusKeinPapier = 0x10;
    private const uint StatusOffline = 0x80;
    private const uint StatusNichtVerfuegbar = 0x1000;
    private const uint StatusKeinToner = 0x40000;
    private const uint StatusEingriffNoetig = 0x100000;
    private const uint StatusKlappeOffen = 0x400000;
    private const uint AttributOfflineVerwenden = 0x400;

    private const uint Gestoert = StatusFehler | StatusPapierstau | StatusKeinPapier
        | StatusKeinToner | StatusEingriffNoetig | StatusKlappeOffen;

    public DruckerLage Standarddrucker()
    {
        var name = StandarddruckerName();
        if (name is null)
        {
            return new DruckerLage(null, DruckerZustand.KeinDrucker);
        }

        try
        {
            var (status, attribute) = StatusUndAttribute(name);
            return new DruckerLage(name, ZustandAus(status, attribute));
        }
        catch (Win32Exception exception)
        {
            logger.LogInformation(exception, "Drucker {Drucker} ließ sich nicht abfragen.", name);
            return new DruckerLage(name, DruckerZustand.Unbekannt);
        }
    }

    /// <summary>Übersetzt Status und Attribute aus <c>PRINTER_INFO_2</c>.</summary>
    public static DruckerZustand ZustandAus(uint status, uint attribute) =>
        (status, attribute) switch
        {
            _ when (attribute & AttributOfflineVerwenden) != 0 => DruckerZustand.Offline,
            _ when (status & (StatusOffline | StatusNichtVerfuegbar)) != 0 => DruckerZustand.Offline,
            _ when (status & Gestoert) != 0 => DruckerZustand.Gestoert,
            _ when (status & StatusAngehalten) != 0 => DruckerZustand.Angehalten,
            _ => DruckerZustand.Bereit,
        };

    private static string? StandarddruckerName()
    {
        var laenge = 0;
        NativeMethods.GetDefaultPrinter(null, ref laenge);
        if (laenge == 0)
        {
            return null;
        }

        var puffer = new char[laenge];
        return NativeMethods.GetDefaultPrinter(puffer, ref laenge)
            ? new string(puffer, 0, Math.Max(0, laenge - 1))
            : null;
    }

    private static (uint Status, uint Attribute) StatusUndAttribute(string name)
    {
        if (!NativeMethods.OpenPrinter(name, out var drucker, IntPtr.Zero))
        {
            throw new Win32Exception(Marshal.GetLastPInvokeError());
        }

        try
        {
            NativeMethods.GetPrinter(drucker, 2, IntPtr.Zero, 0, out var benoetigt);
            if (benoetigt <= 0)
            {
                throw new Win32Exception(Marshal.GetLastPInvokeError());
            }

            var speicher = Marshal.AllocHGlobal(benoetigt);
            try
            {
                if (!NativeMethods.GetPrinter(drucker, 2, speicher, benoetigt, out _))
                {
                    throw new Win32Exception(Marshal.GetLastPInvokeError());
                }

                var info = Marshal.PtrToStructure<PrinterInfo2>(speicher);
                return (info.Status, info.Attributes);
            }
            finally
            {
                Marshal.FreeHGlobal(speicher);
            }
        }
        finally
        {
            NativeMethods.ClosePrinter(drucker);
        }
    }

    /// <summary><c>PRINTER_INFO_2</c> — gebraucht werden nur Attribute und Status.</summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct PrinterInfo2
    {
        public IntPtr ServerName;
        public IntPtr PrinterName;
        public IntPtr ShareName;
        public IntPtr PortName;
        public IntPtr DriverName;
        public IntPtr Comment;
        public IntPtr Location;
        public IntPtr DevMode;
        public IntPtr SepFile;
        public IntPtr PrintProcessor;
        public IntPtr Datatype;
        public IntPtr Parameters;
        public IntPtr SecurityDescriptor;
        public uint Attributes;
        public uint Priority;
        public uint DefaultPriority;
        public uint StartTime;
        public uint UntilTime;
        public uint Status;
        public uint Jobs;
        public uint AveragePpm;
    }

    private static class NativeMethods
    {
        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetDefaultPrinter(char[]? puffer, ref int laenge);

        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool OpenPrinter(string name, out IntPtr drucker, IntPtr vorgaben);

        [DllImport("winspool.drv", SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetPrinter(IntPtr drucker, int stufe, IntPtr puffer, int groesse, out int benoetigt);

        [DllImport("winspool.drv", SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool ClosePrinter(IntPtr drucker);
    }
}
