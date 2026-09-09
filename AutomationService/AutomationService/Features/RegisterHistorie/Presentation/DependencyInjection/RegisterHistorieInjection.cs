using AutomationService.Features.RegisterHistorie.Domain.Services;

// Der Dienst heisst wie sein Slice, und der Slice ist von hier aus als
// Namespace sichtbar — ohne diesen Alias läse der Compiler "RegisterHistorie"
// als Namespace und nicht als Typ (CS0118).
using RegisterHistorieDienst = AutomationService.Features.RegisterHistorie.Domain.Services.RegisterHistorie;

namespace AutomationService.Features.RegisterHistorie.Presentation.DependencyInjection;

public static class RegisterHistorieInjection
{
    public static IServiceCollection AddRegisterHistorieServices(this IServiceCollection services)
    {
        services.AddScoped<IRegisterHistorie, RegisterHistorieDienst>();
        services.AddScoped<IRegisterImport, RegisterImport>();
        return services;
    }
}
