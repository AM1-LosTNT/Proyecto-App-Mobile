# Casos de Uso — TurisApp

> Documento que describe los escenarios principales de interacción entre los usuarios y el sistema, organizados por rol.

---

## Convenciones

- **Actor:** Usuario que inicia el caso de uso.
- **Precondiciones:** Lo que debe cumplirse antes de iniciar.
- **Flujo principal:** Pasos normales del caso de uso.
- **Postcondiciones:** Qué queda hecho al finalizar.
- **Excepciones:** Qué pasa si algo falla.

---

## CU-01: Registrarse como nuevo usuario

**Actor:** Visitante (sin sesión)  
**Precondiciones:** App instalada, conexión a internet, Supabase disponible.

**Flujo principal:**
1. El visitante abre la app y ve la pantalla de login/registro.
2. Selecciona "Registrarse".
3. Ingresa email, contraseña, nombre y selecciona rol (Turista o Dueño de negocio).
4. Presiona "Registrar".
5. Supabase Auth crea la cuenta y se crea el perfil en la tabla `usuarios`.
6. La app redirige a la pantalla de inicio (MainNavigationScreen).

**Postcondiciones:** El usuario tiene cuenta activa y sesión iniciada.

**Excepciones:**
- Si el email ya existe, se muestra error: "Este correo ya está registrado".
- Si no hay internet, se muestra error de conexión y se permite reintentar.

---

## CU-02: Iniciar sesión

**Actor:** Usuario registrado  
**Precondiciones:** Tener cuenta creada en Supabase Auth.

**Flujo principal:**
1. El usuario abre la app y ve la pantalla de login.
2. Ingresa email y contraseña.
3. Presiona "Iniciar sesión".
4. Supabase valida las credenciales y restaura la sesión.
5. `AuthGate` redirige a MainNavigationScreen.

**Postcondiciones:** Sesión activa y acceso a las pantallas principales según el rol.

**Excepciones:**
- Credenciales incorrectas → error "Email o contraseña incorrectos".
- Sin conexión → error de red con opción de reintentar.

---

## CU-03: Cerrar sesión

**Actor:** Usuario autenticado  
**Precondiciones:** Sesión iniciada.

**Flujo principal:**
1. Desde el perfil, el usuario selecciona "Cerrar sesión".
2. `AppState.signOut()` cierra la sesión en Supabase.
3. `AuthGate` redirige a LoginScreen.

**Postcondiciones:** Sesión cerrada; se requiere iniciar sesión de nuevo para usar la app.

---

## CU-04: Explorar lugares (catálogo)

**Actor:** Cualquier usuario (incluso sin sesión para ver público)  
**Precondiciones:** App inicializada y datos cargados de Supabase.

**Flujo principal:**
1. Desde el inicio, el usuario ve la lista de lugares ordenados por rating.
2. Puede filtrar por categoría o buscar por texto (nombre, dirección, descripción).
3. Al seleccionar un lugar, navega a su pantalla de detalle.

**Postcondiciones:** El usuario ha visto la lista filtrada/buscada de lugares.

**Excepciones:**
- Si falla la carga de datos, se muestra "No se pudieron cargar los datos. Desliza para reintentar".

---

## CU-05: Ver detalle de un lugar

**Actor:** Usuario  
**Precondiciones:** Haber seleccionado un lugar del catálogo o mapa.

**Flujo principal:**
1. Se muestra la pantalla de detalle con nombre, dirección, descripción, categoría, rating y reseñas.
2. El usuario puede leer las reseñas y ver la calificación promedio.
3. Puede reservar el lugar (si es turista) o ver opciones de ruta en micro.

**Postcondiciones:** El usuario conoce los detalles del lugar seleccionado.

---

## CU-06: Agregar / quitar lugar a favoritos

**Actor:** Usuario autenticado  
**Precondiciones:** Sesión iniciada.

**Flujo principal:**
1. Desde el detalle o el catálogo, el usuario presiona el ícono de favorito.
2. `AppState.toggleFavorite()` actualiza optimista y localmente.
3. Se sincroniza con Supabase (`setFavorito`).
4. Si el servidor falla, se revierte el cambio local.

**Postcondiciones:** El lugar está guardado o eliminado de los favoritos del usuario.

---

## CU-07: Hacer una reserva

