using Spire.Doc;

namespace AutomationService.Features.PdfConversion.Domain.Services;

public class PdfConversionService : IPdfConversionService
{
        /// <summary>
        /// Konvertiert eine DOCX-Datei direkt von der Festplatte zu PDF
        /// (Effizient für existierende Dateien)
        /// </summary>
        public async Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
        {
            if (string.IsNullOrWhiteSpace(docxFilePath))
                throw new ArgumentException("DOCX file path cannot be null or empty.", nameof(docxFilePath));
    
            if (!File.Exists(docxFilePath))
                throw new FileNotFoundException($"DOCX file not found: {docxFilePath}");
    
            try
            {
                string tempPdfPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".pdf");
    
                Document doc = new Document();
                doc.LoadFromFile(docxFilePath, FileFormat.Docx);
                doc.SaveToFile(tempPdfPath, FileFormat.PDF);
    
                byte[] pdfBytes = await File.ReadAllBytesAsync(tempPdfPath);
                File.Delete(tempPdfPath);
    
                return pdfBytes;
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Fehler bei der Konvertierung von .docx zu .pdf", ex);
            }
        }
    
    public async Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes)
    {
        if (docxBytes == null || docxBytes.Length == 0)
            throw new ArgumentException("Input DOCX bytes cannot be null or empty.");

        try
        {
            string tempDocxPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".docx");
            string tempPdfPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".pdf");

            await File.WriteAllBytesAsync(tempDocxPath, docxBytes);

            Document doc = new Document();
            doc.LoadFromFile(tempDocxPath, FileFormat.Docx);
            doc.SaveToFile(tempPdfPath, FileFormat.PDF);

            byte[] pdfBytes = await File.ReadAllBytesAsync(tempPdfPath);

            File.Delete(tempDocxPath);
            File.Delete(tempPdfPath);

            return pdfBytes;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("Fehler bei der Konvertierung von .docx zu .pdf", ex);
        }
    }
}