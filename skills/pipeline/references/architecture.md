# Архитектура и пакеты

Это закон для всех стадий: контракты (4), слайс (5), задачи (6), реализация (7), аудит (8).
В проекте, где код уже есть, закон — для нового кода; старый под него не переделывается
без просьбы пользователя.
Платформы: **iOS, Android, Web** — всё ниже должно работать на всех трёх.
Отступление от него — только по решению пользователя, с записью в `decisions.md`.

---

## Структура

```
lib
 ┣ app
 ┃ ┣ di                           # GetIt + injectable
 ┃ ┣ router
 ┃ ┃ ┗ app_router.dart            # AutoRouter
 ┃ ┣ theme
 ┃ ┃ ┣ app_colors.dart            # статичные поля: seedColor и дополнительные цвета
 ┃ ┃ ┣ app_theme.dart             # сборка темы
 ┃ ┃ ┣ colors_manager.dart        # цветовая схема по seed
 ┃ ┃ ┗ glass_manager.dart         # жидкое стекло
 ┃ ┗ <app_name>_app.dart          # корневой виджет приложения
 ┣ l10n                           # ARB-файлы (intl + gen-l10n)
 ┣ core
 ┃ ┣ config
 ┃ ┃ ┗ app_config.dart            # константы конфигурации (фаза 2)
 ┃ ┣ logger                       # Talker, логгеры пакетов, наблюдатель навигации
 ┃ ┣ network
 ┃ ┃ ┣ dio_client.dart
 ┃ ┃ ┗ api_interceptors.dart
 ┃ ┣ storage                      # Hive CE (данные), shared_preferences (настройки)
 ┃ ┗ widgets                      # общие виджеты
 ┣ features
 ┃ ┣ home                         # родительский route
 ┃ ┗ <feature>
 ┃   ┣ data
 ┃   ┃ ┣ api                      # Retrofit-клиенты
 ┃   ┃ ┣ models                   # модели; json_serializable — с фазы 2
 ┃   ┃ ┗ repositories
 ┃   ┣ presentation
 ┃   ┃ ┣ cubit                    # бизнес-логика
 ┃   ┃ ┣ pages
 ┃   ┃ ┃ ┗ pages.dart             # barrel
 ┃   ┃ ┗ widgets
 ┃   ┃   ┗ widgets.dart           # barrel, используется только в pages этой фичи
 ┃   ┗ <feature>.dart             # barrel: страницы и логика, нужные снаружи
 ┗ main.dart
```

Один файл — один класс (подробно — «Стиль кода» в SKILL.md): у каждого виджета, Cubit,
репозитория своё имя файла. Состояния Cubit — в одном файле, мелкие модели фичи — можно в одном.

## Правила слоёв

Поток зависимостей — только сверху вниз:

```
pages / widgets → cubit → repositories → api (Retrofit) / core/storage (Hive)
```

- **Cubit** знает только репозитории своей фичи. Dio, Retrofit, Hive и DTO ему не видны.
- **Репозиторий** — единственное место, где встречаются API и хранилище. Он ловит
  `DioException` и ошибки хранилища и превращает их в ошибки фичи (`sealed class`).
  Наверх `DioException` не уходит.
- **Страница** получает Cubit из DI, рисует его состояния. Логики в виджетах нет:
  условие сложнее «какое состояние показать» — это Cubit.
- **Виджеты фичи** лежат в `presentation/widgets`, экспортируются через `widgets.dart`
  и используются **только** страницами этой фичи. Нужен в двух фичах — переезжает
  в `core/widgets`.
- **Между фичами** — только через barrel `<feature>.dart`. Импорт внутренностей чужой
  фичи (`features/x/data/...`) запрещён.
- Новая страница — экспорт в `pages.dart`; новый виджет фичи — экспорт в `widgets.dart`.

## Фундамент — до любого функционала

Собирается первым шагом фазы 1, в этом порядке. Пока не собран и не проверен
пользователем — экранов с функционалом нет.

1. **Тема** — `app/theme`, светлая и тёмная (см. «Тема» ниже).
2. **Навигация** — `app/router`, auto_route, `home` — родительский route.
3. **Локализация** — intl + gen-l10n, ARB в `lib/l10n` (см. «Локализация»).
4. **DI** — `app/di`, get_it + injectable.
5. **Логи** — `core/logger`, Talker.

