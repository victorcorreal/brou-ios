# Brou para iPhone y iPad

La app de Victor Correal que acompaña a Brou para Mac. Comparte por iCloud los favoritos y las contraseñas.

- **Navegar:** un campo para direcciones o búsquedas (Google), sin texto de ejemplo. Pestañas, atrás y adelante (también deslizando), recargar, compartir y copiar la dirección.
- **Bloqueador de anuncios:** el mismo del Mac, compilado dentro de WebKit.
- **Páginas oscuras:** cualquier web clara en oscuro, con fotos y vídeos en su color, como en el Mac.
- **Modo lectura solo texto:** el artículo y nada más, con el título una vez.
- **Favoritos en iCloud:** los mismos registros que Brou para Mac (zona `Search`, tipo `Bookmark`).
- **Contraseñas en el llavero de iCloud:** el mismo grupo que el Mac. Ofrece guardarlas al enviar un formulario, las rellena con un toque y las muestra con Face ID.
- **Filtro por subdominio:** las sugerencias y la llave de la barra muestran solo las cuentas del host abierto. `cms`, `dev` y el dominio principal se mantienen separados. Si no hay cuentas para ese host, la lista queda vacía; "Show All Passwords" permite verlas todas. Se conserva la equivalencia histórica entre `www` y el dominio sin `www`.
- **Contraseñas de la web abierta:** la llave de la barra de acceso abre solo las cuentas de esa web, con cuándo se usó y se guardó cada una. Deslizar a la izquierda borra esa cuenta y ninguna más. "Show All Passwords" vuelve a la lista entera.
- **Navegador predeterminado y pantalla de inicio:** desde la versión 1.0.1, la app incluye el permiso de navegador de Apple (`com.apple.developer.web-browser`), aprobado para `cat.correal.search` el 20 de octubre de 2026. Puedes elegir Brou como navegador predeterminado en Ajustes. "Share" entrega la página al menú de compartir de iOS, que ofrece "Add to Home Screen", con el icono y el nombre de la web. Un icono guardado sin "Open as Web App" abre su web en el navegador predeterminado que hayas elegido.
- **Diseño:** en iPhone (y el Duo plegado), página a pantalla completa con la barra abajo. En iPad (y el Duo abierto), barra lateral con pestañas y favoritos.

Todo lo que comparte con el Mac está descrito en `SINCRONIZACION.md`, en la carpeta `Mac/Search` de Vcode.

## Instalar

```bash
xcodegen generate
```

Después, en Xcode, elige el esquema **Search** y tu iPhone o iPad, y pulsa ⌘R. O desde la terminal:

```bash
xcodebuild -project Search.xcodeproj -scheme Search -destination 'id=<UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> <ruta a Brou.app>
```

Firma con el equipo Great Heights Systems S.L. (`E653G759EN`). Instalada así, dura un año. La distribución pública y el nombre en App Store Connect se preparan por separado. Brou tiene nombre e icono propios.

### Firma y permiso de navegador

El identificador sigue siendo `cat.correal.search`. El contenedor `iCloud.cat.correal.search` y el grupo de llavero compartido tampoco cambian. Para actualizar, instala la nueva compilación sobre la anterior, sin desinstalarla.

La aprobación de Apple permite usar la capacidad, pero el perfil de firma también debe incluirla. En Xcode, abre el target Search → Signing & Capabilities, comprueba el equipo, la firma automática y la capacidad **Default Web Browser**. Deja que Xcode actualice el perfil antes de compilar. La firma del ejecutable y el perfil deben contener `com.apple.developer.web-browser = true`.

Con otro equipo de Apple, necesitas tus propios identificadores, contenedor y grupo de llavero, además de solicitar a Apple el permiso de navegador. Esta aprobación no se transfiere a otra cuenta. Los datos de iCloud y las contraseñas de nuestro equipo tampoco son accesibles desde una compilación de otro equipo.

Este permiso habilita la elección de navegador y la acción de pantalla de inicio. Las contraseñas propias de Brou usan el grupo de llavero compartido; el permiso de navegador no da acceso general a la base de datos de la app Contraseñas de Apple. El permiso de passkeys para navegadores de Mac es otra capacidad.

