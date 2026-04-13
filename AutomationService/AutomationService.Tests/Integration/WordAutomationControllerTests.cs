// using System.Net;
// using System.Net.Http.Json;
// using AutomationService.Features.WordAutomation.Presentation.Dtos;
// using FluentAssertions;
// using Microsoft.AspNetCore.Mvc.Testing;
// using Microsoft.Extensions.Configuration;
//
// namespace AutomationService.Tests.Integration;
//
// public class WordAutomationControllerTests : IClassFixture<WebApplicationFactory<Program>>
// {
//     private readonly WebApplicationFactory<Program> _factory;
//
//     public WordAutomationControllerTests(WebApplicationFactory<Program> factory)
//     {
//         _factory = factory.WithWebHostBuilder(builder =>
//         {
//             builder.ConfigureAppConfiguration((_, configBuilder) =>
//             {
//                 configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
//                 {
//                     ["WordAutomation:TemplatesDirectory"] = "Templates",
//                     ["WordAutomation:OutputDirectory"] = "Generated"
//                 });
//             });
//         });
//     }
//
//     [Fact]
//     public async Task GenerateReplacedDocument_WithInvalidPayload_ReturnsBadRequest()
//     {
//         var client = _factory.CreateClient();
//         var payload = new WordReplacementDto
//         {
//             FileName = "../../evil",
//             ReplacePatterns = new Dictionary<string, string>()
//         };
//
//         var response = await client.PostAsJsonAsync("/api/WordAutomation/replaced-document", payload);
//
//         response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
//         var body = await response.Content.ReadFromJsonAsync<ReplacedDocumentResponseDto>();
//         body.Should().NotBeNull();
//         body!.ErrorCode.Should().Be("validation_failed");
//         body.Success.Should().BeFalse();
//     }
//
//     [Fact]
//     public async Task GenerateReplacedDocument_WhenTemplateIsMissing_ReturnsNotFound()
//     {
//         var client = _factory.CreateClient();
//         var payload = new WordReplacementDto
//         {
//             FileName = "NotExistingTemplate",
//             ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
//         };
//
//         var response = await client.PostAsJsonAsync("/api/WordAutomation/replaced-document", payload);
//
//         response.StatusCode.Should().Be(HttpStatusCode.NotFound);
//         var body = await response.Content.ReadFromJsonAsync<ReplacedDocumentResponseDto>();
//         body.Should().NotBeNull();
//         body!.ErrorCode.Should().Be("template_not_found");
//         body.Success.Should().BeFalse();
//     }
// }
