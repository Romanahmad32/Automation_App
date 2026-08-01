namespace AutomationService.Features.PdfConversion.Domain.Services;

public interface IPdfConversionService
{
    Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath);
    Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes);
}