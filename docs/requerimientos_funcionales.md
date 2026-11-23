# Requerimientos Funcionales — TurisApp

> Documento que describe qué debe hacer la aplicación TurisApp, organizado por módulos y roles de usuario.

---

## 1. Roles de usuario

| Rol | Descripción | Cómo se asigna |
|-----|-------------|----------------|
| **Turista** (`user`) | Usuario final que explora lugares, hace reservas y guarda favoritos | Al registrarse eligiendo "Turista" |
| **Dueño de negocio** (`business`) | Puede crear y gestionar sus propios lugares y reservas | Al registrarse eligiendo "Dueño de negocio" |
| **Administrador** (`admin`) | Gestión total de usuarios, negocios, categorías y lugares | Solo desde la base de datos (SQL) |

---

## 2. Módulo de Autenticación (Auth)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-AUTH-01 | Registro de usuario | El usuario puede crear cuenta con email, contraseña, nombre y rol (turista o negocio) | Alta |
| RF-AUTH-02 | Inicio de sesión | El usuario autenticado con email y contraseña accede a la app | Alta |
| RF-AUTH-03 | Cierre de sesión | El usuario puede cerrar sesión desde su perfil | Alta |
| RF-AUTH-04 | Recuperación de contraseña | Supabase Auth permite restablecer contraseña por email | Media |
| RF-AUTH-05 | Puerta de autenticación | Si no hay sesión activa se muestra LoginScreen; si existe, MainNavigationScreen | Alta |
| RF-AUTH-06 | Pantalla de carga | Mientras se inicializa Supabase y se carga el perfil, se muestra un Splash con el logo | Media |

---

## 3. Módulo de Inicio y Catálogo (Home)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-HOME-01 | Lista de lugares | Mostrar lugares recomendados ordenados por rating | Alta |
| RF-HOME-02 | Categorías | Mostrar categorías disponibles para filtrar lugares | Alta |
| RF-HOME-03 | Búsqueda de lugares | Buscar lugares por nombre, dirección, descripción, categoría o tipo | Alta |
| RF-HOME-04 | Filtros por categoría | Filtrar la lista de lugares por categoría seleccionada | Alta |

---

## 4. Módulo de Mapa (Map)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-MAP-01 | Mapa interactivo | Mostrar lugares en un mapa con marcadores y teselas | Alta |
| RF-MAP-02 | Búsqueda en mapa | Buscar lugares por texto desde el mapa | Alta |
| RF-MAP-03 | Filtros por categoría en mapa | Filtrar marcadores del mapa por categoría | Alta |
| RF-MAP-04 | Geolocalización | Obtener la ubicación actual del usuario y centrar el mapa | Alta |
| RF-MAP-05 | Permisos de ubicación | Solicitar y gestionar permisos de GPS del dispositivo | Alta |

---

## 5. Módulo de Detalle de Lugar (Details)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-DET-01 | Ver detalle de lugar | Ver nombre, dirección, descripción, categoría, rating y reseñas de un lugar | Alta |
| RF-DET-02 | Ver reseñas | Listar reseñas y calificación promedio de un lugar | Alta |
| RF-DET-03 | Hacer reserva | Crear una reserva para un lugar seleccionado | Alta |
| RF-DET-04 | Acceder a ruta | Desde el detalle, acceder al planificador de rutas en micro | Media |

---

## 6. Módulo de Favoritos (Favorites)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-FAV-01 | Agregar a favoritos | Marcar un lugar como favorito (actualización optimista) | Alta |
| RF-FAV-02 | Quitar de favoritos | Remover un lugar de la lista de favoritos | Alta |
| RF-FAV-03 | Ver favoritos | Listar los lugares marcados como favoritos del usuario | Alta |

---

## 7. Módulo de Perfil (Profile)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-PRF-01 | Ver perfil | Ver nombre, email, rol, avatar y portada del usuario | Alta |
| RF-PRF-02 | Editar perfil | Actualizar nombre, teléfono, nombre de negocio, avatar y portada | Alta |
| RF-PRF-03 | Subir imágenes | Subir foto de avatar y portada a Supabase Storage | Alta |
| RF-PRF-04 | Ver mis reservas | Listar las reservas hechas por el usuario | Alta |
| RF-PRF-05 | Acceso al panel admin | Si el rol es admin, mostrar el Panel de administración | Alta |

---

## 8. Módulo de Planificador de Rutas (Route)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-RUT-01 | Planificar ruta en micro | Calcular ruta entre dos puntos usando micros con tiempo estimado y transbordos | Alta |
| RF-RUT-02 | Micros cercanos | Obtener micros cercanos a una ubicación | Media |
| RF-RUT-03 | Respaldo de ruta | Si el RPC falla, usar respaldo calculado en Dart | Media |

---

## 9. Módulo de Panel de Negocio (Business)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-BIZ-01 | Crear lugar | El dueño de negocio puede registrar un nuevo lugar | Alta |
| RF-BIZ-02 | Editar lugar | Modificar datos de un lugar propio | Alta |
| RF-BIZ-03 | Subir imágenes de lugar | Subir imágenes de los lugares del negocio | Alta |
| RF-BIZ-04 | Ver reservas del negocio | Listar reservas recibidas en los lugares propios | Alta |

---

## 10. Módulo de Panel de Administración (Admin)

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-ADM-01 | Gestionar usuarios | Ver y administrar usuarios del sistema | Alta |
| RF-ADM-02 | Gestionar negocios | Ver y administrar negocios registrados | Alta |
| RF-ADM-03 | Gestionar categorías | Crear, editar y eliminar categorías de lugares | Alta |
| RF-ADM-04 | Gestionar lugares | Ver y administrar todos los lugares de la plataforma | Alta |
| RF-ADM-05 | Gestionar reservas | Ver y administrar todas las reservas del sistema | Alta |

---

## 11. Servicios adicionales

| ID | Requerimiento | Descripción | Prioridad |
|----|---------------|-------------|-----------|
| RF-SVC-01 | Clima | Consultar el clima actual de una ubicación | Media |
| RF-SVC-02 | Asistente de voz | Reconocer comandos de voz y responder con síntesis de voz | Media |
| RF-SVC-03 | OCR | Reconocer texto en imágenes (ej. comprobantes) | Baja |
| RF-SVC-04 | PDF | Generar comprobantes o reportes en PDF | Baja |
