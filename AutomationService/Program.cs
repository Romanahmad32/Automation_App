using AutomationService.Features.WordAutomation.Presentation.DependencyInjection;
using Scalar.AspNetCore;

const string CorsPolicyName = "WordAutomationCors";
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddControllers();
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

builder.Services.AddWordServices(builder.Configuration);

var app = builder.Build();
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors(CorsPolicyName);
app.MapControllers();

app.Run();

public partial class Program;
