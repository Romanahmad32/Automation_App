using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.PdfConversion.Domain.Services;

public interface IWordInteropPdfConverter
{
    /// <summary>null = noch nicht versucht, false = Word nicht verfügbar.</summary>
    bool? IsAvailable { get; }

    Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath, CancellationToken cancellationToken = default);

    /// <summary>Erzeugt die Word-Instanz vorab, damit der erste echte Request nicht den Start bezahlt.</summary>
    Task WarmupAsync();
}

/// <summary>
/// Konvertiert DOCX zu PDF über das installierte Microsoft Word (COM,
/// ExportAsFixedFormat) — dadurch entspricht die Vorschau exakt dem Druckbild.
/// Bewusst Late-Binding über die ProgID statt der Interop-PIAs: die PIA-Assemblys
/// ("office", "Microsoft.Office.Interop.Word") sind unter .NET (ohne GAC) zur
/// Laufzeit nicht auflösbar und würden den Prozess crashen.
/// Word-COM ist nicht threadsafe: alle Aufrufe werden über eine Queue auf einem
/// dedizierten STA-Thread serialisiert; die Word-Instanz bleibt zwischen den
/// Aufrufen am Leben (Startkosten fallen nur einmal an).
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WordInteropPdfConversionService : IWordInteropPdfConverter, IAsyncDisposable
{
    private const int WdExportFormatPdf = 17;     // WdExportFormat.wdExportFormatPDF
    private const int WdDoNotSaveChanges = 0;     // WdSaveOptions.wdDoNotSaveChanges
    private const int WdAlertsNone = 0;           // WdAlertLevel.wdAlertsNone

    private sealed record ConversionJob(string? DocxPath, TaskCompletionSource<byte[]> Completion);

    private readonly BlockingCollection<ConversionJob> _jobs = [];
    private readonly Thread _workerThread;
    private readonly TimeSpan _conversionTimeout;
    private readonly ILogger<WordInteropPdfConversionService> _logger;

    private dynamic? _wordApplication;
    private volatile bool _wordUnavailable;
    private volatile bool _firstAttemptDone;
    private bool _disposed;

    public bool? IsAvailable => _firstAttemptDone ? !_wordUnavailable : null;

    public WordInteropPdfConversionService(
        IOptions<PdfConversionOptions> options,
        ILogger<WordInteropPdfConversionService> logger)
    {
        _logger = logger;
        _conversionTimeout = TimeSpan.FromSeconds(options.Value.ConversionTimeoutSeconds);
        _workerThread = new Thread(WorkerLoop) { IsBackground = true, Name = "WordInteropPdf" };
        _workerThread.SetApartmentState(ApartmentState.STA);
        _workerThread.Start();
    }

    public async Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(docxFilePath))
            throw new ArgumentException("DOCX file path cannot be null or empty.", nameof(docxFilePath));
        if (!File.Exists(docxFilePath))
            throw new FileNotFoundException($"DOCX file not found: {docxFilePath}");
        if (_wordUnavailable)
            throw new PdfConversionUnavailableException("Microsoft Word ist auf diesem System nicht verfügbar.");

        var job = new ConversionJob(
            Path.GetFullPath(docxFilePath),
            new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously));
        _jobs.Add(job, cancellationToken);

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(_conversionTimeout);
        return await job.Completion.Task.WaitAsync(timeoutSource.Token);
    }

    public Task WarmupAsync()
    {
        var job = new ConversionJob(null, new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously));
        _jobs.Add(job);
        return job.Completion.Task;
    }

    private void WorkerLoop()
    {
        foreach (var job in _jobs.GetConsumingEnumerable())
        {
            try
            {
                if (job.DocxPath is null)
                {
                    EnsureWordApplication();
                    job.Completion.TrySetResult([]);
                    continue;
                }

                byte[] pdfBytes;
                try
                {
                    pdfBytes = ConvertOnWorkerThread(job.DocxPath);
                }
                catch (COMException)
                {
                    // Word-Instanz könnte abgestürzt/extern beendet worden sein:
                    // einmal frisch aufbauen und den Job wiederholen.
                    TearDownWordApplication();
                    pdfBytes = ConvertOnWorkerThread(job.DocxPath);
                }

                job.Completion.TrySetResult(pdfBytes);
            }
            catch (Exception exception)
            {
                job.Completion.TrySetException(Translate(exception));
            }
        }

        TearDownWordApplication();
    }

    private byte[] ConvertOnWorkerThread(string docxPath)
    {
        var word = EnsureWordApplication();
        var tempPdfPath = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.pdf");

        dynamic? document = null;
        try
        {
            document = word.Documents.Open(
                docxPath,
                ReadOnly: true,
                AddToRecentFiles: false,
                Visible: false);
            document!.ExportAsFixedFormat(tempPdfPath, WdExportFormatPdf);
        }
        finally
        {
            if (document is not null)
            {
                document.Close(WdDoNotSaveChanges);
                Marshal.ReleaseComObject(document);
            }
        }

        var pdfBytes = File.ReadAllBytes(tempPdfPath);
        File.Delete(tempPdfPath);
        return pdfBytes;
    }

    private dynamic EnsureWordApplication()
    {
        if (_wordApplication is not null)
            return _wordApplication;

        var wordType = Type.GetTypeFromProgID("Word.Application");
        if (wordType is null)
        {
            _wordUnavailable = true;
            _firstAttemptDone = true;
            _logger.LogWarning("Microsoft Word ist nicht installiert — PDF-Vorschau fällt auf FreeSpire zurück.");
            throw new PdfConversionUnavailableException("Microsoft Word ist auf diesem System nicht installiert.");
        }

        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        dynamic word = Activator.CreateInstance(wordType)!;
        word.Visible = false;
        word.DisplayAlerts = WdAlertsNone;
        word.ScreenUpdating = false;
        _wordApplication = word;
        _firstAttemptDone = true;
        _logger.LogInformation("Word-Instanz gestartet in {ElapsedMs} ms.", stopwatch.ElapsedMilliseconds);
        return word;
    }

    private void TearDownWordApplication()
    {
        if (_wordApplication is null)
            return;

        try
        {
            _wordApplication.Quit(WdDoNotSaveChanges);
        }
        catch (COMException)
        {
            // Instanz ist bereits weg (abgestürzt oder extern beendet) — nichts zu tun.
        }
        finally
        {
            Marshal.ReleaseComObject(_wordApplication);
            _wordApplication = null;
            GC.Collect();
            GC.WaitForPendingFinalizers();
        }
    }

    private static Exception Translate(Exception exception) =>
        exception switch
        {
            PdfConversionUnavailableException or FileNotFoundException => exception,
            _ => new InvalidOperationException("Fehler bei der Konvertierung von .docx zu .pdf über Word.", exception),
        };

    public ValueTask DisposeAsync()
    {
        if (_disposed)
            return ValueTask.CompletedTask;
        _disposed = true;

        _jobs.CompleteAdding();
        if (!_workerThread.Join(TimeSpan.FromSeconds(5)))
            _logger.LogWarning("Word-Worker-Thread hat sich nicht rechtzeitig beendet.");
        _jobs.Dispose();
        return ValueTask.CompletedTask;
    }
}