`core/network` (Dio), Hive и `core/config` — фаза 2. `shared_preferences` можно
с фазы 1 — например, для выбранной темы.

## Корневой виджет — `<app_name>_app.dart`

Образец:

```dart
class SpendyHolikApp extends StatefulWidget {
  const SpendyHolikApp({super.key});

  @override
  State<SpendyHolikApp> createState() => _SpendyHolikAppState();
}

class _SpendyHolikAppState extends State<SpendyHolikApp> {
  late final _routerConfig = getIt<AppRouter>().config(
    navigatorObservers: () => [TalkerAutoRouteObserver(getIt<Talker>())],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      builder: (_, child) => Material(type: .transparency, child: child),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizationsSetup.delegates,
      supportedLocales: AppLocalizationsSetup.supportedLocales,
      localeListResolutionCallback: AppLocalizationsSetup.resolve,
      routerConfig: _routerConfig,
    );
  }
}
```

- **`builder: (_, child) => Material(type: .transparency, child: child)` обязателен.**
  Без `Material` над деревом текст внутри стекла рисуется жёлтым с красным подчёркиванием.
  Делается **один раз** здесь; в виджетах стекла `Material` не дублируется.
- Наблюдатель навигации Talker подключается здесь же.

## Фазы и данные

- **Фаза 1.** Модели — простые классы в `data/models`. Интерфейс репозитория —
  в `data/repositories`, рядом — фейковая реализация с захардкоженными данными,
  зарегистрированная в DI под интерфейс. Cubit зависит только от интерфейса.
- **Фаза 2.** Реальная реализация того же интерфейса через Retrofit и Hive, в DI
  регистрируется она. Фейк удаляется, если пользователь не решил оставить его.
  Модели получают `json_serializable`.

## Тема

- **Цвета — flex_color_scheme.** Схема строится по `seedColor` из `AppColors` в
  `colors_manager.dart`. **Фоновые и surface-цвета нейтральные**: без подмешивания
  seed-цвета, белый/серый/чёрный. Seed-цвет — только на акцентах: кнопки, активные
  элементы, выделение. Подбирай настройки flex_color_scheme под это по его документации.
- Тема собирается в `app_theme.dart`, светлая и тёмная, обе проверяются вручную.
- **Макет в режиме «строго»** задаёт цвета, в том числе фоновые: правило нейтрального фона
  уступает макету. Цвета макета всё равно заводятся в `AppColors` и схему, не хардкодом.
- **Шрифты** — из `brief.md`. Подключаются в теме (`textTheme`), не в виджетах.
- **Жидкое стекло — для шапок и меню**: app bar, нижняя и боковая навигация, меню,
  выпадающие панели. Контент и карточки — не стекло.
- **Кнопки внутри шапок — тоже стеклянные** (это правило дизайна): обычная кнопка
  Material в стеклянной шапке — дефект. Стекло — через `glass_manager.dart`,
  который оборачивает `liquid_glass_widgets`; фичи пакет напрямую не используют.
- `liquid_glass_widgets` используешь **так, как в его документации**. Перед первым
  использованием в проекте прочитай документацию пакета (pub.dev / репозиторий), не по памяти.
  Под стеклом должен быть прокручиваемый контент — иначе эффекта не видно.
- Цвета в виджетах — только из `Theme.of(context).colorScheme` и `AppColors`.
  Захардкоженный `Color(0xFF...)` в фиче — дефект.

## Адаптивность и отзывчивость

- **Адаптивность.** Каждый экран с первого раза работает на узком (телефон) и широком
  (планшет, окно браузера) экране. Брейкпоинты задаются в одном месте и фиксируются
  в контрактах фазы 1; от ширины зависят раскладка и тип навигации. Раскладка строится
  от доступной ширины (`LayoutBuilder`, `MediaQuery.sizeOf`), а не от платформы.
- **Отзывчивость.** Нажатие даёт видимую реакцию сразу. Загрузка — shimmer-скелетон.
  Долгие операции не блокируют UI. Списки — `ListView.builder` / `GridView.builder`.
