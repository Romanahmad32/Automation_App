namespace AutomationService.Features.WordAutomation.Domain.Exceptions;

public sealed class TemplateProcessingException : Exception
{
    public TemplateProcessingException(string message) : base(message)
    {
    }

    public TemplateProcessingException(string message, Exception innerException) : base(message, innerException)
    {
    }
}
