import 'package:automation_app/core/general_widgets/form/feld_schluessel.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Reaktives Textfeld auf `material_ui` — Ersatz für `ReactiveTextField`.
///
/// **Warum es das gibt:** reactive_forms (18.2.x) baut sein `ReactiveTextField`
/// noch auf dem alten Material aus dem Flutter-SDK. Unter dem
/// `material_ui`-`Scaffold` fehlt dieses alte `Material`, das Feld scheitert
/// mit „No Material widget found.". Außerdem übernähme es das
/// `inputDecorationTheme` der App nicht — `filled`, `fillColor`,
/// `contentPadding` und die Rahmen gingen in jedem Formularfeld verloren.
///
/// Gebaut wie `ReactiveTextField` selbst, nur mit dem `TextField` aus
/// `material_ui`; die Theme-Dekoration wird wie dort per `applyDefaults` mit
/// dem `inputDecorationTheme` des umgebenden Themes angewandt. Fehlertexte
/// kommen aus `validationMessages` und erscheinen erst, wenn das Control
/// berührt wurde (`showErrors`-Vorgabe von reactive_forms).
///
/// Nicht alle Parameter von `ReactiveTextField` sind durchgereicht: Bewusst
/// fehlen u. a. `readOnly`, `textInputAction`, `autofocus`, `onSubmitted` und
/// `style`; sie werden bei Bedarf ergänzt.
///
/// Weggelassen ist der Zweig für `TimeOfDay`: Das wäre der alte Material-Typ,
/// und die App nutzt ihn nicht. Zieht reactive_forms später auf `material_ui`
/// um, kann dieses Feld wieder durch `ReactiveTextField` ersetzt werden.
class ReactiveTextEingabe<T> extends ReactiveFocusableFormField<T, String> {
  ReactiveTextEingabe({
    super.key,
    super.formControlName,
    super.formControl,
    super.validationMessages,
    super.valueAccessor,
    super.showErrors,
    super.focusNode,
    InputDecoration decoration = const InputDecoration(),
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    bool obscureText = false,
    ReactiveFormFieldCallback<T>? onChanged,
  }) : super(
         builder: (field) {
           final state = field as ReactiveTextEingabeState<T>;
           final wirksam = decoration.applyDefaults(
             Theme.of(state.context).inputDecorationTheme,
           );
           return TextField(
             // Jedes benannte Feld ist ansprechbar, auch wenn es leer ist.
             key: FeldSchluessel.fuer(formControlName),
             controller: state.textController,
             focusNode: state.focusNode,
             decoration: wirksam.copyWith(errorText: state.errorText),
             keyboardType: keyboardType,
             inputFormatters: inputFormatters,
             maxLines: maxLines,
             obscureText: obscureText,
             enabled: field.control.enabled,
             onChanged: (wert) {
               field.didChange(wert);
               onChanged?.call(field.control);
             },
           );
         },
       );

  @override
  ReactiveFormFieldState<T, String> createState() =>
      ReactiveTextEingabeState<T>();
}

/// Zustand von [ReactiveTextEingabe]: hält den `TextEditingController` und
/// gleicht ihn mit dem Wert des Controls ab.
class ReactiveTextEingabeState<T>
    extends ReactiveFocusableFormFieldState<T, String> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: value?.toString() ?? '');
  }

  @override
  void onControlValueChanged(dynamic value) {
    final text = value == null ? '' : value.toString();
    textController.value = textController.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    super.onControlValueChanged(value);
  }

  @override
  ControlValueAccessor<T, String> selectValueAccessor() {
    if (control is FormControl<int>) {
      return IntValueAccessor() as ControlValueAccessor<T, String>;
    } else if (control is FormControl<double>) {
      return DoubleValueAccessor() as ControlValueAccessor<T, String>;
    } else if (control is FormControl<DateTime>) {
      return DateTimeValueAccessor() as ControlValueAccessor<T, String>;
    }
    return super.selectValueAccessor();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}
