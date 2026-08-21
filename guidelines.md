# Flutter & Dart Guidelines

Rules for Claude Code (Desktop and CLI) when writing, testing, or running Dart
and Flutter code in this repository. Targets desktop, web, and mobile.

Precedence: these guidelines override default model behavior. When a rule here
conflicts with a generic best practice, follow the rule here. When a rule here
conflicts with an explicit user instruction in the conversation, follow the user.

## Working style

- Assume the user knows programming but may be new to Dart. Explain Dart-specific
  features when they appear: null safety, `Future`, `Stream`, pattern matching.
- Ask for clarification when a request is ambiguous about intended behavior or
  target platform (mobile, web, desktop, CLI).
- Explain the benefit of any new `pub.dev` dependency before adding it.
- Never add a state management, DI, or routing package that is not already listed
  in this document unless the user explicitly asks for it.

## Tooling

Prefer these tools over raw shell commands when available:

| Task            | Tool             | Fallback           |
|-----------------|------------------|--------------------|
| Format          | `dart_format`    | `dart format .`    |
| Auto-fix lints  | `dart_fix`       | `dart fix --apply` |
| Analyze         | `analyze_files`  | `dart analyze`     |
| Run tests       | `run_tests`      | `flutter test`     |
| Manage packages | `pub`            | see below          |
| Find packages   | `pub_dev_search` | pub.dev            |

Package commands when the `pub` tool is unavailable:

```shell
flutter pub add <package>                        # dependency
flutter pub add dev:<package>                    # dev dependency
flutter pub add override:<package>:1.0.0         # override
dart pub remove <package>                        # remove
```

With the `pub` tool, pass the same `dev:` / `override:` prefixes.

Run `dart_format`, `dart_fix`, and `analyze_files` before reporting work complete.

## Project structure

- Standard Flutter layout. `lib/main.dart` is the entry point.
- Organize into logical layers:
  - **Presentation** — widgets, screens
  - **Domain** — business logic classes
  - **Data** — models, repositories, API clients
  - **Core** — shared utilities, extension types, `Result`, `Command`
- For anything beyond a small app, organize by feature first: each feature owns
  its own `presentation/`, `domain/`, and `data/` subfolders.
- Group related libraries in the same folder. Define related classes in the same
  library file; for large libraries, export smaller private libraries from one
  top-level library.

## Architecture

- Separate concerns along MVC/MVVM lines with defined Model, View, and
  ViewModel/Controller roles.
- Apply SOLID principles.
- Favor composition over inheritance.
- Prefer immutable data structures. Widgets, especially `StatelessWidget`, are
  immutable.
- Abstract data sources (API calls, database operations) behind
  Repositories/Services so they can be faked in tests.
- Define explicit data classes for the data the app handles.
- **Dependency injection:** use manual constructor injection so dependencies are
  explicit in the API. Do **not** use `Riverpod`, `GetX`, or `GetIt` unless
  explicitly requested. If injection beyond constructors is explicitly requested,
  `provider` is the accepted option.

## Error handling: the Result pattern

**Always use a functional return pattern for internal expressions.** A function
that wraps a fallible call (native method, I/O, network) catches the error
internally and returns a typed `Result<T, Failure>` — never lets the exception
escape to the caller or the UI layer.

The canonical implementation lives in `lib/core/result/` as `result.dart`,
`failure.dart`, and `success.dart`. Treat it as a starting point that may grow
new features; do not replace it with a third-party alternative such as
`dartz` or `fpdart`.

Required shape:

```dart
// result.dart
library;

part 'failure.dart';
part 'success.dart';

/// A callback function that takes a result and returns a value.
typedef ResultCallback<T, R> = T Function(R result);

/// Represents an operation that may either succeed or fail.
abstract interface class Result<T, S extends Failure> {
  const factory Result.failure(S failure) = _FailureResult<T, S>;
  const factory Result.success(T value) = _SuccessResult<T, S>;

  /// Deconstructs the [Result] using the provided callbacks.
  R fold<R>({
    required ResultCallback<R, S> onFailure,
    required ResultCallback<R, Success<T>> onSuccess,
  });

  /// Deconstructs the [Result], returning the value if successful, or `null`
  /// if the operation fails.
  T? tryFold({required ResultCallback<T?, Success<T>> onSuccess});

  bool get isFailure;
  bool get isSuccess;

  /// Throws [NotFailureException] if the [Result] is a success.
  S get failure;

  /// Throws [NotSuccessException] if the [Result] is a failure.
  Success<T> get success;
}
```

