# Mantenimiento compartido con Mac — 21 de octubre de 2026

Las PR #8–#13 están integradas en `main`: permiso de navegador, identidad Brou, contraseñas por host, icono, inicio mínimo y continuidad del fondo bajo la hora. Esta actualización adapta tres correcciones de Search a la arquitectura de la app compañera.

- [aee74ba](https://github.com/driceroland/Search/commit/aee74ba), de manolito: consultar solo atributos al ofrecer cuentas; leer el secreto de la referencia elegida al tocarla. Se conserva la separación entre HTTP y HTTPS, aunque compartan usuario. Antes de rellenar se comprueban de nuevo el host y el esquema de la página activa.
- [4be2fd3](https://github.com/driceroland/Search/commit/4be2fd3), de Bryan Zane: excluir búsquedas, títulos y códigos usando también el nombre accesible y el placeholder. No rellenar el título al buscar el campo de usuario.
- [1b3edc5](https://github.com/driceroland/Search/commit/1b3edc5), de Bryan Zane: comprobar el límite completo de un dominio bloqueado y permitir nombres parecidos.

Los commits originales incluyen la coautoría de Claude Opus 5.5. Se conserva la atribución MIT a Office Commun. La app iPhone no contiene el puente Mac de passkeys, hosts nativos o extensiones; no se añaden para trasladar correcciones que aquí no aplican. Se conserva la equivalencia histórica `www`/dominio raíz; no hay fallback a subdominios vecinos.

## Repetir las pruebas

Requieren macOS con Xcode y WebKit, sin cuenta Apple ni acceso al llavero real:

```sh
python3 Tests/UpstreamRegression/run.py
```

Se compila el Vault de producción con un adaptador Security local de datos sintéticos (6 comprobaciones). El segundo ejecutable usa los scripts de producción en un WKWebView efímero y el compilador real de reglas WebKit (13 comprobaciones). No abre páginas externas, no utiliza datos del navegador y no configura iCloud. Las seis más trece comprobaciones pasan.

Para compilar la app sin firma para el simulador, con XcodeGen instalado:

```sh
xcodegen generate
xcodebuild -project Search.xcodeproj -scheme Search -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO build
```

El build de simulador y el archivo Release para dispositivo se han completado. El archivo Release usa la configuración de desarrollo existente: bundle ID `cat.correal.search`, mismo grupo de llavero, contenedor CloudKit y entorno Development, con permiso de navegador. El número de compilación sube; no se cambia la versión visible 1.1.0.

## Límites

Las pruebas del Vault verifican consultas y selección de referencias con un adaptador, no el llavero real de iOS. El WebKit de macOS permite verificar el JavaScript compartido, pero no sustituye una comprobación de interfaz en un iPhone. Esta actualización no se ha instalado todavía en el teléfono. Falta repetir el flujo entre Mac e iPhone, cambios sin conexión, conflictos, borrados y cambios de cuenta. No afirmar que estas comprobaciones acreditan la sincronización de iCloud.

No cambian las pantallas iniciales aprobadas, el foco del buscador ni el menú inferior. No se han publicado versiones, cambiado la visibilidad del repositorio ni enviado solicitudes externas.

## Later device verification

The basic physical Mac/iPhone journeys were subsequently checked on 21 October 2026; see [VERIFICATION.md](VERIFICATION.md). Earlier statements above about untested cross-device sync describe the integration stage. Offline/conflict/account-switch coverage remains pending.
