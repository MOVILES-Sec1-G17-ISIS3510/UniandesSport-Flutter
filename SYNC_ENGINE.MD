# Sync Engine - Implementación final

Este documento explica la versión final del flujo offline-first para `casual match` en UniandesSport-Flutter.

## Objetivo
Garantizar que cuando un usuario crea un evento deportivo:
1. Se guarde primero en SQLite local.
2. La UI lo pueda ver de inmediato, incluso sin Internet.
3. El cambio quede encolado para sincronizarse después.
4. Cuando regrese la conexión, el Sync Engine suba el evento a Firestore.

## Flujo real implementado

### 1) Creación del evento
La pantalla de creación llama a:
- `lib/features/play/services/events_repository.dart`
- método `createEvent(...)`

Ese método ahora hace lo siguiente:
- genera un `eventId` local
- construye un `SportEvent`
- guarda el evento en la tabla `play_events`
- inserta una fila en `sync_queue` con:
  - `event_id`
  - `action = 'create_play_event'`
  - `status = 'pending'`
  - `retry_count = 0`
  - `timestamp = now`
- dispara `SyncEngineService().processQueue()` en background

Esto significa que la creación ya no depende de Firestore para existir localmente.

### 2) Consulta del schedule
Cuando el usuario consulta su schedule:
- `EventsRepository.getUserParticipatingEvents(userId)` primero lee `play_events`
- si encuentra registros locales, los devuelve de inmediato
- si no hay cache local, consulta Firestore y cachea lo remoto en `play_events`

Así el schedule funciona offline.

### 3) Sincronización con Firestore
El motor vive en:
- `lib/core/network/sync_engine_service.dart`

`SyncEngineService`:
- escucha conectividad con `connectivity_plus`
- también tiene un `Timer.periodic` de respaldo para reintentar cada 30 segundos mientras la app está abierta
- procesa la tabla `sync_queue` ordenada por `timestamp`
- reconoce `action = 'create_play_event'`
- lee el evento desde `play_events`
- lo sube a Firestore en la colección `events`
- usa `SetOptions(merge: true)` para no sobrescribir campos que el servidor ya conozca
- si la subida tiene éxito:
  - elimina la fila de `sync_queue`
  - marca `play_events.is_synced = 1`
- si falla:
  - incrementa `retry_count`
  - cambia `status = 'failed'`
  - reprograma `timestamp` con backoff exponencial

### 4) UI optimista
La pantalla:
- `lib/features/play/views/create_casual_event_page.dart`

Después de crear el evento:
- refresca `PlayViewModel.loadMyScheduled(forceRefresh: true)`
- así el usuario ve inmediatamente el nuevo evento en local

## Tablas locales
El helper SQLite en:
- `lib/core/local_storage/database_helper.dart`

crea estas tablas:

### `play_events`
Tabla principal para casual matches y eventos deportivos de Play.
Campos clave:
- `id`
- `created_by`
- `creator_semester`
- `title`
- `sport`
- `modality`
- `description`
- `location`
- `scheduled_at`
- `max_participants`
- `participants_json`
- `status`
- `created_at`
- `updated_at`
- `is_synced`

### `sync_queue`
Cola de cambios pendientes:
- `id`
- `event_id`
- `action`
- `status`
- `retry_count`
- `timestamp`

### `events`
Cache simple de la feature anterior.
Se mantiene para compatibilidad con el flujo viejo.

## Archivos importantes

### `lib/features/play/models/sport_event.dart`
`SportEvent` ahora incluye:
- `toLocalMap()`
- `fromLocalMap()`
- `creatorSemester`

Esto permite persistir y reconstruir el evento sin depender de Firestore.

### `lib/features/play/services/events_repository.dart`
Es la pieza clave del flujo local-first.

### `lib/core/network/sync_engine_service.dart`
Es la pieza que sincroniza la cola cuando vuelve la conexión.

### `lib/features/play/views/create_casual_event_page.dart`
Refresca la vista tras crear el evento para que la UX sea inmediata.

## Por qué ahora sí sincroniza
Antes el `casual match` se mandaba directo a Firestore, así que si el usuario estaba offline, no quedaba registro local real.

Ahora el orden es:
1. SQLite local
2. UI optimista
3. Cola `sync_queue`
4. Firestore cuando vuelve la conexión

Además, el Sync Engine ya no depende solo del evento de conectividad:
- también reintenta periódicamente mientras la app está viva
- eso reduce el riesgo de que un cambio de red no dispare el sync a tiempo

## Qué pasa si falla la sincronización
Si Firestore rechaza la escritura o falla la red:
- la fila queda en `sync_queue`
- se incrementa `retry_count`
- se aplica backoff exponencial
- cuando `retry_count` supera el máximo configurado, se marca como fallo permanente

## Estado actual de la implementación
La solución final ya está alineada con lo que pediste:
- el evento se guarda primero localmente
- el schedule lo puede mostrar sin internet
- al volver la conexión, la cola se procesa y sube el evento a Firestore

## Recomendaciones futuras
- Agregar indicadores visuales de `pendiente de sync` / `sincronizado`
- Crear tests de `EventsRepository` y `SyncEngineService`
- Añadir sincronización nativa en background si quieres que funcione aun con la app cerrada
- Agregar telemetría/logs para fallos de Firestore y conflictos de datos

## Nota final
La fuente de verdad offline es `play_events`.
La cola `sync_queue` es el mecanismo que garantiza la subida posterior a Firestore.

## Arranque de la app y sesión offline

El arranque de autenticación está pensado para no bloquear al usuario cuando ya existe una sesión local en FirebaseAuth.

### Regla de decisión
1. `FirebaseAuth.instance.currentUser != null`
   - Se entra **de inmediato** a `HomeScreen`.
   - No se descarga el perfil de Firestore para no depender de internet.
   - `AppShell` recibe un perfil mínimo local y puede seguir funcionando offline.

2. `FirebaseAuth.instance.currentUser == null`
   - Se consulta la conectividad del dispositivo.
   - Si **no hay internet**, se muestra el mensaje:
     - `Necesitas conectarte a internet para poder abrir la aplicación e iniciar sesión`
   - Si **sí hay internet**, se muestra `LoginPage`.

### Tabla de comportamiento
| Sesión local | Internet | Pantalla resultante |
|---|---:|---|
| Sí | Sí | `HomeScreen` |
| Sí | No | `HomeScreen` |
| No | Sí | `LoginPage` |
| No | No | Pantalla de aviso sin internet |

### Flujo textual
```text
App inicia
  ├─ currentUser != null ?
  │    └─ Sí → HomeScreen inmediato
  │
  └─ No → verificar conectividad
         ├─ Internet disponible → LoginPage
         └─ Sin internet → Aviso claro al usuario
```

### Cómo convive con la sincronización offline-first
Este flujo de arranque no interfiere con el Sync Engine:
- La sesión local permite entrar al Home aunque no haya internet.
- El `SyncEngineService` sigue procesando `sync_queue` en paralelo cuando vuelve la conectividad.
- Los `casual match` guardados en `play_events` siguen disponibles offline en `My Schedule`.

### Archivos involucrados
- `lib/features/auth/views/auth_gate.dart`
- `lib/features/home/views/home_screen.dart`
- `lib/features/home/views/app_shell.dart`
- `lib/features/auth/views/login_page.dart`
- `lib/core/network/sync_engine_service.dart`

### Nota de implementación
En este proyecto, la pantalla principal real es `AppShell`, envuelta por `HomeScreen`. El `AuthGate` usa un perfil mínimo local para no bloquear el acceso cuando `currentUser` ya existe.
