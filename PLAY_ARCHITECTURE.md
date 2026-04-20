# Arquitectura de la funcionalidad Play

> Este documento describe **cómo está diseñada la funcionalidad `Play`** dentro del proyecto y por qué se tomaron esas decisiones.
>
> **Nota de terminología:** en conversaciones previas apareció el término **MVVC**, pero la implementación real del código corresponde a **MVVM (Model - View - ViewModel)**. En este documento se usa el nombre correcto para que la documentación sea consistente con la arquitectura actual.

---

## Índice
1. [Objetivo de la funcionalidad Play](#objetivo-de-la-funcionalidad-play)
2. [Vista general de las decisiones de diseño](#vista-general-de-las-decisiones-de-diseño)
3. [Estructura de la funcionalidad en el proyecto](#estructura-de-la-funcionalidad-en-el-proyecto)
4. [MVVM en Play](#mvvm-en-play)
5. [Provider como mecanismo de conexión](#provider-como-mecanismo-de-conexión)
6. [Repository Pattern en Play](#repository-pattern-en-play)
7. [Singleton en Play](#singleton-en-play)
8. [Encapsulamiento en Play](#encapsulamiento-en-play)
9. [Flujos visuales de alto nivel](#flujos-visuales-de-alto-nivel)
10. [Justificación de las decisiones de diseño](#justificación-de-las-decisiones-de-diseño)
11. [Trade-offs y límites actuales](#trade-offs-y-límites-actuales)
12. [Reglas para extender Play sin romper la arquitectura](#reglas-para-extender-play-sin-romper-la-arquitectura)

---

## Objetivo de la funcionalidad Play

La funcionalidad `Play` resuelve un flujo muy concreto dentro de la aplicación:

- permitir al usuario **seleccionar un deporte**,
- escoger una **modalidad**,
- **buscar eventos activos** que coincidan con esa selección,
- **registrarse** en un evento,
- o **crear un partido casual** cuando corresponda.

Además, `Play` necesita coordinar UI, estado local de la pantalla, navegación y acceso a Firebase. Por eso no conviene resolverla con una sola clase grande: se necesita una arquitectura que separe responsabilidades.

---

## Vista general de las decisiones de diseño

La funcionalidad `Play` combina **cuatro decisiones principales**:

| Decisión | Dónde se ve | Para qué sirve |
|---|---|---|
| **MVVM** | `play_page.dart`, `play_view_model.dart` | Separar UI de lógica y estado |
| **Provider** | `app.dart`, `app_shell.dart` | Inyectar dependencias y escuchar cambios de estado |
| **Repository Pattern** | `events_repository.dart` | Encapsular Firebase detrás de una API de dominio |
| **Singleton** | `EventsRepository.instance` | Reutilizar una sola instancia del repositorio |
| **Encapsulamiento** | campos privados y getters/métodos del ViewModel | Proteger el estado interno y reducir acoplamiento |

---

## Estructura de la funcionalidad en el proyecto

La parte principal de `Play` vive dentro de `lib/features/home/`.

```text
lib/
└── features/
    └── home/
        ├── data/
        │   └── events_repository.dart
        ├── domain/
        │   └── models/
        │       ├── sport_event.dart
        │       └── event_modality.dart
        └── presentation/
            ├── controllers/
            │   └── play_view_model.dart
            ├── pages/
            │   ├── play_page.dart
            │   ├── create_casual_event_page.dart
            │   ├── event_registration_result_page.dart
            │   └── app_shell.dart
            └── widgets/
                ├── sport_selector.dart
                ├── modality_selector.dart
                ├── action_buttons_section.dart
                └── event_card.dart
```

### Lectura estructural de esa organización

- **`data/`** contiene el acceso real a Firestore y Cloud Functions.
- **`domain/`** contiene los modelos del negocio, como `SportEvent`.
- **`presentation/`** contiene pantallas, widgets y el ViewModel.

### Por qué esta estructura tiene sentido

1. **Agrupa por funcionalidad**, no por tipo de archivo global.
2. Hace que los cambios de `Play` queden localizados.
3. Permite que la UI evolucione sin tocar la capa de datos.
4. Hace más fácil encontrar dónde vive cada responsabilidad.

---

## MVVM en Play

## ¿Qué papel cumple cada pieza?

La implementación de `Play` sigue **MVVM**.

```text
Usuario
  │
  ▼
View (`play_page.dart`)
  │ delega acciones
  ▼
ViewModel (`play_view_model.dart`)
  │ usa servicios de datos
  ▼
Model / Repository (`sport_event.dart`, `events_repository.dart`)
```

### 1. View: `play_page.dart`

La `View` solo se encarga de:

- dibujar la pantalla,
- mostrar estados visuales,
- invocar acciones del ViewModel,
- navegar a otras páginas cuando hace falta.

En otras palabras, **la View no debería “pensar”**.

#### Ejemplos de lo que hace la View

- muestra `SportSelector`, `ModalitySelector` y `ActionButtonsSection`,
- lee el estado desde `context.watch<PlayViewModel>()`,
- llama `vm.search()` o `vm.resetSearch()`,
- abre `CreateCasualEventPage` o `EventRegistrationResultPage`.

### 2. ViewModel: `play_view_model.dart`

El `ViewModel` concentra el estado y la lógica de la feature.

#### Estado que controla

- deporte seleccionado,
- modalidad seleccionada,
- si la búsqueda está cargando,
- resultados de búsqueda,
- errores,
- evento en proceso de unión,
- reglas como `canSearch` y `canCreate`.

#### Acciones que resuelve

- `selectSport(...)`
- `selectModality(...)`
- `search()`
- `resetSearch()`
- `joinEvent(...)`
- `formatSchedule(...)`
- `updateProfile(...)`

### 3. Model / dominio

El dominio representa la información con la que trabaja la feature:

- `SportEvent`
- `EventModality`

Estos objetos son el lenguaje del negocio. La UI no debería hablar en términos de `DocumentSnapshot` o `QuerySnapshot`, sino en términos de `SportEvent`.

### Por qué MVVM tiene sentido en Play

`Play` tiene suficiente complejidad como para justificar separación:

- múltiples estados visuales,
- acceso a Firebase,
- validación de acciones,
- navegación condicionada,
- reglas de negocio como “solo crear si la modalidad es casual”.

Si toda esa lógica viviera dentro de la pantalla, el archivo se volvería difícil de mantener. MVVM reduce ese problema.

---

## Provider como mecanismo de conexión

`Provider` es la pieza que conecta la `View` con el `ViewModel`.

### Registro de dependencias

A alto nivel, el árbol se ve así:

```text
main.dart
  └── app.dart
      └── MultiProvider
          ├── Provider<EventsRepository>
          ├── ChangeNotifierProxyProvider<AuthRepository, AuthController>
          └── ChangeNotifierProxyProvider<EventsRepository, PlayViewModel>
```

### Qué aporta Provider aquí

- permite **inyectar el repositorio** en el ViewModel,
- permite que la UI **escuche cambios reactivos**,
- evita pasar dependencias manualmente por muchos constructores,
- centraliza el ciclo de vida de objetos compartidos.

### Cómo se usa en la práctica

- `context.watch<PlayViewModel>()` para reconstruir la UI cuando el estado cambia.
- `context.read<PlayViewModel>()` para acceder sin suscripción reactiva.

### Por qué tiene sentido

Sin `Provider`, la pantalla tendría que manejar sus propias instancias o recibir demasiadas dependencias manualmente. Eso elevaría el acoplamiento y haría más difícil extender el flujo.

---

## Repository Pattern en Play

## Qué problema resuelve

La funcionalidad `Play` necesita consultar Firestore, registrar usuarios y crear eventos. Si la UI hablara directo con Firebase, quedaría acoplada a detalles técnicos de infraestructura.

Para evitar eso se usa **Repository Pattern**.

### Implementación actual

`events_repository.dart` encapsula operaciones como:

- `searchEvents(...)`
- `getRecommendedEvents(...)`
- `getEventById(...)`
- `createEvent(...)`
- `joinEvent(...)`
- `registerUserInEventWithMessage(...)`
- `getUserEvents(...)`
- `getUserParticipatingEvents(...)`

### Visualización de la idea

```text
PlayPage / PlayViewModel
        │
        │ no conocen Firestore directamente
        ▼
EventsRepository
        │
        ├── FirebaseFirestore
        └── FirebaseFunctions
```

### Qué encapsula el repositorio

- la forma exacta de construir queries,
- la colección usada en Firestore,
- el manejo de transacciones,
- los mensajes de error del backend,
- la transformación de documentos a modelos del dominio.

### Por qué esta decisión tiene sentido

1. **Bajo acoplamiento**: la UI no depende de Firebase.
2. **Mantenibilidad**: si cambia la query, el cambio queda en un solo sitio.
3. **Testabilidad**: el ViewModel puede probarse con un repositorio falso.
4. **Claridad**: la capa de presentación trabaja con métodos del dominio, no con APIs de infraestructura.

---

## Singleton en Play

## Qué decisión se tomó

`EventsRepository` se expone como una instancia única:

```dart
EventsRepository.instance
```

### Visualmente

```text
                 ┌─────────────────────────┐
PlayViewModel ──▶│ EventsRepository.instance │
Home widgets ──▶│ EventsRepository.instance │
Other pages  ──▶│ EventsRepository.instance │
                 └─────────────────────────┘
```

### Por qué tiene sentido en este caso

`EventsRepository` es un buen candidato a Singleton porque:

1. **No guarda estado mutable propio**.
2. Solo coordina llamadas a `FirebaseFirestore.instance`.
3. Distintas partes de la app pueden reutilizar la misma instancia.
4. Evita construir objetos repetidos para un servicio esencialmente compartido.

### Qué beneficio real aporta

- reduce creación innecesaria de instancias,
- estandariza el punto de acceso al servicio,
- simplifica la inyección con `Provider`.

### Qué no significa

Usar Singleton **no reemplaza** a `Provider` ni a `Repository Pattern`.

- `Singleton` controla **la cantidad de instancias**.
- `Repository Pattern` controla **la abstracción del acceso a datos**.
- `Provider` controla **cómo se entregan esas dependencias a la UI**.

Son decisiones complementarias, no excluyentes.

---

## Encapsulamiento en Play

El encapsulamiento es una de las tácticas más visibles de esta feature.

## ¿Dónde aparece?

### 1. En `PlayViewModel`

El estado interno no se expone directamente:

```text
_selectedSport
_selectedModality
_hasSearched
_isSearching
_searchResults
_searchError
_joiningEventId
_repo
_profile
```

La UI no modifica esos valores por su cuenta. En vez de eso, usa:

- getters,
- métodos controlados,
- operaciones como `selectSport`, `search`, `joinEvent`.

### 2. En `EventsRepository`

La UI no sabe:

- qué colección se consulta,
- qué filtros exactos se usan,
- cómo se hace la transacción,
- cómo se maneja la Cloud Function.

Todo eso queda encapsulado dentro del repositorio.

### 3. En widgets reutilizables

Widgets como `EventCard` encapsulan:

- layout,
- animación de expansión,
- presentación de descripción,
- botón de acción,
- estilo visual consistente.

### Beneficio de encapsular

- protege invariantes,
- reduce acoplamiento,
- evita modificaciones accidentales del estado,
- permite cambiar implementación interna sin romper a los consumidores.

### Ejemplo conceptual

```text
La View NO hace esto:
  vm._searchResults.add(...)

La View SÍ hace esto:
  vm.search()
  vm.selectSport('futbol')
```

Esto obliga a que el cambio de estado pase por una API controlada.

---

## Flujos visuales de alto nivel

## 1. Flujo de búsqueda

```text
[Usuario toca "Buscar"]
          │
          ▼
[PlayPage]
  lee vm.canSearch
  llama vm.search()
          │
          ▼
[PlayViewModel]
  cambia _isSearching = true
  notifyListeners()
          │
          ▼
[EventsRepository]
  searchEvents(...)
          │
          ▼
[Firestore / Cloud Functions]
          │
          ▼
[List<SportEvent>]
          │
          ▼
[PlayViewModel]
  actualiza _searchResults
  cambia _isSearching = false
  notifyListeners()
          │
          ▼
[PlayPage]
  reconstruye UI y muestra resultados
```

## 2. Flujo de registro a un evento

```text
[Usuario toca "Unirse"]
          │
          ▼
[EventCard -> PlayPage]
          │
          ▼
[PlayViewModel.joinEvent(event)]
          │
          ▼
[EventsRepository.registerUserInEventWithMessage(...)]
          │
          ▼
[Firestore transaction]
          │
          ├── éxito   ──▶ resultado success
          └── error   ──▶ resultado failure
          │
          ▼
[PlayViewModel]
  refresca búsqueda si corresponde
          │
          ▼
[PlayPage]
  navega a EventRegistrationResultPage
```

## 3. Relación estructural de alto nivel

```text
┌────────────────────────────────────────────────────────────┐
│                        PRESENTATION                        │
│                                                            │
│  PlayPage  ─────▶  PlayViewModel  ◀────  AppShell          │
│     │                    │                                 │
│     │ usa widgets        │ usa Provider / notifyListeners  │
│     ▼                    ▼                                 │
│  EventCard         estado + reglas                         │
└────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────┐
│                           DATA                             │
│                                                            │
│                 EventsRepository.instance                  │
│                      │              │                      │
│                      ▼              ▼                      │
│              FirebaseFirestore   FirebaseFunctions         │
└────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────┐
│                          DOMAIN                            │
│                                                            │
│              SportEvent / EventModality                    │
└────────────────────────────────────────────────────────────┘
```

---

## Justificación de las decisiones de diseño

### 1. MVVM

**Se eligió porque** `Play` ya no es una pantalla trivial.

Tiene:
- selección de filtros,
- reglas de habilitación,
- carga remota,
- estados de error,
- navegación basada en resultados,
- acciones de registro y refresco.

**Beneficio principal:** separar UI de lógica y hacer el flujo más mantenible.

---

### 2. Provider

**Se eligió porque** se necesitaba una forma simple y consistente de:

- proveer dependencias,
- compartir el ViewModel,
- reaccionar a cambios de estado.

**Beneficio principal:** integración natural con Flutter y bajo costo de complejidad.

---

### 3. Repository Pattern

**Se eligió porque** Firebase es un detalle de infraestructura, no una responsabilidad de la UI.

**Beneficio principal:** el resto de la feature piensa en eventos y acciones del dominio, no en documentos y queries.

---

### 4. Singleton

**Se eligió porque** el repositorio no tiene estado mutable de negocio y puede compartirse.

**Beneficio principal:** una sola instancia coherente del servicio dentro de la app.

---

### 5. Encapsulamiento

**Se eligió porque** el estado de Play tiene reglas y no debe alterarse desde cualquier sitio.

**Beneficio principal:** controlar cómo cambia el estado y proteger invariantes del flujo.

---

## Trade-offs y límites actuales

Toda decisión de diseño tiene beneficios y costos.

| Decisión | Beneficio | Costo / límite |
|---|---|---|
| MVVM | mejor separación y testabilidad | agrega una capa adicional |
| Provider | simple e idiomático en Flutter | puede volverse difuso si el árbol crece mucho |
| Repository | desacopla Firebase de la UI | requiere disciplina para no saltarse la capa |
| Singleton | reutiliza una sola instancia | no sirve para objetos con configuración mutable por pantalla |
| Encapsulamiento | protege el estado | obliga a exponer APIs bien pensadas |

### Límites actuales de la implementación

Aun con esta base, `Play` podría fortalecerse más en el futuro con:

- casos de uso explícitos (`SearchEventsUseCase`, `JoinEventUseCase`),
- pruebas unitarias del `PlayViewModel`,
- logging estructurado,
- cache local de búsquedas o recomendaciones,
- manejo más formal de errores de red.

---

## Reglas para extender Play sin romper la arquitectura

Si la funcionalidad crece, estas reglas ayudan a mantener consistencia:

1. **La View no debe hablar directamente con Firebase.**
2. **Toda lógica nueva debe entrar primero al ViewModel o al repositorio.**
3. **Si la lógica es de negocio, no debe vivir en un widget.**
4. **Si una dependencia se comparte y no tiene estado mutable, puede evaluarse como Singleton.**
5. **El estado interno del ViewModel debe seguir encapsulado.**
6. **Los widgets reutilizables deben seguir siendo “tontos”: reciben datos y callbacks.**
7. **La capa de dominio debe seguir usando modelos del negocio, no tipos de infraestructura.**

---

## Resumen ejecutivo

La funcionalidad `Play` está construida alrededor de una idea central:

> **la UI dibuja, el ViewModel coordina, el repositorio accede a datos y los modelos representan el dominio.**

Eso se traduce en estas decisiones concretas:

- **MVVM** para separar interfaz y lógica,
- **Provider** para conectar estado y dependencias,
- **Repository Pattern** para abstraer Firebase,
- **Singleton** para compartir el repositorio,
- **Encapsulamiento** para proteger el estado interno.

El resultado es una feature más clara, más modificable y más fácil de extender sin mezclar responsabilidades.

