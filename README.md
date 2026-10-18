# Search para iPhone, iPad y iPhone Duo

La app de Victor que acompaña a su Search para Mac. Comparte por iCloud los favoritos y las contraseñas.

- **Navegar:** un campo para direcciones o búsquedas (Google), sin texto de ejemplo. Pestañas, atrás y adelante (también deslizando), recargar, compartir y copiar la dirección.
- **Bloqueador de anuncios:** el mismo del Mac, compilado dentro de WebKit.
- **Páginas oscuras:** cualquier web clara en oscuro, con fotos y vídeos en su color, como en el Mac.
- **Modo lectura solo texto:** el artículo y nada más, con el título una vez.
- **Favoritos en iCloud:** los mismos registros que Search para Mac (zona `Search`, tipo `Bookmark`).
- **Contraseñas en el llavero de iCloud:** el mismo grupo que el Mac. Ofrece guardarlas al enviar un formulario, las rellena con un toque y las muestra con Face ID.
- **Contraseñas de la web abierta:** la llave de la barra de acceso abre solo las cuentas de esa web, con cuándo se usó y se guardó cada una. Deslizar a la izquierda borra esa cuenta y ninguna más. "Show All Passwords" vuelve a la lista entera.
- **Añadir a pantalla de inicio:** "Share" pasa la página entera al menú de compartir de iOS, como Chrome. iOS ofrece entonces "Add to Home Screen", con el icono y el nombre de la web. Solo aparece cuando Search tiene el permiso de navegador de Apple (`com.apple.developer.web-browser`), que hay que pedir a Apple. Con ese permiso, Search también puede ser el navegador predeterminado: los enlaces de otras apps se abren en Search, y un icono guardado sin "Open as Web App" abre su web en Search.
- **Diseño:** en iPhone (y el Duo plegado), página a pantalla completa con la barra abajo. En iPad (y el Duo abierto), barra lateral con pestañas y favoritos.

Todo lo que comparte con el Mac está descrito en `SINCRONIZACION.md`, en la carpeta `Mac/Search` de Vcode.

## Instalar

```bash
xcodegen generate
```

Después, en Xcode, elige el esquema **Search** y tu iPhone o iPad, y pulsa ⌘R. O desde la terminal:

```bash
xcodebuild -project Search.xcodeproj -scheme Search -destination 'id=<UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> <ruta a Search.app>
```

Firma con el equipo Great Heights Systems S.L. (`E653G759EN`). Instalada así, dura un año. No está en la App Store: el nombre "Search" es de Office Commun.

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
