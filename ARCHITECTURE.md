# Arquitectura de UniandesSport — Flutter

## Índice
1. [Visión general](#visión-general)
2. [Estructura de carpetas](#estructura-de-carpetas)
3. [Patrones implementados](#patrones-implementados)
   - [Feature-First + Clean Architecture simplificada](#1-feature-first--clean-architecture-simplificada)
   - [MVVM con Provider](#2-mvvm-con-provider)
   - [Singleton](#3-singleton)
4. [Flujo de datos completo](#flujo-de-datos-completo)
5. [Reglas de la arquitectura](#reglas-de-la-arquitectura)

---

## Visión general

La aplicación combina tres patrones complementarios:

| Patrón | Scope | Archivos clave |
|---|---|---|
| **Feature-First** | Toda la app | `lib/features/`, `lib/core/` |
| **MVVM + Provider** | Funcionalidades con estado | `PlayViewModel`, `AuthController` |
| **Singleton** | Servicios sin estado | `EventsRepository` |

---

## Estructura de carpetas

```
lib/
├── core/                          ← Código compartido entre features
│   └── theme/
│       ├── app_theme.dart         ← Colores, tipografías globales
│       └── app_sports.dart        ← Estilos y metadatos de cada deporte
│
├── features/
│   ├── auth/                      ← Feature de autenticación
│   │   ├── data/
│   │   │   └── auth_repository.dart       ← Acceso a Firebase Auth + Firestore
│   │   ├── domain/
│   │   │   └── models/
│   │   │       ├── user_profile.dart      ← Modelo de usuario
│   │   │       └── user_role.dart         ← Enum de roles
│   │   └── presentation/
│   │       ├── controllers/
│   │       │   └── auth_controller.dart   ← ViewModel de autenticación
│   │       └── pages/
│   │           ├── auth_gate.dart         ← Decide si mostrar login o app
│   │           ├── login_page.dart
│   │           └── register_page.dart
│   │
│   └── home/                      ← Feature principal (shell + play + home)
│       ├── data/
│       │   └── events_repository.dart     ← Acceso a Firestore (Singleton)
│       ├── domain/
│       │   └── models/
│       │       ├── sport_event.dart       ← Modelo de evento deportivo
│       │       └── event_modality.dart    ← Enum casual/torneo
│       └── presentation/
│           ├── controllers/
│           │   └── play_view_model.dart   ← ViewModel de Play (MVVM)
│           ├── pages/
│           │   ├── app_shell.dart         ← Navegación principal (BottomNav)
│           │   ├── home_page.dart
│           │   ├── play_page.dart         ← View pura (sin lógica)
│           │   └── ...
│           └── widgets/
│               ├── sport_selector.dart
│               ├── event_card.dart
│               └── ...
│
├── app.dart                       ← Raíz del árbol, configura Provider
└── main.dart                      ← Punto de entrada
```

---

## Patrones implementados

### 1. Feature-First + Clean Architecture simplificada

#### ¿Qué es?
Organizar el código por **funcionalidad** (feature) en lugar de por tipo de archivo. Dentro de cada feature se respeta una separación en 3 capas: `data`, `domain` y `presentation`.

#### ¿Cómo está implementado?

```
features/
  auth/          ← todo lo relacionado con login/registro junto
    data/        ← capa de acceso a Firebase
    domain/      ← modelos de negocio (Dart puro, sin Flutter)
    presentation/ ← UI y controllers
  home/
    data/
    domain/
    presentation/
```

#### ¿Por qué tiene sentido?
- **Localidad**: cuando hay un bug en Play, todos los archivos relevantes están en `features/home/`.
- **Escalabilidad**: agregar una feature nueva (ej. `retos/`) no toca ningún archivo existente.
- **Separación de responsabilidades**: `data` no sabe de widgets, `domain` no sabe de Firebase, `presentation` no sabe de Firestore.

---

### 2. MVVM con Provider

#### ¿Qué es?
**Model-View-ViewModel** divide la pantalla en tres responsabilidades claras:
- **Model**: datos puros y acceso a servicios externos (repositorios).
- **ViewModel**: estado de la pantalla, lógica de negocio, coordinación.
- **View**: solo dibuja lo que el ViewModel expone, sin lógica propia.

**Provider** es el mecanismo que conecta el ViewModel con la View: pone el ViewModel en el árbol de widgets y notifica a la View cuando el estado cambia.

#### ¿Cómo está implementado?

**Paso 1 — Registrar en `app.dart`** (una sola vez para toda la app):
```dart
MultiProvider(
  providers: [
    Provider<EventsRepository>(
      create: (_) => EventsRepository.instance, // singleton inyectado
    ),
    ChangeNotifierProxyProvider<EventsRepository, PlayViewModel>(
      create: (ctx) => PlayViewModel(
        repository: ctx.read<EventsRepository>(),
        profile: UserProfile.empty(),
      ),
      update: (ctx, repo, vm) => vm ?? PlayViewModel(...),
    ),
  ],
  child: MaterialApp(...),
)
```

**Paso 2 — PlayViewModel** (lógica y estado):
```dart
class PlayViewModel extends ChangeNotifier {
  final EventsRepository _repo; // inyectado, no instanciado aquí
  UserProfile _profile;

  String? _selectedSport;
  bool _isSearching = false;
  List<SportEvent> _searchResults = [];

  bool get canSearch => _selectedSport != null && _selectedModality != null;

  void selectSport(String? sport) {
    _selectedSport = sport;
    notifyListeners(); // avisa a la View
  }

  Future<void> search() async {
    _isSearching = true;
    notifyListeners();
    _searchResults = await _repo.searchEvents(...);
    _isSearching = false;
    notifyListeners();
  }
}
```

**Paso 3 — PlayPage** (solo dibuja):
```dart
class PlayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlayViewModel>(); // escucha cambios

    return SportSelector(
      selectedSport: vm.selectedSport,         // lee del VM
      onSportSelected: vm.selectSport,         // delega al VM
    );
  }
}
```

#### ¿Por qué tiene sentido?

| Sin MVVM (antes) | Con MVVM (ahora) |
|---|---|
| `_PlayPageState` tenía 200+ líneas mezclando UI y lógica | `PlayPage` solo dibuja (~80 líneas) |
| El repositorio se instanciaba dentro del widget | El repositorio es inyectado por Provider |
| Si el estado cambiaba, `setState` reconstruía todo el árbol | Solo los widgets que hacen `watch` se reconstruyen |
| Imposible testear la lógica sin construir widgets | `PlayViewModel` se puede testear con Dart puro |

La regla de oro es: **si un widget necesita "pensar", ese pensamiento va al ViewModel**.

#### Diferencia entre `read` y `watch`

```dart
// watch: reconstruye el widget cada vez que el VM notifica cambios.
// Úsalo en build() para mostrar datos reactivos.
final vm = context.watch<PlayViewModel>();

// read: lee el valor UNA sola vez, no se suscribe a cambios.
// Úsalo en callbacks (onPressed) para no reconstruir innecesariamente.
context.read<PlayViewModel>().selectSport('futbol');
```

---

### 3. Singleton

#### ¿Qué es?
Un patrón que garantiza que una clase tenga **exactamente una instancia** durante toda la vida de la aplicación, accesible globalmente.

#### ¿Cómo está implementado?

```dart
class EventsRepository {
  // Constructor privado: nadie puede hacer `EventsRepository()` desde fuera.
  EventsRepository._internal() : _firestore = FirebaseFirestore.instance;

  // Instancia única, creada una sola vez al arrancar la app (eager singleton).
  static final EventsRepository instance = EventsRepository._internal();

  final FirebaseFirestore _firestore;
  // ... métodos
}

// Uso:
final repo = EventsRepository.instance; // siempre la misma instancia
```

Se registra en `app.dart` con Provider para que el ViewModel lo reciba por inyección:
```dart
Provider<EventsRepository>(
  create: (_) => EventsRepository.instance,
),
```

#### ¿Por qué tiene sentido aquí y no en el repositorio de auth?

`EventsRepository` es el candidato ideal para Singleton porque:

1. **No tiene estado mutable propio**: solo coordina llamadas a Firestore. No guarda datos entre llamadas.
2. **Firebase ya es un singleton interno**: `FirebaseFirestore.instance` siempre devuelve la misma conexión. Crear múltiples `EventsRepository` no abre más conexiones, pero sí crea objetos innecesarios.
3. **Uso concurrente**: `PlayPage`, `HomePage` (recomendaciones) y `AppShell` pueden necesitar el repositorio al mismo tiempo. Con Singleton, todos comparten la misma instancia sin coordinación extra.

`AuthRepository` **no es Singleton** porque podría necesitar distintas instancias de `FirebaseAuth` en pruebas unitarias (para simular usuarios distintos). La flexibilidad importa más que la eficiencia en ese caso.

---

## Flujo de datos completo

```
Usuario toca "Buscar"
        │
        ▼
  PlayPage.build()          ← View: solo captura el gesto
  vm.search()               ← delega al ViewModel
        │
        ▼
  PlayViewModel.search()    ← ViewModel: gestiona el estado
  _isSearching = true
  notifyListeners()         ← avisa a la View
        │
        ▼
  PlayPage se reconstruye   ← View: muestra CircularProgressIndicator
        │
        ▼
  _repo.searchEvents()      ← ViewModel llama al repositorio
        │
        ▼
  EventsRepository          ← Singleton: coordina con Firebase
  FirebaseFirestore.get()   ← servicio externo
        │
        ▼
  Retorna List<SportEvent>  ← modelo de dominio
        │
        ▼
  PlayViewModel._searchResults = events
  _isSearching = false
  notifyListeners()
        │
        ▼
  PlayPage se reconstruye   ← View: muestra la lista de EventCard
```

---

## Reglas de la arquitectura

Estas reglas evitan que la arquitectura se degrade con el tiempo:

1. **La View no instancia repositorios**. Si un widget necesita datos, los pide al ViewModel via `context.watch` o `context.read`.

2. **El ViewModel no importa paquetes de Flutter UI** (`material.dart`, `widgets`). Solo importa modelos, repositorios y `ChangeNotifier`.

3. **Los modelos son Dart puro**. `SportEvent`, `UserProfile`, etc. no dependen de Flutter ni de Firebase directamente (excepto para los métodos `fromFirestore`/`toJson` que son la frontera de la capa de datos).

4. **El repositorio no conoce la UI**. No recibe ni retorna widgets. Habla el lenguaje de los modelos de dominio.

5. **Un Singleton solo si no tiene estado**. Si un objeto necesita cambiar su configuración en runtime, no debe ser Singleton.

6. **`context.read` en callbacks, `context.watch` en `build`**. Usar `watch` en un callback causa reconstrucciones innecesarias.

