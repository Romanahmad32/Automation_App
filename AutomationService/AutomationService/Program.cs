using AutomationService.Core.Lifetime;
using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Presentation.DependencyInjection;
using AutomationService.Features.DevSimulation.Presentation.DependencyInjection;
using AutomationService.Features.FormTemplates.Presentation.DependencyInjection;
using AutomationService.Features.MailboxMonitor.Presentation.DependencyInjection;
using AutomationService.Features.MailboxMonitor.Presentation.Hubs;
using AutomationService.Features.Mandanten.Presentation.DependencyInjection;
using AutomationService.Features.PdfConversion.Presentation.DependencyInjection;
using AutomationService.Features.Settings.Presentation.DependencyInjection;
using AutomationService.Features.Versicherer.Presentation.DependencyInjection;
using AutomationService.Features.Vorgaenge.Presentation.DependencyInjection;
using AutomationService.Features.WordAutomation.Presentation.DependencyInjection;
using AutomationService.Features.ZentralrufAutomation.Presentation.DependencyInjection;
using Scalar.AspNetCore;

const string CorsPolicyName = "WordAutomationCors";
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policyBuilder =>
    {
        var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        if (builder.Environment.IsDevelopment())
        {
            policyBuilder.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin();
            return;
        }

        if (allowedOrigins.Length > 0)
        {
            policyBuilder.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

builder.Services.AddLifetimeServices(builder.Configuration);
builder.Services.AddPersistenceServices();
builder.Services.AddWordServices(builder.Configuration);
builder.Services.AddPdfConversionServices(builder.Configuration);
builder.Services.AddZentralrufServices(builder.Configuration);
builder.Services.AddMailboxServices(builder.Configuration);
builder.Services.AddSettingsServices();
builder.Services.AddMandantenServices();
builder.Services.AddVersichererServices();
builder.Services.AddVorgaengeServices();
builder.Services.AddFormTemplatesServices();
builder.Services.AddBackupServices();
builder.Services.AddDevSimulationServices(builder.Configuration);

var app = builder.Build();
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Kein UseHttpsRedirection: Der Dienst spricht bewusst nur lokales HTTP (localhost:5143);
// ohne konfigurierten HTTPS-Endpunkt erzeugte die Middleware nur die Warnung
// "Failed to determine the https port for redirect".
app.UseCors(CorsPolicyName);
app.MapHealthEndpoint();
app.MapControllers();
app.MapHub<MailboxHub>("/hubs/mailbox");

app.Run();

public partial class Program;
