// using AutomationService.Features.WordAutomation.Domain.Services;
// using AutomationService.Features.WordAutomation.Presentation.Dtos;
// using AutomationService.Tests.Support;
// using FluentAssertions;
// using Microsoft.Extensions.Logging.Abstractions;
// using Microsoft.Extensions.Options;
// using Xceed.Words.NET;
//
// namespace AutomationService.Tests.Unit;
//
// public class WordAutomationServiceTests : IDisposable
// {
//     private readonly string _contentRoot;
//
//     public WordAutomationServiceTests()
//     {
//         _contentRoot = Path.Combine(Path.GetTempPath(), $"AutomationServiceTests_{Guid.NewGuid():N}");
//         Directory.CreateDirectory(Path.Combine(_contentRoot, "Templates"));
//         Directory.CreateDirectory(Path.Combine(_contentRoot, "Generated"));
//     }
//
//     [Fact]
//     public void GenerateReplacedDocument_ReplacesKnownPlaceholders_IgnoresCase()
//     {
//         var templatePath = Path.Combine(_contentRoot, "Templates", "Letter.docx");
//         using (var document = DocX.Create(templatePath))
//         {
//             document.InsertParagraph("Hello {{FirstName}}, date={{Today}}");
//             document.Save();
//         }
//
//         var service = CreateService();
//         var response = service.GenerateReplacedDocument(new WordReplacementDto
//         {
//             FileName = "Letter",
//             ReplacePatterns = new Dictionary<string, string> { ["firstname"] = "Roman" }
//         });
//
//         var outputPath = Path.Combine(_contentRoot, "Generated", response.OutputFileName);
//         File.Exists(outputPath).Should().BeTrue();
//         using var outputDocument = DocX.Load(outputPath);
//         var text = outputDocument.Text;
//         text.Should().Contain("Roman");
//         text.Should().NotContain("{{Today}}");
//     }
//
//     [Fact]
//     public void GenerateReplacedDocument_WhenTemplateMissing_ThrowsFileNotFoundException()
//     {
//         var service = CreateService();
//
//         var action = () => service.GenerateReplacedDocument(new WordReplacementDto
//         {
//             FileName = "MissingTemplate",
//             ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
//         });
//
//         action.Should().Throw<FileNotFoundException>();
//     }
//
//     [Fact]
//     public void GenerateReplacedDocument_WhenFileNameContainsTraversal_ThrowsArgumentException()
//     {
//         var service = CreateService();
//
//         var action = () => service.GenerateReplacedDocument(new WordReplacementDto
//         {
//             FileName = "..\\secrets",
//             ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
//         });
//
//         action.Should().Throw<ArgumentException>();
//     }
//
//     [Fact]
//     public void GenerateReplacedDocument_WhenPlaceholderMissing_ReturnsWarningAndKeepsTag()
//     {
//         var templatePath = Path.Combine(_contentRoot, "Templates", "Contract.docx");
//         using (var document = DocX.Create(templatePath))
//         {
//             document.InsertParagraph("Value={{Known}} Missing={{Unknown}}");
//             document.Save();
//         }
//
//         var service = CreateService();
//         var response = service.GenerateReplacedDocument(new WordReplacementDto
//         {
//             FileName = "Contract",
//             ReplacePatterns = new Dictionary<string, string> { ["Known"] = "ok" }
//         });
//
//         response.Warnings.Should().Contain("Unknown");
//         var outputPath = Path.Combine(_contentRoot, "Generated", response.OutputFileName);
//         using var outputDocument = DocX.Load(outputPath);
//         outputDocument.Text.Should().Contain("{{Unknown}}");
//     }
//
//     public void Dispose()
//     {
//         if (Directory.Exists(_contentRoot))
//         {
//             Directory.Delete(_contentRoot, true);
//         }
//     }
//
//     private WordAutomationService CreateService()
//     {
//         var options = Options.Create(new WordAutomationOptions
//         {
//             TemplatesDirectory = "Templates",
//             OutputDirectory = "Generated"
//         });
//
//         return new WordAutomationService(
//             NullLogger<WordAutomationService>.Instance,
//             options,
//             new FakeHostEnvironment(_contentRoot));
//     }
// }