- **Web.** В общем коде нет `dart:io` (`Platform.isIOS` на Web падает) — для проверки
  платформы `kIsWeb` и `defaultTargetPlatform`. Ввод мышью и клавиатурой тоже
  работает: hover, прокрутка колесом, Tab.

## Локализация

- **intl + gen-l10n.** ARB-файлы в `lib/l10n`, основной язык — по `brief.md`.
- Все строки UI — из ARB. Захардкоженная строка в виджете — дефект. Числа, даты,
  валюты форматируются через intl с учётом локали.
- Новый ключ: добавляешь во все ARB и сразу запускаешь `flutter gen-l10n`.
  Сгенерированные файлы локализации (`lib/l10n/app_localizations*.dart`) руками
  не правятся и в git не попадают.

## Хранение настроек — shared_preferences

- Настройки и небольшие пользовательские данные (выбранная тема, язык, флаги онбординга,
  данные профиля) — `shared_preferences`. Hive — для данных фич и кэша API.
- Доступ — через обёртку в `core/storage`, зарегистрированную в DI. Фичи
  `SharedPreferences` напрямую не вызывают, а работают через свой репозиторий.
- `shared_preferences` не шифруется: токены, пароли и секреты туда не кладутся. Нужно
  хранить такое — решение с пользователем, в `decisions.md`.

## Логи — Talker

- Логирование только через Talker, `print` и `debugPrint` в коде нет.
- У пакета есть официальная интеграция с Talker (`talker_dio_logger` для Dio,
  `talker_bloc_logger` для Bloc) — подключаешь её.
- У пакета есть свои логи, а официальной интеграции нет (например, `liquid_glass_widgets`) —
  пишешь **свой адаптер** в `core/logger`, который перенаправляет логи пакета в Talker.
  Как пакет отдаёт логи — по его документации или исходникам, не по памяти.
- **Навигация логируется на всех уровнях вложенности**: корневой роутер, вложенные
  роутеры (`home` и его дети), табы. Наблюдатель (`TalkerAutoRouteObserver`, свой класс
  в `core/logger` на основе `AutoRouterObserver`) логирует и обычные переходы, и смену
  табов; как пробросить его во вложенные роутеры — по документации auto_route.
  Ручная проверка навигации — переход на вложенную страницу и смена таба видны в логе.
- В Talker не попадают секреты, токены и персональные данные — ни в интерсепторах,
  ни в тексте ошибок.

## Конфигурация

- Несекретные настройки (базовый URL API, таймауты, размеры страниц, фичефлаги) —
  константы в `core/config/app_config.dart`, по образцу `AppColors`:
  ```dart
  abstract final class AppConfig {
    static const apiBaseUrl = 'https://api.example.com';
    static const connectTimeout = Duration(seconds: 10);
  }
  ```
- Это единственное место для таких значений. URL, таймаут или лимит, захардкоженный
  в `dio_client.dart`, Retrofit-клиенте или фиче, — дефект: берётся из `AppConfig`.
- Флагов `--dart-define` и flavors нет, запуск — обычный `flutter run`.
- Секреты в `AppConfig` не кладутся никогда — константа в коде попадает в сборку.

## Линтер

`flutter_lints` (стандартный `analysis_options.yaml`). «`flutter analyze` чистый» —
ноль замечаний по нему; в проекте, где код уже был, — ноль **новых** относительно
базовой точки из `brief.md`. Единственное добавление — исключение `docs/**` из анализа,
чтобы код спайков не ломал проверку. Правила линтера не отключаешь, `// ignore:` не ставишь
без причины, понятной из комментария рядом.

## Пакеты

Набор фиксирован. Новый пакет — только с согласия пользователя, решение в `decisions.md`.

