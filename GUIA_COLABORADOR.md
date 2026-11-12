# Guía para colaboradores — TurisApp (Flutter + Supabase)

Esta guía explica cómo una persona nueva puede descargar, configurar, ejecutar y
modificar el proyecto **TurisApp** sin romper nada.

- Repositorio: <https://github.com/AM1-LosTNT/Proyecto-App-Mobile>
- Rama principal: `main`
- Stack: Flutter 3.32.x · Dart 3.8.x · Supabase (Auth, Postgres/PostGIS, Storage)

---

## 1. Requisitos previos

Instala y verifica estas herramientas **antes** de clonar:

| Herramienta | Versión / nota |
|---|---|
| Flutter SDK | 3.32.5 stable (mínimo Dart 3.8.1) |
| Git | 2.30 o superior |
| Android Studio | Con SDK de Android (API 35) y **JDK 17** |
| NDK | 27.0.12077973 (lo pide `android/app/build.gradle.kts`) |
| Dispositivo / emulador | Android 7.0 (API 24) o superior |
| Editor | VS Code con extensión Flutter, o Android Studio con plugin Flutter |

Comprueba que todo esté correcto:

```bash
flutter --version
flutter doctor -v
```

`flutter doctor` debe mostrar en verde Flutter, Android toolchain y, si usas Mac,
Xcode. Si algo sale en rojo, corrígelo antes de continuar.

> Solo para iOS se necesita una Mac con Xcode. En Windows se puede desarrollar y
> probar todo lo de Android.

---

## 2. Clonar el repositorio

```bash
git clone https://github.com/AM1-LosTNT/Proyecto-App-Mobile.git
cd Proyecto-App-Mobile
```

Instala las dependencias de Dart/Flutter:

```bash
flutter pub get
```

Verifica que el proyecto esté sano:

```bash
flutter analyze     # no debe mostrar issues
flutter test        # deben pasar todos los tests
```

---

## 3. Ejecutar la app

1. Conecta un teléfono con depuración USB activada o abre un emulador de Android.
2. Confirma que Flutter lo detecta:

```bash
flutter devices
```

3. Ejecuta:

```bash
flutter run
```

Para compilar el APK de prueba:

```bash
flutter build apk --debug
# resultado: build/app/outputs/flutter-apk/app-debug.apk
```

### Importante sobre la base de datos

**La base de datos ya está creada y funcionando en un proyecto de Supabase
compartido.** Las credenciales están en `lib/main.dart` (URL y
`publishableKey`), así que la app funciona al clonarla, sin configuración extra.

- La `publishableKey` es pública y está pensada para ir en el cliente.
- **Nunca** agregues la clave `service_role` al código: esa clave salta todas las
  políticas de seguridad y solo se usa en el servidor.
- Si necesitas entrar al panel de Supabase (tablas, usuarios, Storage), pídele
  acceso al administrador del proyecto. No se comparte por el repositorio.

---

## 4. Base de datos: cómo está armada

El proyecto usa Postgres + PostGIS. Todo el esquema vive en dos archivos:

| Archivo | Uso |
|---|---|
| `android/app/src/data/database.sql` | Esquema base: tablas, relaciones y políticas iniciales |
| `supabase/actualizacion_completa.sql` | Actualización idempotente: rating automático, políticas de admin, Storage, rutas en micro |

### Si trabajas sobre el proyecto compartido

No hace falta ejecutar nada: la base ya tiene los dos scripts aplicados.

### Si creas tu propio proyecto de Supabase (para pruebas)

1. Crea el proyecto en <https://supabase.com>.
2. En **Database → Extensions**, habilita `postgis`, `uuid-ossp` y `pgcrypto`.
3. Abre **SQL Editor** y ejecuta, en este orden:
   1. `android/app/src/data/database.sql`
   2. `supabase/actualizacion_completa.sql`
4. En **Authentication → Providers → Email**, desactiva "Confirm email" mientras
   desarrollas, para poder registrarte sin revisar el correo.
5. Copia la URL y la `publishableKey` de tu proyecto (Settings → API) y
   reemplázalas en `lib/main.dart`.

El script `actualizacion_completa.sql` crea automáticamente los buckets públicos
`avatars` y `business-images`, con sus políticas de acceso.

---

## 5. Roles y cuentas de prueba

La tabla `usuarios` tiene la columna `rol`, con tres valores posibles:

| Rol | Cómo se obtiene |
|---|---|
| `user` | Al registrarse eligiendo **Turista** |
| `business` | Al registrarse eligiendo **Dueño de negocio** |
| `admin` | Solo se asigna desde la base de datos |

Para convertir una cuenta en administradora, regístrate primero en la app y luego
ejecuta en el SQL Editor:

```sql
update public.usuarios
set rol = 'admin'
where email = 'correo@ejemplo.com';
```

Vuelve a iniciar sesión en la app y aparecerá el **Panel de administración** en la
pantalla de Perfil.

Cuentas recomendadas para probar todo:

1. Un turista (favoritos, reseñas, reservas, rutas).
2. Un dueño de negocio (crear lugares, subir imágenes, ver reservas).
3. Un administrador (gestionar usuarios, negocios, categorías y reservas).

---

## 6. Flujo de trabajo con Git

**Nunca trabajes directamente sobre `main`.** Cada cambio va en su propia rama y
se integra con un Pull Request.

```bash
# 1. Actualiza tu copia
git checkout main
git pull origin main

# 2. Crea tu rama (usa un nombre descriptivo)
git checkout -b feat/filtro-precio-mapa

# 3. Trabaja y guarda cambios
git status
git diff
git add lib/screens/map/map_screen.dart
git commit -m "Agrega filtro por precio en el mapa"

# 4. Sube la rama
git push -u origin feat/filtro-precio-mapa

# 5. Abre el Pull Request en GitHub y pide revisión
```

