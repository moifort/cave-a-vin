# Changelog

## 1.5 (2026.07.29)

### Novedades
- La pantalla Premium se abre ahora con las cifras de la cuenta: los escaneos usados, los que quedan y la fecha de renovación del cupo.
- La ficha de una botella guardada indica ahora su ubicación en la bodega.

### Correcciones
- Una suscripción comprada en la App Store se activa ahora en cuanto se paga.
- Una botella se guarda ahora en la posición elegida, y no en la de al lado.
- La cuadrícula que se muestra al mover una botella tiene ahora las dimensiones de la bodega.
- Algunos textos no seguían el idioma de la aplicación y aparecían siempre en francés. Queda corregido en el panel, en los mensajes de carga y en los ajustes.

## 1.4 (2026.07.22)

### Novedades
- El escaneo de etiquetas dispone ahora de un cupo mensual de cinco escaneos gratuitos. Cuando se agota el cupo del mes, la pantalla de escaneo propone Vinarium Premium. Todo lo demás de la aplicación sigue siendo gratuito y sin límite.
- Vinarium Premium desbloquea el escaneo ilimitado, con una modalidad mensual o una anual que empieza con siete días gratis. La oferta se encuentra en los Ajustes, y la suscripción se gestiona desde la cuenta de App Store.

### Rendimiento
- El panel se abre más rápido.

## 1.3 (2026.07.18)

### Novedades
- Durante un escaneo, la etiqueta fotografiada permanece en pantalla con una animación mientras se ejecuta el análisis, en lugar de una pantalla de carga vacía.
- Cuando un escaneo no reconoce ninguna etiqueta, una pantalla clara lo indica y propone reintentar, en lugar de abrir una ficha vacía.
- La bodega compartida reúne ahora su valor total, sus avisos de botellas listas para beber y su diario para todo el hogar. Cada movimiento del diario muestra al miembro que lo originó.

## 1.2 (2026.07.16)

### Novedades
- El tamaño de la bodega puede cambiarse ahora desde los Ajustes, partiendo de un modelo o definiendo el número de filas y huecos. Las botellas permanecen en su sitio.
- Las botellas de la bodega compartida son ahora accesibles a la búsqueda. Las de todo el hogar aparecen en la lista y la búsqueda, con el nombre de su propietario.
- El nombre aparece en el perfil.

### Correcciones
- Los enlaces de invitación abren ahora la aplicación de forma fiable.

## 1.1 (2026.07.15)

### Novedades
- Un flujo de configuración en el primer inicio pide el nombre y luego las dimensiones de la bodega (número de filas y huecos). El modelo puede elegirse en un catálogo de vinotecas del mercado, con búsqueda por marca o modelo, para un dimensionamiento automático, o las dimensiones se introducen a mano. También se guarda el número de zonas de temperatura.
- El tamaño de la bodega ya no es fijo. Corresponde a las dimensiones elegidas en la configuración, y tanto la cuadrícula de colocación como la capacidad mostrada se adaptan a ellas.
- La barra de pestañas se reduce automáticamente al desplazarse para ampliar la zona de contenido, y el botón Escanear permanece fijo a la derecha.
- En la pantalla de inicio de sesión, el logotipo se anima al abrir, con un mosaico de cápsulas con los colores de la aplicación que aparece en cascada.
- Abrir un enlace de invitación inicia ahora la aplicación directamente en la pantalla que permite unirse al hogar. Si la aplicación no está instalada, la página propone descargarla desde la App Store.
- Cada código de invitación muestra una insignia «Pendiente».

### Correcciones
- Las acciones Copiar enlace, Correo y Revocar se activan ahora de forma independiente. Un solo toque ya no dispara las tres a la vez.

## 1.0 (2026.07.11)

### Novedades
- Compartir la bodega: se invita a las personas del hogar con un código para compartir una única bodega común. Cada uno conserva su biblioteca, sus notas de cata y su diario, y solo las botellas en bodega se ponen en común.
- En una bodega compartida, todas las botellas del hogar aparecen en la misma cuadrícula, con el nombre del propietario en las de los demás. Cualquier miembro puede colocar, mover, consumir o regalar cualquier botella. La salida se registra en el diario del propietario del vino, y cada nota de cata sigue siendo la de su autor.
- En la ficha de un vino de otro miembro se muestra el nombre del propietario y se ocultan las acciones reservadas como editar, eliminar o recomendar.
- Una lupa en la barra de herramientas abre una búsqueda a pantalla completa. Puede escribirse un nombre de vino, un productor, una añada o una persona, y los resultados se ordenan por relevancia y se agrupan con claridad, por ejemplo en bodega, ya bebidos, regalos o recomendados. Sobre los resultados se ofrecen filtros combinables (color, tipo, favorito, en bodega, regalos).
- Las listas señalan de un vistazo las botellas en bodega con un icono de armario.
- Las vistas Regalados y Recomendados ofrecen una nueva ordenación «Por persona» que agrupa la lista por quien regala o recomienda.
- Al escanear, la ventana de añadir solo ofrece ya «Guardar en bodega» y «Solo registrar». El favorito y la recomendación se ajustan ahora directamente en la ficha.
- Todas las bebidas tienen ahora subtipos estructurados (ron, oporto, cerveza rubia, sake espumoso y más), ofrecidos en los formularios y rellenados por el análisis de IA.
- El color de un vino vuelve a ser su capa (tinto, blanco o rosado). Espumoso y Dulce pasan a ser subtipos del vino.
- En el panel, el widget «En bodega» muestra la ocupación de la bodega, con las botellas colocadas sobre la capacidad total (por ejemplo 41/48) y el total en un tamaño menor.
- La pantalla de Ajustes es accesible desde el panel con un icono en la parte superior izquierda.
- Un perfil de usuario permite cerrar sesión.
- La versión de la aplicación y el historial del changelog pueden consultarse.
- Se muestra la información de la bodega (dimensiones y número de botellas colocadas).
- Los datos pueden exportarse e importarse en formato JSON.

### Correcciones
- La lista «Mis vinos» vuelve a mostrarse en lugar de un mensaje de error.

### Rendimiento
- Las listas, la búsqueda y el panel son más rápidos. El servidor agrupa y comparte sus lecturas, sin recargar nunca varias veces los mismos vinos ni recorrer toda la bodega para un simple filtro.
- La apertura de la ficha detallada es mucho más rápida. El servidor lee ahora solo la información del vino consultado en lugar de recorrer toda la bodega.