```dart
// failure.dart — part of 'result.dart'
/// Higher-order abstraction for failures. Implementers must expose a brief
/// [message] and, optionally, longer [details].
abstract interface class Failure implements Exception {
  const factory Failure({required String message, String? details}) = _Failure;

  String get message;
  String? get details;
}
```

```dart
// success.dart — part of 'result.dart'
/// A generic success carrying a value of type [T].
abstract interface class Success<T> {
  const factory Success(T value) = _Success<T>;

  T get value;
}

/// Specialization for operations that return nothing.
final class VoidSuccess implements Success<void> {
  const VoidSuccess();

  @override
  void get value => {};
}
```

`_FailureResult`, `_SuccessResult`, `_Failure`, and `_Success` are the private
implementations; `NotFailureException` and `NotSuccessException` are thrown when
the wrong accessor is used. Define custom `Failure` subtypes per domain instead
of reusing the default `Failure` everywhere.

Usage:

```dart
Future<Result<User, Failure>> getUser(String id) async {
  try {
    return Result.success(await _api.fetchUser(id));
  } on SocketException catch (e) {
    return Result.failure(NetworkFailure(message: 'Offline', details: '$e'));
  }
}
```

## State management

- Prefer Flutter's built-in solutions. Do not reach for a third-party package
  unless the situation below calls for it or the user asks.
- `Stream` + `StreamBuilder` for sequences of asynchronous events.
- `Future` + `FutureBuilder` for a single asynchronous operation.
- `ValueNotifier` + `ValueListenableBuilder` for simple, local, single-value state.

  ```dart
  final ValueNotifier<int> _counter = ValueNotifier<int>(0);

  ValueListenableBuilder<int>(
    valueListenable: _counter,
    builder: (context, value, child) => Text('Count: $value'),
  );
  ```

- **BLoC / Cubit:** for state that is complex or shared across widgets. Use
  `BLoC` for very complex state, `Cubit` for everything else.
- Pick the right listener for the job:
  - `BlocBuilder<Event, State>` — rebuild widgets.
  - `BlocListener<Event, State>` — react without rebuilding (SnackBars, logging).
  - `BlocConsumer<Event, State>` — react **and** rebuild.
- Separate ephemeral state from app state.

### MVVM and the Command pattern

When a more robust structure is needed, use MVVM, and always pair it with
BLoC/Cubit. Wrap each ViewModel action in a `Command` — a `Cubit` that tracks one
action's lifecycle, prevents concurrent execution, and surfaces a `Result`.

```dart
// lib/core/command/command.dart
typedef CommandAction0<T> = Future<Result<T, Failure>> Function();
typedef CommandAction1<T, A> = Future<Result<T, Failure>> Function(A);

/// The base state for a [Command] execution lifecycle.
sealed class CommandState<T> {
  const CommandState();
}

final class CommandInitial<T> implements CommandState<T> {
  const CommandInitial();
}

/// Emitted while the action runs. Use it to show loaders and disable input.
final class CommandLoading<T> implements CommandState<T> {
  const CommandLoading();
}

/// Emitted when the action finishes, carrying its [result].
final class CommandCompleted<T> implements CommandState<T> {
  const CommandCompleted(this.result);

  final Result<T, Failure> result;
}

/// Encapsulates an asynchronous action, managing its state transitions and
/// rejecting re-entrant execution.
abstract class Command<T> extends Cubit<CommandState<T>> {
  Command() : super(const CommandInitial());

  Future<void> _execute(CommandAction0<T> action) async {
    if (state is CommandLoading<T> || isClosed) {
      return;
    }

    emit(const CommandLoading());

    final result = await action();

    emit(CommandCompleted(result));
    return;
  }
}

/// For actions that take no arguments.
class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  Future<void> execute() async {
    await _execute(_action);
  }
}

/// For actions that take a single argument of type [A].
class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  Future<void> execute(A argument) async {
    await _execute(() => _action(argument));
  }
}
```

```dart
final fetchUserCommand = Command0<User>(() => userRepository.getUser());
await fetchUserCommand.execute();

final deleteItemCommand = Command1<void, String>(repository.delete);
await deleteItemCommand.execute('item_123');
```

## Dart style

