# 📊 Estructura de Firebase Firestore para Eventos Deportivos

## 🏗️ Colecciones y Documentos

### **1. Colección: `events`**
Almacena todos los eventos deportivos (partidos y torneos).

#### Estructura de un documento evento:

```json
{
  "id": "AUTO_GENERATED",
  "createdBy": "uid_usuario_creador",
  "title": "Fútbol 5v5",
  "sport": "futbol",
  "modality": "casual",
  "description": "Partido amistoso, nivel principiante",
  "location": "UniAndes Courts",
  "scheduledAt": "2024-03-15T15:00:00Z",
  "maxParticipants": 10,
  "participants": ["uid_usuario1", "uid_usuario2", "uid_usuario3"],
  "status": "active",
  "createdAt": "2024-03-10T10:30:00Z",
  "updatedAt": "2024-03-14T12:00:00Z"
}
```

#### Desglose de campos:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `createdBy` | string | UID del usuario que creó el evento |
| `title` | string | Título del evento (ej: "Fútbol 5v5") |
| `sport` | string | Deporte (`futbol`, `calistenia`, `running`, etc.) |
| `modality` | string | Tipo de evento: `casual` o `tournament` |
| `description` | string | Descripción del evento |
| `location` | string | Ubicación del evento |
| `scheduledAt` | timestamp | Fecha y hora programada del evento |
| `maxParticipants` | number | Máximo de participantes permitidos |
| `participants` | array | Lista de UIDs de participantes (incluye creador) |
| `status` | string | Estado: `active`, `completed`, `cancelled` |
| `createdAt` | timestamp | Fecha de creación del evento |
| `updatedAt` | timestamp | Última actualización |

---

## 📋 Reglas de Firestore Security

