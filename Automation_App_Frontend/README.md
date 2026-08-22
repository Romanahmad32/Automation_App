# automation_app — Flutter frontend

The desktop frontend of the Office Automation App. It holds no local
persistence of its own: every store goes through the backend in
[`../AutomationService`](../AutomationService) over HTTP.

Project overview, screenshots and architecture: **[../README.md](../README.md)**

```powershell
flutter pub get
dart run build_runner build
flutter run -d windows
flutter test
flutter analyze
```

Files ending in `.g.dart`, `.freezed.dart`, `.gr.dart` and
`injection.config.dart` are generated — never edit them by hand, run
build_runner instead.