- Follow [Effective Dart](https://dart.dev/effective-dart).
- `PascalCase` for classes, `camelCase` for members, variables, functions, and
  enums, `snake_case` for files.
- Lines of 80 characters or fewer.
- Functions do one thing and stay short — aim for under 20 lines.
- Avoid abbreviations. Use meaningful, consistent, descriptive names.
- Write the shortest code that is still clear. Clever or obscure code is a defect.
- Be soundly null-safe. Avoid `!` unless the value is guaranteed non-null.
- Use `async`/`await` for asynchronous work, with real error handling. Use
  `Stream` for sequences of asynchronous events.
- Use pattern matching where it simplifies the code.
- Use records to return multiple values when a whole class would be overkill.
- Prefer exhaustive `switch` statements and expressions — no `break` needed.
- Use `try-catch` with exceptions appropriate to the situation, and define custom
  exceptions for domain-specific cases. Wrap the result in `Result` (see above).
- Use arrow syntax for simple one-line functions.
- Anticipate and handle errors. Never fail silently.
- Design for testability: depend on the `file`, `process`, and `platform`
  packages where relevant so in-memory and fake implementations can be injected.

## Flutter widgets and performance

- Compose small, reusable widgets rather than extending existing ones; this also
  keeps the tree shallow.
- Use small **private `Widget` classes**, not private helper methods that return
  a `Widget`.
- Break large `build()` methods into those private widget classes.
- Use `const` constructors in widgets and `build()` methods wherever possible.
- Never do expensive work — network calls, heavy computation — inside `build()`.
- Use `ListView.builder` or `SliverList` for long lists.
- Use `compute()` to move expensive work such as JSON parsing off the UI isolate.

## Routing

- Use `go_router` for declarative navigation, deep linking, and web support.
  `auto_route` is the acceptable alternative when the user prefers it.

  ```dart
  final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'details/:id',
            builder: (context, state) {
              final String id = state.pathParameters['id']!;
              return DetailScreen(id: id);
            },
          ),
        ],
      ),
    ],
  );

  MaterialApp.router(routerConfig: _router);
  ```

- Handle auth flows with `go_router`'s `redirect`: send unauthorized users to
  login, then back to their intended destination.
- Use the built-in `Navigator` for short-lived, non-deep-linkable screens such as
  dialogs and temporary views.

## Data handling and serialization

- Use `json_serializable` + `json_annotation`.
- Use `fieldRename: FieldRename.snake` so Dart camelCase maps to snake_case keys.

  ```dart
  @JsonSerializable(fieldRename: FieldRename.snake)
  class User {
    User({required this.firstName, required this.lastName});

    factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

    final String firstName;
    final String lastName;

    Map<String, dynamic> toJson() => _$UserToJson(this);
  }
  ```

## Logging

Use `log` from `dart:developer` for structured logging that reaches DevTools.
Never use `print`.

```dart
import 'dart:developer' as developer;

developer.log('User logged in successfully.');

try {
  // ...
} catch (e, s) {
  developer.log(
    'Failed to fetch data',
    name: 'myapp.network',
    level: 1000, // SEVERE
    error: e,
    stackTrace: s,
  );
}
```

## Code generation

- Keep `build_runner` as a dev dependency whenever generation is used.
- Use `build_runner` for all generation tasks, including `json_serializable`.
- After editing generated-code sources, run:

  ```shell
  dart run build_runner build --delete-conflicting-outputs
  ```

## Testing

- Unit tests with `package:test`; widget tests with `package:flutter_test`;
  integration tests with `package:integration_test` (added as a `dev_dependency`
  with `sdk: flutter`).
- Prefer `package:checks` over the default matchers for assertions.
- Follow Arrange-Act-Assert (Given-When-Then).
- Cover domain logic, the data layer, and state management with unit tests; UI
  components with widget tests; end-to-end user flows with integration tests.
- Prefer fakes or stubs over mocks. If mocks are unavoidable use `mockito` or
  `mocktail`, and avoid code generation for them.
- Aim for high coverage.

## Analysis options

Start from this `analysis_options.yaml` and keep it in sync:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**.freezed.dart"
    - "**.g.dart"
    - "**/generated_plugin_registrant.dart"
    - lib/l10n/app_localizations*.dart
    - "**/build/*"
  errors:
    directives_ordering: error
    prefer_single_quotes: error
    always_declare_return_types: error
    invalid_annotation_target: ignore

formatter:
  page_width: 80
  trailing_commas: preserve

linter:
  rules:
    ## ERROR RULES
    avoid_dynamic_calls: true
    avoid_slow_async_io: true
    avoid_type_to_string: true
    avoid_web_libraries_in_flutter: true
    cancel_subscriptions: true
    close_sinks: true
    comment_references: true
    deprecated_member_use_from_same_package: true
    discarded_futures: false
    invalid_case_patterns: true
    literal_only_boolean_expressions: true
    no_self_assignments: true
    prefer_relative_imports: false
    prefer_void_to_null: true
    throw_in_finally: true
    unnecessary_statements: true

    ## STYLES RULES
    always_declare_return_types: true
    always_put_required_named_parameters_first: true
    avoid_annotating_with_dynamic: false
    avoid_bool_literals_in_conditional_expressions: true
    avoid_catching_errors: true
    avoid_classes_with_only_static_members: true
    avoid_double_and_int_checks: true
    avoid_equals_and_hash_code_on_mutable_classes: true
    avoid_implementing_value_types: true
    avoid_multiple_declarations_per_line: true
    avoid_private_typedef_functions: true
    avoid_redundant_argument_values: true
    avoid_void_async: false
    cast_nullable_to_non_nullable: true
    combinators_ordering: true
    directives_ordering: true
    eol_at_end_of_file: true
    lines_longer_than_80_chars: false
    matching_super_parameters: true
    no_literal_bool_comparisons: true
    one_member_abstracts: true
    only_throw_errors: true
    prefer_expression_function_bodies: true
    prefer_final_locals: true
    prefer_if_elements_to_conditional_expressions: true
    prefer_int_literals: true
    prefer_mixin: true
    prefer_null_aware_method_calls: true
    prefer_single_quotes: true
    require_trailing_commas: false
    sized_box_shrink_expand: true
    sort_constructors_first: true
    sort_unnamed_constructors_first: true
    type_annotate_public_apis: true
    unawaited_futures: true
    unnecessary_await_in_return: true
    unnecessary_breaks: true
    unnecessary_null_checks: true
    unnecessary_parenthesis: true
    unnecessary_raw_strings: true
    unreachable_from_main: true
    use_colored_box: true
    use_decorated_box: true
    use_enums: true
    use_is_even_rather_than_modulo: true
    use_named_constants: true
    use_raw_strings: true
    use_test_throws_matchers: true
    unnecessary_const: true
    prefer_const_constructors: true
    prefer_const_declarations: true

    ## PUB RULES
    sort_pub_dependencies: true
```

## Theming

- Define one centralized `ThemeData`. Supply both `theme` and `darkTheme` to
  `MaterialApp`, and drive `themeMode` so the user can pick light, dark, or
  system.
- Generate palettes with `ColorScheme.fromSeed()` for both brightnesses.
- Centralize component styles (`appBarTheme`, `elevatedButtonTheme`, `cardTheme`)
  inside `ThemeData` rather than styling widgets one by one.
- Use `google_fonts` for custom fonts, applied through a `TextTheme`.

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  ),
  home: const MyHomePage(),
);
```

### Design tokens with `ThemeExtension`

For custom styles outside standard `ThemeData`, define a `ThemeExtension<T>`,
implement `copyWith` and `lerp`, register it in `ThemeData.extensions`, and read
it with `Theme.of(context).extension<MyColors>()!`.

```dart
@immutable
class MyColors extends ThemeExtension<MyColors> {
  const MyColors({required this.success, required this.danger});

  final Color? success;
  final Color? danger;

  @override
  ThemeExtension<MyColors> copyWith({Color? success, Color? danger}) =>
      MyColors(success: success ?? this.success, danger: danger ?? this.danger);

  @override
  ThemeExtension<MyColors> lerp(ThemeExtension<MyColors>? other, double t) {
    if (other is! MyColors) return this;
    return MyColors(
      success: Color.lerp(success, other.success, t),
      danger: Color.lerp(danger, other.danger, t),
    );
  }
}
```

### State-dependent styling

Use `WidgetStateProperty.resolveWith` when the value depends on state, and
`WidgetStateProperty.all` when it does not.

```dart
final ButtonStyle myButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith<Color>(
    (Set<WidgetState> states) =>
        states.contains(WidgetState.pressed) ? Colors.green : Colors.red,
  ),
);
```

## Layout

- **Rows and columns:** `Expanded` to fill remaining main-axis space, `Flexible`
  to shrink without growing, `Wrap` to flow onto the next line. Do not mix
  `Flexible` and `Expanded` in the same `Row` or `Column`.
- **General content:** `SingleChildScrollView` for fixed-size content larger than
  the viewport; `.builder` constructors of `ListView`/`GridView` for long lists;
  `FittedBox` to scale a single child; `LayoutBuilder` for responsive decisions
  based on available space.
- **Stacks:** `Positioned` to anchor to edges, `Align` for alignment-based
  placement.
- **Overlays:** use `OverlayPortal` for dropdowns and tooltips — it manages the
  `OverlayEntry` for you.

  ```dart
  class _MyDropdownState extends State<MyDropdown> {
    final _controller = OverlayPortalController();

    @override
    Widget build(BuildContext context) => OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (BuildContext context) => const Positioned(
        top: 50,
        left: 10,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('I am an overlay!'),
          ),
        ),
      ),
      child: ElevatedButton(
        onPressed: _controller.toggle,
        child: const Text('Toggle Overlay'),
      ),
    );
  }
  ```

- Use `LayoutBuilder` or `MediaQuery` for responsive UIs; the app must work on
  mobile and web.
- Read text styles from `Theme.of(context).textTheme`.
- Configure `textCapitalization`, `keyboardType`, and placeholder text on text
  fields.

## Visual design

- Build interfaces that follow modern design guidelines and are genuinely usable.
- Provide obvious navigation controls when there is more than one page.
- Use typographic contrast — hero text, section headlines, list headlines,
  emphasized keywords — to make structure readable at a glance.
- Apply a subtle noise texture to the main background for a premium, tactile feel.
- Use multi-layered drop shadows for depth; cards get a soft, deep shadow so they
  read as lifted.
- Use icons to reinforce meaning and navigation.
- Give interactive elements — buttons, checkboxes, sliders, lists, charts — a
  shadow with tasteful color for a subtle glow.

### Color

- Meet WCAG 2.1: at least **4.5:1** contrast for normal text, **3:1** for large
  text (18pt, or 14pt bold).
- Define a clear primary / secondary / accent hierarchy and follow the 60-30-10
  rule: 60% dominant neutral or primary, 30% secondary, 10% accent.
- Use complementary colors for accents only. They cause eye strain as text and
  background pairings.
- Include a wide range of concentrations and hues for a vibrant palette.

Reference palette:

| Role | Hex |
| --- | --- |
| Primary | `#0D47A1` |
| Secondary | `#1976D2` |
| Accent | `#FFC107` |
| Neutral / Text | `#212121` |
| Background | `#FEFEFE` |

### Typography

- Limit the app to one or two font families. Prefer legible sans-serif faces for
  UI body text; system fonts are a valid choice. Use `google_fonts` otherwise.
- Establish an explicit type scale and differentiate with weight, color, and
  opacity rather than size alone.
- Line height 1.4x-1.6x the font size; body line length 45-75 characters.
- Never set long-form text in all caps.

```dart
textTheme: const TextTheme(
  displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold),
  titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
  bodyLarge: TextStyle(fontSize: 16.0, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14.0, height: 1.4),
  labelSmall: TextStyle(fontSize: 11.0, color: Colors.grey),
),
```

## Assets and images

- Declare every asset path in `pubspec.yaml`.

  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - assets/images/
  ```

- `Image.asset` for bundled images, `NetworkImage`/`Image.network` for remote
  ones, `cached_network_image` when caching matters, `ImageIcon` for custom icons
  from an `ImageProvider`.
- Always give network images a `loadingBuilder` and an `errorBuilder`.

  ```dart
  Image.network(
    'https://picsum.photos/200/300',
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
  )
  ```

- Images must be relevant, appropriately sized, and appropriately licensed. Use
  placeholders when real assets are unavailable.

## API design

When building reusable APIs such as a library:

- Design from the perspective of the caller. The API must be intuitive and hard
  to misuse.
- Treat documentation as part of the design. Make it clear, concise, and
  example-driven.

## Documentation

- Write `dartdoc` (`///`) comments for all public APIs — classes, constructors,
  methods, and top-level functions. Documenting private APIs is encouraged.
- Open with a single-sentence, user-centric summary ending in a period, then a
  blank line before the rest.
- Explain **why**, not what. The code already says what it does.
- Document parameters, return values, and thrown exceptions in prose. Include
  code samples where they help.
- Consider a library-level doc comment for an overview.
- Place doc comments **before** annotations.
- Do not document both a getter and its setter — document one.
- Do not restate the obvious from a name or signature; that is noise.
- Do not add trailing comments.
- Be brief, avoid jargon and unexplained acronyms, use consistent terminology.
- Use Markdown sparingly and never HTML. Fence code and specify the language.

## Accessibility

Assume a wide range of physical and mental abilities, ages, education levels, and
learning styles.

- Maintain at least 4.5:1 text contrast.
- Keep the UI usable when the system font size is increased.
- Provide clear labels through the `Semantics` widget.
- Test with TalkBack (Android) and VoiceOver (iOS).
