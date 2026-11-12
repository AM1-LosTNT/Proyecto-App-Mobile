# TurisApp

Aplicación móvil de turismo para Santa Cruz de la Sierra, construida en **Flutter**
con **Supabase** como backend (autenticación, base de datos Postgres/PostGIS y
almacenamiento de imágenes).

## Funcionalidades

- Registro e inicio de sesión con roles: **Turista**, **Dueño de negocio** y **Administrador**
- Inicio con lugares recomendados y categorías
- Mapa interactivo con búsqueda por texto y filtros por categoría
- Detalle de lugares con reseñas, calificación promedio y reservas
- Favoritos con actualización instantánea
- Planificador de rutas en micro con tiempo estimado y transbordos
- Perfil con foto de portada y avatar
- Panel de administración: usuarios, negocios, categorías, lugares y reservas
- Panel de negocio: crear y editar lugares, subir imágenes y gestionar reservas

## Requisitos

- Flutter 3.32.x (Dart 3.8.x)
- Android Studio con SDK de Android y JDK 17
- Un dispositivo o emulador Android 7.0 (API 24) o superior
- Git

## Inicio rápido

```bash
git clone https://github.com/AM1-LosTNT/Proyecto-App-Mobile.git
cd Proyecto-App-Mobile
flutter pub get
flutter run
```

Las credenciales de Supabase ya están configuradas en `lib/main.dart`, por lo que la
app funciona sin pasos adicionales. Puedes verificar el estado del proyecto con:

```bash
flutter analyze
flutter test
```

## Estructura

```
lib/
├── main.dart                  # Arranque e inicialización de Supabase
├── models/                    # Modelos de datos
├── providers/                 # Estado global (destinos, favoritos, perfil)
├── services/                  # Supabase, ubicación y transporte
├── screens/                   # Pantallas por módulo (auth, map, admin, business...)
└── theme/                     # Tema visual
supabase/
└── actualizacion_completa.sql # Rating automático, políticas, Storage y rutas
android/app/src/data/
└── database.sql               # Esquema base de la base de datos
```

## Documentación para colaboradores

Lee **[GUIA_COLABORADOR.md](GUIA_COLABORADOR.md)** para el paso a paso completo:
instalación, base de datos, roles, flujo de ramas y Pull Requests, y solución de
problemas comunes.

## Notas

- El proyecto usa únicamente Supabase; no contiene Firebase ni servicios de Google.
- La clave incluida en el cliente es la `publishableKey`, segura para distribución.
  Nunca agregues la clave `service_role` al repositorio.