Agrega estas reglas en **Firebase Console → Firestore → Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Permitir lectura de eventos activos a todos
    match /events/{eventId} {
      allow read: if resource.data.status == 'active';
      
      // Solo el creador puede actualizar o eliminar su evento
      allow write: if request.auth.uid == resource.data.createdBy;
      
      // Permitir crear eventos a usuarios autenticados
      allow create: if request.auth.uid != null 
                    && request.resource.data.createdBy == request.auth.uid;
    }
    
    // Permitir lectura de perfiles de usuario
    match /users/{userId} {
      allow read: if true;
    }
  }
}
```

---

## 🔄 Ejemplo de Flujo: Crear Evento

### **Usuario Regular crea un PARTIDO CASUAL:**

1. **Evento creado:**
```dart
await EventsRepository().createEvent(
  createdBy: currentUser.uid,
  title: 'Fútbol 5v5 - Principiantes',
  sport: 'futbol',
  modality: EventModality.casual,
  description: 'Partido casual sin experiencia requerida',
  location: 'Cancha principal UniAndes',
  scheduledAt: DateTime.now().add(Duration(days: 1, hours: 2)),
  maxParticipants: 10,
);
```

2. **Documento en Firestore:**
```json
{
  "createdBy": "user123",
  "title": "Fútbol 5v5 - Principiantes",
  "sport": "futbol",
  "modality": "casual",
  "description": "Partido casual sin experiencia requerida",
  "location": "Cancha principal UniAndes",
  "scheduledAt": Timestamp(2024-03-15T18:30:00Z),
  "maxParticipants": 10,
  "participants": ["user123"],  // Solo el creador al inicio
  "status": "active",
  "createdAt": Timestamp(2024-03-14T10:30:00Z),
  "updatedAt": Timestamp(2024-03-14T10:30:00Z)
}
```

---

## 🏆 Flujo: Admin crea TORNEO

### **Admin/Coordinador crea un TORNEO:**

1. **Verificación de rol en Firestore:**

En la colección `users`, agregar un campo `role`:

```json
{
  "uid": "admin123",
  "email": "admin@uniandes.edu.co",
  "fullName": "Juan Administrador",
  "role": "admin",  // 'user' | 'admin'
  "university": "Uniandes",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

2. **Crear torneo (solo si `role == 'admin'`):**

```dart
// En la app, verificar primero:
final userDoc = await _firestore.collection('users').doc(userId).get();
final role = userDoc['role'] ?? 'user';

if (role == 'admin') {
  // Permitir crear torneo
  await EventsRepository().createEvent(
    createdBy: adminUid,
    title: 'Torneo de Fútbol 2024',
    sport: 'futbol',
    modality: EventModality.tournament,
    description: 'Torneo oficial de la universidad',
    location: 'Estadio UniAndes',
    scheduledAt: DateTime.now().add(Duration(days: 30)),
    maxParticipants: 32,
  );
}
```

3. **Documento en Firestore:**
```json
{
  "createdBy": "admin123",
  "title": "Torneo de Fútbol 2024",
  "sport": "futbol",
  "modality": "tournament",
  "description": "Torneo oficial de la universidad",
  "location": "Estadio UniAndes",
  "scheduledAt": Timestamp(2024-04-15T09:00:00Z),
  "maxParticipants": 32,
  "participants": ["admin123"],
  "status": "active",
  "createdAt": Timestamp(2024-03-14T10:30:00Z),
  "updatedAt": Timestamp(2024-03-14T10:30:00Z)
}
```

---

## 📱 Ejemplo: Poblar Base de Datos (Manual para testing)

### **Via Firebase Console:**

1. Ir a **Firestore → Colección `events` → Agregar documento**
2. Dar ID automático o personalizado
3. Agregar los campos manualmente

**Documento 1: Fútbol Casual**
```
Documento ID: event_001

createdBy: "user123" (string)
title: "Fútbol 5v5" (string)
sport: "futbol" (string)
modality: "casual" (string)
description: "Partido amistoso para principiantes" (string)
location: "Cancha 1 - UniAndes Courts" (string)
scheduledAt: 15 de marzo de 2024, 3:00 PM (date)
maxParticipants: 10 (number)
participants: ["user123", "user456", "user789"] (array)
status: "active" (string)
createdAt: 14 de marzo de 2024, 10:30 AM (date)
updatedAt: 14 de marzo de 2024, 10:30 AM (date)
```

**Documento 2: Calistenia Casual**
```
Documento ID: event_002

createdBy: "user456"
title: "Calistenia en el parque"
sport: "calistenia"
modality: "casual"
description: "Entrenamiento de calistenia al aire libre"
location: "Parque central UniAndes"
scheduledAt: 16 de marzo de 2024, 5:00 PM
maxParticipants: 15
participants: ["user456", "user789"]
status: "active"
createdAt: 14 de marzo de 2024, 11:00 AM
updatedAt: 14 de marzo de 2024, 11:00 AM
```

**Documento 3: Running Casual**
```
Documento ID: event_003

createdBy: "user789"
title: "5K Running matutino"
sport: "running"
modality: "casual"
description: "Carrera de 5 kilómetros a ritmo moderado"
location: "Campus UniAndes"
scheduledAt: 15 de marzo de 2024, 6:30 AM
maxParticipants: 25
participants: ["user789", "user123"]
status: "active"
createdAt: 14 de marzo de 2024, 9:15 AM
updatedAt: 14 de marzo de 2024, 9:15 AM
```

---

## 🔍 Índices de Firestore (Important!)

Para que las búsquedas funcionen rápido, crear estos índices:

**Índice 1: sport + modality + status**
```
Colección: events
Campos:
- sport (Ascending)
- modality (Ascending)  
- status (Ascending)
- scheduledAt (Ascending)
```

**Índice 2: createdBy + createdAt**
```
Colección: events
Campos:
- createdBy (Ascending)
- createdAt (Descending)
```

**Índice 3: participants (array-contains)**
```
Colección: events
Campos:
- participants (Contains)
- scheduledAt (Ascending)
```

*Firebase sugerirá crear estos índices automáticamente cuando hagas las queries.*

---

## 💡 Query Ejemplos desde la App

### **Buscar todos los eventos de Fútbol Casual activos:**
```dart
await _firestore
    .collection('events')
    .where('sport', isEqualTo: 'futbol')
    .where('modality', isEqualTo: 'casual')
    .where('status', isEqualTo: 'active')
    .orderBy('scheduledAt')
    .get();
```

### **Obtener todos los eventos creados por un usuario:**
```dart
await _firestore
    .collection('events')
    .where('createdBy', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .get();
```

### **Obtener eventos en los que un usuario participa:**
```dart
await _firestore
    .collection('events')
    .where('participants', arrayContains: userId)
    .orderBy('scheduledAt')
    .get();
```

---

## ✅ Checklist para Poblar BD

- [ ] Crear colección `events` en Firestore
- [ ] Agregar 3-5 documentos de eventos de prueba (diferentes deportes y modalidades)
- [ ] Verificar que `status` sea siempre `active` para eventos visibles
- [ ] Configurar índices de Firestore (sport + modality + status)
- [ ] Agregar campo `role` a documentos de usuario en colección `users`
- [ ] Configurar Security Rules
- [ ] Probar búsquedas desde la app

---

## 🎯 Resumen

- **Usuarios normales** crean eventos con `modality: casual`
- **Admins** crean eventos con `modality: tournament`
- **Participantes** se agregan al array `participants` cuando se unen
- **Estado** controla si aparecen en búsquedas (`active`, `completed`, `cancelled`)
- **Índices** hacen que las búsquedas sean rápidas

¡Listo para empezar a poblar! 🚀