## Brou 1.1.0 — 21 de octubre de 2026

Nombre visible, nombre del ejecutable e icono propios. El icono usa el mismo original que la app para Mac; véase [Brand/README.md](Brand/README.md). Se conservan `cat.correal.search`, el contenedor y la zona de CloudKit, el grupo y la etiqueta de las contraseñas y la carpeta de datos local. El permiso de navegador aprobado sigue incluido. No se desinstala la versión anterior para actualizar.

El proyecto, el esquema y el target siguen llamándose `Search` para conservar las instrucciones de compilación y facilitar el mantenimiento. La app compilada se llama `Brou.app`.

## Versión 1.0.1 — 21 de octubre de 2026

- Incluye el permiso de navegador predeterminado y permite ofrecer «Añadir a pantalla de inicio» desde Compartir.
- Mantiene el identificador, el contenedor de iCloud, el grupo de contraseñas y el entorno CloudKit Development.
- El plist generado toma la versión y el número de compilación de `MARKETING_VERSION` y `CURRENT_PROJECT_VERSION`, sin valores antiguos que los oculten.

Verificación de la compilación `1792569136`:

- Archivo Release y exportación IPA de desarrollo completados; firma, perfil, capacidad nueva e identidades existentes verificados.
- Instalada sobre la versión 1.0 en el iPhone 16 Pro. Los tres archivos de datos locales conservan el mismo contenido tras actualizar.
- Arranque confirmado en el iPhone; el proceso permanece activo.
- Víctor ha comprobado en el dispositivo que «Añadir a pantalla de inicio» aparece en Compartir y que Search figura en Ajustes entre los navegadores predeterminados.

Estas comprobaciones no incluyen crear y abrir un acceso de pantalla de inicio, cambiar el navegador predeterminado ni volver a validar la sincronización entre dispositivos.

Los archivos de desarrollo están en `build/` y solo sirven en dispositivos registrados en su perfil. No son una publicación de TestFlight o App Store. El código y las notas no incluyen perfiles, certificados ni copias de datos personales.

## Cómo está hecha

- `Sources/Browser.swift`: pestañas, sesión, ajustes, contraseñas ofrecidas y un historial local para las sugerencias.
- `Sources/Tab.swift`: cada página (`WKWebView`), sus scripts y la navegación.
- `Sources/CloudSync.swift`: copia del motor del Mac (`CKSyncEngine`), con la misma lógica y los mismos registros.
- `Sources/Vault.swift`: contraseñas en el grupo compartido del llavero.
- `Sources/Forms.swift`: detecta formularios de acceso, rellena y avisa al enviar.
- `Sources/Shield.swift`: el bloqueador, copiado del Mac.
- `Resources/JS/`: modo oscuro y lectura, los mismos scripts que el Mac (vía Penumbra).

## Probado

En el simulador iPhone 18 Pro (iOS 27.0): sesión restaurada con tres pestañas, páginas oscuras con fotos en su color y la zona de la hora en negro, modo lectura solo texto, añadir favorito, cambiar de pestaña, guardar una contraseña al enviar un formulario y rellenarla después. Las contraseñas de la web abierta (12-oct-2026): con dos cuentas en `localhost` y otra en `127.0.0.1` cuyo usuario contiene "localhost", la llave muestra solo las dos primeras, borra una sin tocar la otra y la barra deja de ofrecerla. Dos cuentas con el mismo usuario en `localhost`, una guardada por http y otra por https, con contraseñas distintas (12-oct-2026): cada una se muestra y se rellena con la suya. En el iPad Pro 11" (M5): barra lateral con pestañas y favoritos. La franja de la hora (18-oct-2026): en guidedoc.tv, al bajar, toma el gris de su cabecera fija y no deja ver los carteles por encima; en Wikipedia es clara; con Páginas oscuras, negra.

No se puede probar en el simulador: la sincronización con iCloud, porque el simulador no tiene cuenta. Se prueba con tu iPhone y tu Mac.

## Licencia

Parte del código viene de Search, de Office Commun, con licencia MIT. Detalle en `NOTICE` y `LICENSE`.

[Password host-scope verification](Docs/PASSWORD_HOST_SCOPE.md).
