# Especificaciones Técnicas — TurisApp

> Documento de especificaciones técnicas para el desarrollo y mantenimiento de TurisApp.
> Proyecto: App móvil de turismo para Santa Cruz de la Sierra, Bolivia.

---

## 1. Información general

| Campo | Valor |
|-------|-------|
| Nombre del proyecto | TurisApp |
| Propósito | App móvil de turismo y descubrimiento de lugares en Santa Cruz de la Sierra |
| Plataforma objetivo | Android (APK) |
| Framework | Flutter 3.32.x (Dart 3.8.x) |
| Lenguaje | Dart |
| Backend | Supabase (Auth, Postgres/PostGIS, Storage) |
| Gestión de estado | Provider |
| Idioma de la UI | Español (es-BO) con soporte para es e en |
| Versión actual | 1.0.0+1 |
| Repositorio | https://github.com/AM1-LosTNT/Proyecto-App-Mobile.git |
| Rama principal | main |

---

## 2. Stack tecnológico

### 2.1 Frontend (Flutter)

| Capa | Tecnología | Versión | Uso |
|------|-----------|---------|-----|
| UI | flutter (SDK) | 3.32.x | Interfaz y navegación |
| Localizaciones | flutter_localizations | SDK | i18n en español |
| Gestión de estado | provider | 6.1.5+1 | Estado global (AppState, CartProvider) |
| Mapas | flutter_map | 8.3.2 | Mapa interactivo con teselas |
| Geolocalización | geolocator | 13.0.2 | GPS y permisos de ubicación |
| Mapas (datos) | latlong2 | 0.10.1 | Coordenadas y distancias |
| HTTP | http | 1.2.2 | Peticiones REST genéricas |
| Selección de archivos | file_picker | 11.0.3 | Subir imágenes desde galería |
| Captura de imágenes | image_picker | 1.1.2 | Cámara y galería |
| Criptografía | crypto | 3.0.8 | Hash y utilidades de seguridad |
| Reconocimiento de voz | speech_to_text | 7.4.0 | Asistente por voz |
| Síntesis de voz | flutter_tts | 4.2.5 | Respuesta de voz de la app |
| OCR de texto | google_mlkit_text_recognition | 0.16.0 | Reconocimiento de texto en imágenes |
| Generación PDF | syncfusion_flutter_pdf | 31.1.19 | Comprobantes y reportes en PDF |

### 2.2 Backend (Supabase)

| Servicio | Uso en la app |
|----------|---------------|
| Supabase Auth | Registro, login, recuperación de contraseña, sesiones |
| Postgres + PostGIS | Tablas de usuarios, lugares, categorías, reservas, favoritos, reseñas |
| Supabase Storage | Avatares de usuario, portadas e imágenes de negocios |
| Realtime | Cambios de estado de autenticación |
| RPC (funciones) | `obtener_micros_cercanos`, `planificar_ruta_micros`, triggers de rating |

---

## 3. Estructura del proyecto

```
lib/
├── main.dart                  # Arranque + inicialización de Supabase
├── models/                    # Place, Review, UserProfile, MicroRoute, Order, CartItem
├── providers/                 # Estado global (AppState, CartProvider)
├── services/                  # Supabase, ubicación, clima, transporte, recibos
├── screens/                   # Pantallas por módulo (auth, home, map, admin, business...)
└── theme/app_theme.dart       # Colores y estilos globales
supabase/
└── actualizacion_completa.sql # Rating automático, políticas, Storage, rutas
android/app/src/data/
└── database.sql               # Esquema base de la base de datos
```

---

## 4. Arquitectura y patrones

- **Arquitectura en capas:** UI (screens) → Providers (estado) → Services (datos/Supabase) → Modelos (datos).
- **Estado global:** `AppState` cachea destinos, categorías, favoritos y perfil del usuario. Los favoritos se actualizan de forma optimista.
- **Autenticación:** `AuthGate` controla el flujo entre Splash → Login → MainNavigation según la sesión de Supabase.
- **Roles:** Turista (`user`), Dueño de negocio (`business`), Administrador (`admin`). El rol admin solo se asigna desde SQL.
- **Imágenes:** Subidas a Supabase Storage en rutas `${userId}/...` (avatares) y `${userId}/lugares/...` o `${userId}/portada/...` (negocios).
- **Idioma:** Todo el texto visible está en español; no se menciona el proveedor de backend en pantallas.

---

## 5. Requisitos de entorno

| Herramienta | Versión / nota |
|-------------|----------------|
| Flutter SDK | 3.32.5 stable (mínimo Dart 3.8.1) |
| Git | 2.30 o superior |
| Android Studio | SDK de Android (API 35) y JDK 17 |
| NDK | 27.0.12077973 |
| Dispositivo / emulador | Android 7.0 (API 24) o superior |
| Editor | VS Code con extensión Flutter, o Android Studio con plugin Flutter |

---

## 6. Generación del APK

Script incluido: `compilar_apk.bat`

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Salida en `dist/`:
- `TurisApp-arm64.apk` → para casi cualquier teléfono moderno (recomendado)
- `TurisApp-armv7.apk` → solo para teléfonos muy antiguos de 32 bits

> Los APK generados no se suben al repositorio (están en `.gitignore`).
