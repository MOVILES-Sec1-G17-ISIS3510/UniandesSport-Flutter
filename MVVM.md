# MVVM Feature-First en UniandesSport-Flutter

## 1. Filosofia Arquitectonica

Este proyecto adopta una arquitectura **MVVM orientada a funcionalidades (Feature-First)** para escalar sin convertir `lib/` en un monolito dificil de mantener.

- **MVVM** separa responsabilidades en tres capas: `Model`, `ViewModel` y `View`.
- **Feature-First** agrupa el codigo por dominio funcional (`auth`, `play`, `coach`, etc.), no por tipo tecnico global.
- Esta combinacion reduce acoplamiento, facilita pruebas y permite evolucionar cada modulo con menor riesgo de regresion.

### Por que se eligio este enfoque

- Permite que cada feature tenga su propio ciclo completo de UI, estado y acceso a datos.
- Mejora la colaboracion en equipo: varias personas pueden trabajar en features distintas sin conflictos frecuentes.
- Hace explicita la direccion de dependencias: la UI depende del estado expuesto por ViewModels; los ViewModels dependen de Services; los Services transforman datos en Models.

### Separation of Concerns aplicada

- `views/` y `widgets/` se enfocan en renderizar.
- `viewmodels/` centraliza logica de presentacion y estado.
- `services/` encapsula integraciones externas (Firebase, HTTP, almacenamiento, etc.).
- `models/` representa estructuras de datos y serializacion.
- `core/` concentra piezas transversales para toda la app.

---

## 2. Arbol de Directorios Actualizado

Estructura actual detectada en `lib/`:

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── constants/
│   ├── error/
│   ├── network/
│   └── utils/
└── features/
    ├── auth/
    │   ├── models/
    │   ├── services/
    │   ├── viewmodels/
    │   ├── views/
    │   └── widgets/
    ├── challenges/
    │   ├── services/
    │   ├── viewmodels/
    │   ├── views/
    │   └── widgets/
    ├── coach/
    │   ├── models/
    │   ├── services/
    │   ├── viewmodels/
    │   ├── views/
    │   └── widgets/
    ├── home/
    │   ├── models/
    │   ├── services/
    │   ├── viewmodels/
    │   ├── views/
    │   └── widgets/
    └── play/
        ├── models/
        ├── services/
        ├── viewmodels/
        ├── views/
        └── widgets/
```

### Diferencia clave: `core/` vs `features/`

- **`core/`**: codigo transversal reutilizable por toda la aplicacion (constantes, utilidades, red, manejo de errores).
- **`features/`**: modulos de negocio aislados, cada uno con su propia implementacion MVVM.

> Nota: para cumplir una convencion estricta y uniforme, `lib/features/challenges/` deberia incorporar tambien `models/` si la feature persiste o transforma entidades de dominio.

---

## 3. Anatomia de una Funcionalidad (Feature)

Cada feature debe seguir esta anatomia:

### `models/`

Responsabilidad:

- Definir entidades de datos puras (sin dependencias de UI).
- Implementar serializacion/deserializacion (`fromJson`, `toJson`) cuando aplique.
- Validar invariantes minimos del dominio.

Reglas:

- No importar `material.dart` ni paquetes de presentacion.
- No ejecutar llamadas de red directamente.

### `services/`

Responsabilidad:

- Encapsular acceso a fuentes externas: Firebase, REST APIs, storage local, etc.
- Traducir respuestas externas en objetos de dominio (`models`).
- Manejar errores tecnicos y devolver resultados interpretables por el ViewModel.

Reglas:

- Sin estado visual.
- Sin dependencia de `BuildContext`.

### `viewmodels/`

Responsabilidad:

- Orquestar casos de uso de presentacion.
- Exponer estado observable para la UI.
- Coordinar llamadas a `services/` y actualizar estado (`notifyListeners`).

Reglas:

- No crear Widgets.
- No mezclar logica de layout ni estilos.

### `views/` y `widgets/`

Responsabilidad:

- `views/`: pantallas completas, enrutamiento de interacciones del usuario.
- `widgets/`: componentes UI reutilizables dentro de la feature.

Reglas:

- UI pasiva: renderiza estado y delega acciones al ViewModel.
- No acceso directo a servicios o repositorios.

---

## 4. Flujo de Datos y Comunicacion

Flujo recomendado de extremo a extremo:

1. El usuario interactua en una `View` (por ejemplo, pulsa un boton).
2. La `View` delega la accion al metodo correspondiente del `ViewModel`.
3. El `ViewModel` valida contexto de presentacion y llama al `Service`.
4. El `Service` consulta Firebase/API/DB y construye `Models`.
5. El `ViewModel` actualiza su estado interno y notifica cambios.
6. La `View` se reconstruye al observar el ViewModel y refleja el nuevo estado.

### Direccion de dependencias

- `View -> ViewModel -> Service -> Model`
- El retorno de estado viaja de vuelta en sentido inverso hasta la UI.

### Integracion con Provider (contexto del proyecto)

- Registro central en `lib/app.dart` usando `Provider`, `ChangeNotifierProvider` y `ChangeNotifierProxyProvider`.
- Inyeccion de dependencias en el arbol para evitar instanciaciones manuales en UI.

---

## 5. Reglas Estrictas (Do's & Don'ts)

### Do's

- Mantener cada feature autocontenida en su carpeta.
- Exponer solo estado y acciones desde ViewModels.
- Compartir utilidades transversales exclusivamente desde `core/`.
- Mantener imports consistentes por feature y capa.

### Don'ts (obligatorio)

- Las **Views NUNCA** deben instanciar o llamar `Services/Repositorios` directamente.
- Los **Models NUNCA** deben importar librerias de UI como `material.dart`.
- Los **ViewModels NO** deben contener referencias a Widgets de Flutter.
- Los **Services NO** deben depender de `views/` ni de `widgets/`.
- Evitar dependencias ciclicas entre capas de una feature.

### Limites de responsabilidad inquebrantables

- Si una clase renderiza UI, no debe resolver acceso a datos externos.
- Si una clase gestiona integracion externa, no debe conocer detalles de composicion visual.
- Si una clase es de modelo, debe ser agnostica a framework de UI.

---

## 6. Guia de Creacion de una Nueva Feature

Checklist operativo para humanos o IA:

1. Crear `lib/features/<nombre_feature>/`.
2. Crear subcarpetas: `models/`, `services/`, `viewmodels/`, `views/`, `widgets/`.
3. Definir primero los `models/` del dominio.
4. Implementar `services/` para fuentes externas.
5. Implementar `viewmodels/` con estado observable y acciones de UI.
6. Construir `views/` y `widgets/` consumiendo ViewModels.
7. Registrar dependencias en `lib/app.dart` (Providers/ProxyProviders).
8. Verificar imports para mantener aislamiento por capa.
9. Ejecutar analisis estatico y pruebas antes de merge.

## Convenciones de mantenimiento

- No crear carpetas ad hoc fuera de `core/` y `features/`.
- Si una feature requiere entidades de dominio, debe existir `models/`.
- Toda nueva funcionalidad debe iniciar ya alineada al patron MVVM Feature-First.