**Actor:** Turista autenticado  
**Precondiciones:** Sesión iniciada; haber seleccionado un lugar.

**Flujo principal:**
1. Desde el detalle del lugar, el usuario selecciona reservar.
2. Se crea el registro de reserva en Supabase vinculado al usuario y al lugar.
3. La reserva aparece en "Mis reservas" del perfil.

**Postcondiciones:** Reserva creada y visible en el perfil del usuario y en el negocio correspondiente.

---

## CU-08: Ver y editar perfil

**Actor:** Usuario autenticado  
**Precondiciones:** Sesión iniciada.

**Flujo principal:**
1. Desde el menú, el usuario accede a su perfil.
2. Ve nombre, email, rol, avatar y portada.
3. Puede editar nombre, teléfono, nombre de negocio y subir imágenes.
4. Al guardar, se actualiza en Supabase (tabla `usuarios` y metadatos de auth).

**Postcondiciones:** Perfil actualizado en la base de datos.

---

## CU-09: Planificar ruta en micro

**Actor:** Usuario  
**Precondiciones:** Ubicación disponible (GPS) y conexión a internet.

**Flujo principal:**
1. El usuario abre el planificador de rutas.
2. Indica origen y destino (o usa ubicación actual).
3. La app llama al RPC `planificar_ruta_micros` de Supabase.
4. Se muestra la ruta con micros, tiempos estimados y transbordos.
5. Si el RPC falla, `TransportService` usa un respaldo calculado en Dart.

**Postcondiciones:** El usuario tiene una ruta sugerida en transporte público.

---

## CU-10: Crear y gestionar lugar (Dueño de negocio)

**Actor:** Dueño de negocio autenticado  
**Precondiciones:** Rol `business` asignado.

**Flujo principal:**
1. Desde el panel de negocio, el dueño selecciona "Crear lugar".
2. Completa nombre, dirección, categoría, descripción y sube imágenes.
3. El lugar se guarda vinculado a su usuario.
4. Puede editar o eliminar sus propios lugares y ver sus reservas.

**Postcondiciones:** Lugar creado y visible en el catálogo para todos los usuarios.

---

## CU-11: Panel de administración (Administrador)

**Actor:** Administrador autenticado  
**Precondiciones:** Rol `admin` asignado desde SQL.

**Flujo principal:**
1. Desde el perfil, el admin accede al Panel de administración.
2. Puede gestionar usuarios, negocios, categorías, lugares y reservas de toda la plataforma.
3. Puede asignar rol de admin a otros usuarios desde SQL.

**Postcondiciones:** Cambios administrativos aplicados en la base de datos.

---

## CU-12: Recuperar contraseña

**Actor:** Usuario con cuenta  
**Precondiciones:** Acceso al email registrado.

**Flujo principal:**
1. En la pantalla de login, selecciona "¿Olvidaste tu contraseña?".
2. Ingresa su email.
3. Supabase envía un enlace de restablecimiento al correo.
4. El usuario sigue el enlace y crea una nueva contraseña.

**Postcondiciones:** Contraseña actualizada y puede iniciar sesión con la nueva.

---

## Matriz de casos de uso por rol

| Caso de uso | Turista | Dueño de negocio | Administrador | Visitante (sin sesión) |
|-------------|---------|------------------|---------------|------------------------|
| CU-01 Registrarse | ✅ | ✅ | — | ✅ |
| CU-02 Iniciar sesión | ✅ | ✅ | ✅ | ✅ |
| CU-03 Cerrar sesión | ✅ | ✅ | ✅ | — |
| CU-04 Explorar lugares | ✅ | ✅ | ✅ | ✅ (público) |
| CU-05 Ver detalle | ✅ | ✅ | ✅ | ✅ |
| CU-06 Favoritos | ✅ | ✅ | ✅ | — |
| CU-07 Reservar | ✅ | ✅ | ✅ | — |
| CU-08 Editar perfil | ✅ | ✅ | ✅ | — |
| CU-09 Ruta en micro | ✅ | ✅ | ✅ | ✅ |
| CU-10 Gestionar lugar (negocio) | — | ✅ | ✅ | — |
| CU-11 Panel de administración | — | — | ✅ | — |
| CU-12 Recuperar contraseña | ✅ | ✅ | ✅ | ✅ |