| Пакет | Где | Правило |
|---|---|---|
| `dio` | `core/network` | один клиент из `dio_client.dart`, интерсепторы — в `api_interceptors.dart`. Свой `Dio()` в фиче не создаётся |
| `retrofit` | `features/<x>/data/api` | один клиент на фичу, только описание эндпоинтов |
| `json_annotation` / `json_serializable` | `features/<x>/data/models` | модели ответов и запросов |
| `bloc` (`flutter_bloc`) | `presentation/cubit` | Cubit по умолчанию; Bloc — только если нужны события (debounce, трансформеры), и это решение |
| `freezed` | `presentation/cubit` | состояния Cubit — `@freezed` union |
| `get_it` + `injectable` | `app/di` | регистрация аннотациями (`@injectable`, `@lazySingleton`), руками в GetIt не регистрируем |
| `auto_route` | `app/router` | страницы с `@RoutePage()`, маршруты — в `app_router.dart`, `home` — родительский route |
| `hive_ce` | `core/storage` | адаптеры — генерацией, не руками |
| `talker` | `core/logger` | логирование только через него, `print` и `debugPrint` в коде нет |
| `talker_dio_logger`, `talker_bloc_logger` | `core/logger` | официальные интеграции Talker с Dio и Bloc |
| `shared_preferences` | `core/storage` | настройки и небольшие данные, через обёртку |
| `flex_color_scheme` | `app/theme` | схема — по `seedColor` из `AppColors` |
| `liquid_glass_widgets` | `app/theme/glass_manager.dart` | стекло — через `glass_manager`, не напрямую из фич |
| `shimmer` | страницы, `core/widgets` | состояние загрузки — скелетон на shimmer, а не голый индикатор |
| material / `cupertino_ui` | UI | — |
| `intl` + gen-l10n | `lib/l10n` | все строки UI из ARB |
| `flutter_lints` | `analysis_options.yaml` | стандартный набор |

## Генерация

Генерирующие пакеты: `json_serializable`, `retrofit`, `freezed`, `injectable`,
`auto_route`, `hive_ce`, плюс локализация (`flutter gen-l10n`). Генерацию запускает агент:

1. Пишешь исходник с аннотациями и `part`-директивами.
2. Сразу запускаешь:
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
   (для ARB — `flutter gen-l10n`).
3. Дальше работаешь на сгенерированном.

`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, `lib/l10n/app_localizations*.dart`
руками не правятся, вместо генератора не пишутся и **в git не попадают**. Ошибка компиляции «нет такого класса» сразу после правки
аннотаций — почти всегда незапущенная генерация, а не баг.

## Тесты

Пакеты: **`bloc_test` + `mocktail`**. `mocktail` выбран, потому что моки без генерации —
не нужно перезапускать `build_runner` ради каждого нового мока.
Где мок громоздкий, а поведение простое — ручной fake-класс.

Структура `test/` повторяет `lib/`: `test/features/<x>/data/...`, `test/features/<x>/presentation/...`.

Что тестируется по TDD (основные случаи, без фанатизма):

| Слой | Как | Что проверяем |
|---|---|---|
| Репозиторий | `mocktail`-мок Retrofit-клиента / хранилища | маппинг ответа, превращение `DioException` в ошибку фичи, работа с кэшем |
| Cubit | `blocTest`, мок репозитория | последовательность состояний: загрузка → данные / пусто / ошибка |
| Страница | виджет-тест, `MockCubit` из `bloc_test` | на каждое ключевое состояние показывается нужное, нажатие вызывает нужный метод Cubit, раскладка на узкой и широкой ширине |

Виджет-тесты оборачивают страницу в `MaterialApp` с делегатами локализации и темой
приложения — иначе тест проверяет не то, что видит пользователь.

Не тестируем: сгенерированный код, тему, конфиг роутера, DI-регистрацию, фейковые
репозитории, внешний вид и стекло — это ручная проверка.

## .gitignore

Шаблон для проекта. **Сгенерированные файлы в git не попадают** — они восстанавливаются
генерацией после клона (команды — в «Как запускать» в `brief.md`).

```gitignore
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.build/
.buildlog/
.history
.svn/
.swiftpm/
migrate_working_dir/
# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

.vscode/

# Local tooling
.claude/
pid

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/
/coverage/

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

docs/pipeline/

# Android Studio will place build artifacts here
/android/app/debug
/android/app/profile
/android/app/release

# Generated code
*.g.dart
*.gr.dart
*.freezed.dart
*.config.dart
lib/l10n/app_localizations*.dart
```

Новый генерирующий пакет с другим суффиксом файлов — его маска добавляется в раздел
«Generated code».
