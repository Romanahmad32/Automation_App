#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Haelt das Setup der App von InitializeSetup bis zu seinem Ende
// (installer/setup.iss, SetupLaeuftMutex). InstallerVertragTests im Dienst
// prueft, dass hier und dort derselbe Name steht.
constexpr wchar_t kSetupLaeuftMutex[] = L"AutomationAppSetupLaeuft";

// Mit diesem Schalter startet das Setup die App selbst (beide [Run]-Eintraege
// in setup.iss). Dann lebt es noch und haelt den Mutex -- ohne den Schalter
// hielte die App ihren eigenen Neustart fuer ein laufendes Update.
constexpr char kNachUpdate[] = "--nach-update";

// Ob gerade ein Setup der App laeuft. Nur das Vorhandensein zaehlt; besitzen
// muss die App den Mutex nicht.
bool SetupLaeuft() {
  HANDLE mutex = ::OpenMutexW(SYNCHRONIZE, FALSE, kSetupLaeuftMutex);
  if (mutex != nullptr) {
    ::CloseHandle(mutex);
    return true;
  }
  // Ein Setup, das "Als Administrator" gestartet wurde, legt den Mutex mit
  // einer Zugriffsliste an, die diesem Prozess das Oeffnen verwehrt. Da ist er
  // trotzdem.
  return ::GetLastError() == ERROR_ACCESS_DENIED;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Startet der Anwender die App, waehrend das Setup sie ersetzt (#196), etwa
  // per Doppelklick, weil sie nach "Jetzt neu starten" verschwunden ist: Dann
  // uebernaehme sie einen Dienst, der gerade herunterfaehrt, oder startete
  // einen neuen, der den Dienst-Mutex wieder haelt -- und das Setup wartete
  // vergeblich. Stattdessen ein Hinweis, und nichts startet. Das Setup startet
  // die App danach selbst, mit --nach-update.
  const bool nach_update =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                kNachUpdate) != command_line_arguments.end();
  if (!nach_update && SetupLaeuft()) {
    ::MessageBoxW(nullptr,
                  L"Die Automation App wird gerade aktualisiert.\n\n"
                  L"Sie startet danach von selbst \u2013 bitte warten Sie "
                  L"einen Moment.",
                  L"Automation App", MB_OK | MB_ICONINFORMATION);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // lib/main.dart nimmt keine Argumente entgegen; --nach-update kommt dort
  // an und wird nicht gelesen.
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"automation_app", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
