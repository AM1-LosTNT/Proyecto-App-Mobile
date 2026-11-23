# Requerimientos No Funcionales — TurisApp

> Documento que describe las restricciones de calidad, rendimiento, seguridad, usabilidad y operatividad del sistema TurisApp.

---

## 1. Rendimiento

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-PERF-01 | Tiempo de inicio | La app debe inicializar Supabase y mostrar la primera pantalla | Menos de 5 segundos en dispositivo medio |
| RNF-PERF-02 | Carga de lugares | La lista de lugares y categorías debe cargar rápidamente | Menos de 3 segundos con conexión estable |
| RNF-PERF-03 | Actualización optimista | Favoritos y reseñas deben reflejarse al instante sin esperar al servidor | Cambio visible en < 500 ms |
| RNF-PERF-04 | Mapa fluido | El mapa debe moverse y hacer zoom sin trabarse | 30+ fps en dispositivos compatibles |
| RNF-PERF-05 | Tamaño del APK | El APK de release debe ser liviano para facilitar su distribución | Menos de 30 MB (APK arm64) |
| RNF-PERF-06 | Consumo de batería | El uso de GPS y mapa no debe drenar la batería de forma excesiva | Uso razonado de ubicación en segundo plano |

---

## 2. Disponibilidad y confiabilidad

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-DISP-01 | Base de datos compartida | La app usa un proyecto de Supabase compartido ya configurado | Funciona al clonar sin configurar backend |
| RNF-DISP-02 | Fallo de red | Si falla la conexión, la app muestra mensaje de error amable y permite reintentar | No cierra inesperadamente |
| RNF-DISP-03 | Fallo de RPC | Si `planificar_ruta_micros` falla, `TransportService` usa respaldo calculado en Dart | La app sigue funcionando sin la ruta exacta |
| RNF-DISP-04 | Sincronización de favoritos | Si el servidor rechaza un favorito, se revierte el cambio local | El estado local y remoto coinciden |
| RNF-DISP-05 | Carga del perfil | El trigger de la base puede tardar; se reintentan hasta 3 consultas | El perfil se carga correctamente tras registro |

---

## 3. Seguridad

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-SEG-01 | Clave publishable | Solo se usa la `publishableKey` de Supabase en el cliente (segura para distribución) | Nunca se expone la `service_role` |
| RNF-SEG-02 | No subir claves privadas | No se suben `.env`, `key.properties`, keystores (`.jks`) ni claves de servicio | Revisado en checklist de Pull Request |
| RNF-SEG-03 | Autenticación requerida | Acciones como favoritos, reservas y perfil requieren sesión iniciada | Se valida `isLoggedIn` antes de ejecutar |
| RNF-SEG-04 | Políticas de base de datos | Supabase aplica Row Level Security (RLS) sobre tablas | Usuarios solo acceden a sus propios datos salvo admin |
| RNF-SEG-05 | Validación de entrada | Los datos de formularios se validan antes de enviarse al backend | No se envían datos vacíos o malformados |

---

## 4. Usabilidad

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-USR-01 | Idioma | Toda la interfaz está en español (es-BO) | Textos consistentes en español |
| RNF-USR-02 | Retroalimentación | La app muestra indicadores de carga y mensajes de error claros | Usuario siempre sabe qué está pasando |
| RNF-USR-03 | Navegación intuitiva | Navegación por pestañas inferiores con secciones claramente etiquetadas | Acceso rápido a Home, Mapa, Favoritos, Perfil |
| RNF-USR-04 | Pantalla de carga | Mientras inicializa, se muestra un Splash con el logo de TurisApp | No se muestra pantalla en blanco al iniciar |

---

## 5. Compatibilidad

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-CMP-01 | Versión mínima de Android | Android 7.0 (API 24) o superior | Instalable en dispositivos con API 24+ |
| RNF-CMP-02 | Arquitecturas ARM | Soporta arm64-v8a (recomendado) y armeabi-v7a (legacy 32 bits) | APK generado por ABI separado |
| RNF-CMP-03 | Orientación | Diseño adaptado principalmente a modo retrato | UI correcta en retrato |
| RNF-CMP-04 | Idiomas soportados | español (es-BO), es, en | Cambio de idioma sin reiniciar la app |

---

## 6. Mantenibilidad

| ID | Requerimiento | Descripción | Criterio de aceptación |
|----|---------------|-------------|------------------------|
| RNF-MNT-01 | Análisis estático | `flutter analyze` sin issues ni warnings | Código limpio antes de cada commit |
| RNF-MNT-02 | Formato consistente | `dart format .` aplicado | Estilo de código uniforme |
| RNF-MNT-03 | Documentación | Carpeta `docs/` con especificaciones, requisitos y casos de uso | Documentación actualizada |
| RNF-MNT-04 | Ramas de Git | Cada cambio en su propia rama con Pull Request | Nunca trabajar directamente sobre `main` |
| RNF-MNT-05 | Archivos excluidos | `build/`, `.dart_tool/`, `.idea/`, APKs, keystores no se suben al repo | `.gitignore` configurado correctamente |