Antes de cada commit, revisa dos cosas:

```bash
flutter analyze     # sin errores ni warnings
dart format .       # formato consistente
```

### Qué NO se debe subir al repositorio

Ya está protegido por `.gitignore`, pero tenlo presente:

- `build/`, `.dart_tool/`, `.gradle/`, `.idea/`, `*.iml`
- APKs o AAB generados
- Archivos `.env`, `key.properties`, keystores (`.jks`)
- Claves `service_role` de Supabase
- `google-services.json` (el proyecto ya no usa Firebase)

Si por error agregaste algo de esto:

```bash
git rm --cached archivo
git commit -m "Elimina archivo que no debía subirse"
```

---

## 7. Estructura del proyecto

```
lib/
├── main.dart                  # Arranque + inicialización de Supabase
├── models/                    # Place, Review, UserProfile, MicroRoute
├── providers/app_state.dart   # Estado global: destinos, categorías, favoritos, perfil
├── services/
│   ├── supabase_service.dart  # Auth, tablas, Storage y RPC
│   ├── location_service.dart  # GPS y permisos
│   └── transport_service.dart # Rutas en micro y tiempos estimados
├── screens/
│   ├── auth/                  # Login, registro por rol, puerta de sesión
│   ├── home/                  # Inicio y recomendados
│   ├── map/                   # Mapa, búsqueda y filtros
│   ├── details/               # Detalle, reseñas, reservas y acceso a ruta
│   ├── favorites/             # Lugares guardados
│   ├── profile/               # Perfil, mis reservas, subida de imágenes
│   ├── route/                 # Planificador de micros
│   ├── admin/                 # Panel de administración
│   └── business/              # Panel de negocio, formulario y selector de mapa
└── theme/app_theme.dart       # Colores y estilos globales
```

### Lógica que conviene conocer antes de tocar código

- **Estado global:** `AppState` cachea destinos, categorías, favoritos y perfil.
  Los favoritos se actualizan de forma optimista (se ven al instante) y luego se
  sincronizan con Supabase. No recargues datos manualmente si ya están cacheados.
- **Reseñas:** hay una sola reseña por usuario y lugar (`upsert` sobre
  `id_destino, id_usuario`). Un trigger en la base recalcula `rating` y
  `total_reviews`, por eso el promedio se ve al instante sin recargar.
- **Rutas en micro:** usan las funciones `obtener_micros_cercanos` y
  `planificar_ruta_micros`. Si el RPC falla, `TransportService` tiene un respaldo
  calculado en Dart.
- **Imágenes:** se suben a Supabase Storage en `${userId}/...` (avatares) y
  `${userId}/portada/...` o `${userId}/lugares/...` (negocios).
- **Idioma de la UI:** todo el texto visible está en español y no se menciona el
  proveedor de backend en ninguna pantalla.

---

## 8. Problemas comunes

### `flutter doctor` marca el Android toolchain en rojo

Abre Android Studio → **Settings → Languages & Frameworks → Android SDK** e
instala el SDK de Android y las Build Tools. Acepta las licencias:

```bash
flutter doctor --android-licenses
```

### Error de Gradle por versión de Java

El proyecto necesita **JDK 17**. En Android Studio ve a
**Settings → Build, Execution, Deployment → Build Tools → Gradle** y elige
"Gradle JDK 17". Luego:

```bash
flutter clean
flutter pub get
flutter run
```

### `Could not find com.android.tools.build:gradle` o similar

Suele ser caché corrupta de Gradle:

```bash
cd android
./gradlew --stop      # en Windows: gradlew.bat --stop
cd ..
flutter clean
flutter pub get
```

### La app no pide ubicación o el mapa no centra

- Verifica que el permiso de ubicación esté concedido en los ajustes del teléfono.
- En el emulador, define una ubicación simulada en **Extended controls → Location**.
- El mapa necesita internet para descargar las teselas.

### `permission denied for table ...` o una lista aparece vacía

- Confirma que iniciaste sesión.
- En el proyecto compartido, la base ya tiene las políticas aplicadas.
- En un proyecto propio, asegúrate de haber ejecutado `actualizacion_completa.sql`.
- Si `postgis` no está habilitado, las funciones de distancia fallan: habilítalo
  en **Database → Extensions**.

### Error al registrarse con correo

En **Authentication → Providers → Email**, desactiva la confirmación por correo
para desarrollo, o confirma el enlace que llega al buzón.

### La app compila pero no muestra lugares

La base compartida debe tener registros en `destinos_lugares`. Puedes crear
lugares desde una cuenta `business` en la app o desde el panel de administración.

### Cambios que no se reflejan

```bash
flutter clean
flutter pub get
flutter run
```

Si el cambio es de código nativo (permisos, dependencias, Gradle), desinstala la
app del dispositivo y vuelve a ejecutar.

---

## 9. Checklist antes de abrir un Pull Request

- [ ] `flutter analyze` sin issues
- [ ] `flutter test` pasa
- [ ] `dart format .` aplicado
- [ ] La app corre en un dispositivo/emulador real
- [ ] Probé el flujo afectado con el rol correspondiente (turista, negocio, admin)
- [ ] No subí `build/`, `.idea/`, APKs, keystores ni claves privadas
- [ ] El PR explica qué cambia y cómo probarlo

---

## 10. Contacto y accesos

- **Repositorio:** <https://github.com/AM1-LosTNT/Proyecto-App-Mobile>
- **Panel de Supabase:** pídelo al administrador del proyecto.
- **Dudas de arquitectura:** revisa primero `lib/services/supabase_service.dart` y
  `lib/providers/app_state.dart`; ahí está casi toda la lógica de datos.
