# Space Base Odyssey - Documentación del proyecto (español)

NASA Space Apps Challenge 2026, reto "Build a Junior Astronaut Mission Trainer". Este documento reúne toda la documentación del proyecto: panorama general, cómo jugar, ciencia y datos de la NASA, diseño técnico, registro de desarrollo, y fuentes, créditos y licencias. La versión en inglés está en [DOCUMENTATION.md](DOCUMENTATION.md).

## Contenido

- [1. Panorama general](#1-panorama-general)
  - [Qué es el juego](#qué-es-el-juego)
  - [Para quién es](#para-quién-es)
  - [La idea central: cada decisión cuesta algo](#la-idea-central-cada-decisión-cuesta-algo)
  - [Cómo responde el juego al reto](#cómo-responde-el-juego-al-reto)
  - [Resumen general del proyecto](#resumen-general-del-proyecto)
  - [Beneficios para niñas y niños](#beneficios-para-niñas-y-niños)
  - [El equipo](#el-equipo)
  - [Estado actual](#estado-actual)
  - [Enlaces](#enlaces)
  - [Evidencia para el jurado](#evidencia-para-el-jurado)
- [2. Cómo jugar](#2-cómo-jugar)
  - [2.1 El menú de inicio](#21-el-menú-de-inicio)
  - [2.2 El aterrizaje](#22-el-aterrizaje)
  - [2.3 La pantalla (HUD)](#23-la-pantalla-hud)
  - [2.4 C.A.R.L., el robot guía](#24-carl-el-robot-guía)
  - [2.5 Mundo abierto y aventuras](#25-mundo-abierto-y-aventuras)
  - [2.6 Misiones](#26-misiones)
  - [2.7 Construir por pasos](#27-construir-por-pasos)
  - [2.8 Niveles de base (el hábitat es el ayuntamiento)](#28-niveles-de-base-el-hábitat-es-el-ayuntamiento)
  - [2.9 Herramientas](#29-herramientas)
  - [2.10 Equipo](#210-equipo)
  - [2.11 Habilidades](#211-habilidades)
  - [2.12 Créditos, XP, niveles y ritmo](#212-créditos-xp-niveles-y-ritmo)
  - [2.13 La línea de hielo: taladros, silo, planta de agua y robot de carga](#213-la-línea-de-hielo-taladros-silo-planta-de-agua-y-robot-de-carga)
  - [2.14 Vehículos y el garaje](#214-vehículos-y-el-garaje)
  - [2.15 Mascotas y vestidor](#215-mascotas-y-vestidor)
  - [2.16 Explorar la Luna](#216-explorar-la-luna)
  - [2.17 Secretos, coleccionables y códigos](#217-secretos-coleccionables-y-códigos)
  - [2.18 Módulos presurizados y tubos transitables](#218-módulos-presurizados-y-tubos-transitables)
  - [2.19 La cápsula de suministros diaria](#219-la-cápsula-de-suministros-diaria)
  - [2.20 La Bitácora lunar](#220-la-bitácora-lunar)
  - [2.21 C.A.R.L. pregunta, y el glosario con imágenes](#221-carl-pregunta-y-el-glosario-con-imágenes)
  - [2.22 Celebraciones](#222-celebraciones)
  - [2.23 Sonido y música](#223-sonido-y-música)
  - [2.24 Configuración y Ayudas](#224-configuración-y-ayudas)
  - [2.25 Controles](#225-controles)
- [3. Ciencia y datos de la NASA](#3-ciencia-y-datos-de-la-nasa)
  - [3.1 Objetivos de aprendizaje](#31-objetivos-de-aprendizaje)
  - [3.2 Reglas científicas que el juego respeta](#32-reglas-científicas-que-el-juego-respeta)
  - [3.3 Cómo cada tema del reto se convierte en una decisión con consecuencias](#33-cómo-cada-tema-del-reto-se-convierte-en-una-decisión-con-consecuencias)
  - [3.4 Clima espacial en vivo de NASA / CCMC DONKI](#34-clima-espacial-en-vivo-de-nasa--ccmc-donki)
  - [3.5 Números REAL y GAME](#35-números-real-y-game)
  - [3.6 Datos de agencias espaciales aliadas y otras referencias](#36-datos-de-agencias-espaciales-aliadas-y-otras-referencias)
  - [3.7 Referencias del mundo real detrás de los sitios, vehículos y equipo](#37-referencias-del-mundo-real-detrás-de-los-sitios-vehículos-y-equipo)
  - [3.8 La ciencia en las funciones de la etapa 11](#38-la-ciencia-en-las-funciones-de-la-etapa-11)
- [4. Diseño técnico](#4-diseño-técnico)
  - [4.1 Herramientas](#41-herramientas)
  - [4.2 Estructura del repositorio](#42-estructura-del-repositorio)
  - [4.3 Ejecución local](#43-ejecución-local)
  - [4.4 Arquitectura](#44-arquitectura)
  - [4.5 Referencia de módulos](#45-referencia-de-módulos)
  - [4.6 Remotos y acciones](#46-remotos-y-acciones)
  - [4.7 El sistema de guardado](#47-el-sistema-de-guardado)
  - [4.8 El mundo construido por código](#48-el-mundo-construido-por-código)
  - [4.9 Proceso de audio](#49-proceso-de-audio)
  - [4.10 Pruebas](#410-pruebas)
  - [4.11 Notas de rendimiento y seguridad](#411-notas-de-rendimiento-y-seguridad)
  - [4.12 Accesibilidad](#412-accesibilidad)
  - [4.13 Limitaciones técnicas conocidas](#413-limitaciones-técnicas-conocidas)
- [5. Registro de desarrollo](#5-registro-de-desarrollo)
  - [5.1 Equipo y roles](#51-equipo-y-roles)
  - [5.2 Cronología](#52-cronología)
  - [5.3 Decisiones](#53-decisiones)
  - [5.4 Evidencia de pruebas](#54-evidencia-de-pruebas)
  - [5.5 Cómo se usó la IA](#55-cómo-se-usó-la-ia)
  - [5.6 Problemas conocidos](#56-problemas-conocidos)
- [6. Fuentes, créditos y licencias](#6-fuentes-créditos-y-licencias)
  - [6.1 Fuentes de datos](#61-fuentes-de-datos)
  - [6.2 Avisos de terceros](#62-avisos-de-terceros)
  - [6.3 Licencia](#63-licencia)
  - [6.4 Uso de Superinteligencia](#64-uso-de-superinteligencia)

## 1. Panorama general

### Qué es el juego

Space Base Odyssey es un juego cooperativo de Roblox en el que niñas y niños de 7 a 12 años aterrizan en el polo sur de la Luna, construyen una base con sus propias manos y mantienen con vida a una tripulación durante misiones de siete días. La lección detrás de cada sistema es sencilla: en el espacio, cada decisión cuesta algo. La energía que se destina a la ciencia es energía que se le quita al aire o a la comida. Nadie sale lastimado, y cada error termina con una explicación clara.

Se creó para el NASA Space Apps Challenge 2026, reto **"Build a Junior Astronaut Mission Trainer"**, en el evento local NASA Space Apps Querétaro 2026 (14 y 15 de noviembre).

### Para quién es

- **Jugadores:** niñas y niños de 7 a 12 años, solos o con amigos. Una tripulación de misión tiene hasta cuatro jugadores que comparten una misma base.
- **Idiomas:** inglés y español de México desde la primera pantalla. Cada frase del juego tiene como máximo ocho palabras sencillas, para que un niño de 7 años pueda leerla.
- **Dispositivos:** PC y controles táctiles.

### La idea central: cada decisión cuesta algo

Cada día de misión empieza con una fase de planeación tranquila, sin reloj. La tripulación reparte unas cuantas celdas de energía entre tres sistemas: soporte vital, el invernadero y la ciencia. En un día normal hay 4 celdas, y cada sistema puede recibir como máximo 2, así que nunca alcanza la energía para que todo funcione a toda su capacidad. Después, la tripulación se pone el traje para un turno de 150 segundos con la gravedad de la Luna: limpiar paneles llenos de polvo, perforar hielo, reparar fugas, alinear la antena y correr al refugio cuando llega una tormenta. Al final, un reporte explica qué pasó y por qué.

Las consecuencias llegan con retraso a propósito, porque así funcionan los sistemas reales. Las plantas tardan en crecer, así que recortar el invernadero hoy se nota mañana como menos comida. El oxígeno se obtiene del agua más electricidad, así que dejar de traer hielo o de dar energía al soporte vital vacía el aire poco a poco. La dosis de radiación solo sube, nunca baja, así que cada tormenta que se pasa afuera cuenta para el resto de la misión.

### Cómo responde el juego al reto

El reto pide un juego en el que niñas y niños administren un puesto avanzado en la Luna o en Marte y equilibren el soporte vital, la protección contra la radiación, la energía, la producción de alimentos y el retraso en las comunicaciones. Cada uno de estos puntos se convirtió en una decisión con una consecuencia visible.

| Lo que pide el reto | Lo que decide el jugador | Lo que cuesta |
| :--- | :--- | :--- |
| Presupuesto de energía | Cómo repartir las celdas de energía del día entre soporte vital, invernadero y ciencia. | Una celda para la ciencia es una celda que se le quita al aire o a la comida. El polvo quita una celda hasta que alguien limpia el panel. |
| Soporte vital | Energía para el soporte vital, traer hielo, reparar fugas, cuándo rellenar el traje. | El oxígeno se fabrica con agua y electricidad. Respirar, las fugas y rellenar el traje gastan aire. |
| Producción de alimentos | Energía para el invernadero, construir más domos. | La comida llega al día siguiente, nunca el mismo día. |
| Protección contra la radiación | Detenerse y esconderse en el refugio, o seguir trabajando afuera durante una tormenta. | La dosis recibida afuera nunca baja. El refugio protege por su masa, no por la energía. |
| Retraso en las comunicaciones | Usar tiempo del turno para alinear la antena con la Tierra. | Con el enlace, los pronosticadores de la Tierra avisan a la tripulación 45 segundos antes de que lleguen las partículas. Sin él, solo 15 segundos. Los datos científicos también necesitan el enlace para llegar a la Tierra. |

Los tiempos de aviso, la duración del turno y los medidores de 0 a 100 son valores de juego elegidos para que sea jugable. Los números reales que los respaldan (por ejemplo, cerca de 0.9 kg de oxígeno por integrante de la tripulación al día, y un tiempo de señal de unos 1.3 segundos de la Luna a la Tierra) aparecen en la pantalla del juego "De dónde salen nuestros números" y, con sus fuentes, en `DATA_SOURCES.md`.

### Resumen general del proyecto

Space Base Odyssey es un juego cooperativo de Roblox en el que niñas y niños de 7 a 12 años empiezan en el pequeño módulo de aterrizaje que los llevó al polo sur de la Luna y hacen crecer una base desde cero. Cargan cajas de piezas desde el módulo de aterrizaje y arman cada edificio paso a paso con una llave: el hábitat, los paneles solares, un invernadero, una antena, un refugio contra tormentas hecho de regolito y, más adelante, un laboratorio, taladros de hielo, un garaje con un carrito lunar y un camión de hielo, una plataforma de aterrizaje y una nave para la siguiente misión, rumbo a Marte. Una línea de hielo que se ve funcionar convierte el hielo del cráter en agua y aire. Un mundo abierto guiado por 22 aventuras principales y 9 aventuras extra enseña un sistema a la vez, y el hábitat crece a lo largo de cinco niveles de base, desde el campamento de llegada hasta el puerto espacial. Las tripulaciones también juegan misiones de siete días en las que, cada mañana, reparten una cantidad limitada de energía entre el soporte vital, la comida y la ciencia. Las tormentas solares reproducen llamaradas reales de la base de datos DONKI de la NASA, etiquetadas con su fecha real, incluidas falsas alarmas reales en las que una llamarada enorme no trajo ninguna tormenta de partículas. Cada número del mundo real tiene su fuente citada, y nadie sale lastimado nunca: una misión que sale mal termina antes de tiempo, de forma segura, con un reporte que explica por qué.

### Beneficios para niñas y niños

- **Compromisos que se pueden sentir.** Ven cómo baja el medidor de comida al día siguiente de recortar el invernadero.
- **Ciencia real, contada de forma sencilla.** Las plantas tardan en crecer. El oxígeno sale del agua y la electricidad. Una pared gruesa detiene las partículas. La dosis de radiación se acumula y nunca desaparece. Una llamarada grande no siempre trae una tormenta de partículas.
- **Trabajo en equipo.** Hasta cuatro jugadores se reparten las tareas: uno limpia paneles, otro carga hielo, otro repara la fuga, y todos corren juntos al refugio.
- **Fallar sin peligro.** Un regreso anticipado es un resultado de misión con una razón y una invitación a intentarlo de nuevo.
- **Datos honestos.** Ven la fecha de la llamarada real que se está reproduciendo y aprenden la diferencia entre datos en vivo y un archivo histórico. Cada tormenta se plantea como "¿y si una tormenta como esta llegara a tu base?".

### El equipo

El equipo de cuatro integrantes, con crédito en la pantalla de Créditos del juego:

- Luis Alonzo Hernández Silva
- Ana Paula Navarro López
- Marianita Martínez Ruelas
- Santiago Alvarado Delgadillo

Los roles se reparten así: un integrante trabaja en Roblox Studio con un asistente de programación con IA, y los otros tres se encargan de la ciencia y los datos, del diseño de juego y las pruebas de juego, y de la presentación y la entrega. El paquete de prototipo tipo tycoon de Santiago aportó los cuatro modelos de mascotas y varias ideas que se usan en el ciclo de construcción de la base. El concepto, cada decisión de diseño, las pruebas de juego y las decisiones de balance son del equipo. Se usó asistencia de IA (Claude, de Anthropic) para investigación, verificación de datos y borradores de código y de texto, y esto se declara en cada archivo de código.

### Estado actual

- **La etapa 11 está terminada (compilación `0.11.0-stage11`).** Una renovación hecha durante la noche del 16 de noviembre de 2026: sonido y música con una regla honesta del casco, una línea de hielo tipo tycoon que se ve funcionar (taladros, banda, silo, planta de agua, robot de carga), un servidor más seguro con candados en las partidas guardadas, aventuras que enseñan (un premio en el primer minuto, preguntas con imagen de C.A.R.L., un glosario con imágenes), un menú de inicio nuevo sin "Cargar juego", una configuración que acompaña al jugador y una página de Ayudas, una cápsula de suministros diaria y la Bitácora lunar, celebraciones y un mapa más seguro. Pasó una prueba rápida en Studio: menú de inicio sin Cargar juego, la lista de mundos, la aparición en la nave, el seguimiento de aventuras, la tarjeta de la cápsula diaria, la línea de hielo y ningún error en la consola.
- **Publicado.** La versión de la etapa 10 (mundos privados, las correcciones de tormentas y radiación, los logros de aprendizaje) se publicó en la experiencia en vivo el 16 de noviembre de 2026, con servidores de 4 jugadores. La etapa 11 llega al juego en vivo cuando el equipo la publique. Las partidas del juego en vivo se guardan con los DataStores de Roblox.
- **Se puede jugar en Roblox Studio.** Se ejecuta desde el repositorio con Rojo (`rojo serve`, luego Play), con las solicitudes HTTP permitidas para los datos en vivo de la NASA. En un lugar de Studio sin publicar, las partidas solo viven en memoria ("Guardado solo para esta prueba").
- **Limitación por verificación de edad.** Las experiencias nuevas de Roblox solo están abiertas para cuentas con verificación de edad de 16 años o más hasta que aprueban la evaluación de Roblox para todas las edades. Hasta entonces, las niñas y los niños del rango de edad objetivo no pueden jugar la versión pública. El jurado puede ver el video de la partida completa o ejecutar el juego en Roblox Studio.
- **Para docentes.** Un paquete breve para docentes, con tres planes de clase de 20 minutos, está en `docs-public/GUIA_DOCENTE.md` (español) y `docs-public/EDUCATOR_GUIDE.md` (inglés).
- **Pendiente:** pruebas de juego con personas ajenas al equipo y una revisión del diseño para teléfono en un dispositivo real.
- **Por agregar antes de la entrega:** el enlace al video de demostración de 30 segundos (público, sin inicio de sesión, sin menores, sin logotipos de la NASA), el enlace al video de la partida completa, de 4 a 6 capturas de pantalla para la página del proyecto y el archivo de lugar congelado `game.rbxl` en la raíz del repositorio (todavía no está en el repositorio; los archivos de trabajo en `place/` están excluidos por git). También hay que revisar que el video de demostración no tenga imágenes, video ni voces generados por IA: si se agrega alguno, necesita una marca de agua visible.

### Enlaces

- **Demostración del proyecto:** POR AGREGAR: enlace al video de 30 segundos
- **Video de la partida completa:** POR AGREGAR: enlace al video completo y sin cortes de la partida (interfaz en inglés).
- **Proyecto final (repositorio):** https://github.com/Gorzoomer/space-base-odyssey

### Evidencia para el jurado

Las pruebas automatizadas se ejecutan fuera de Roblox con Lune, porque las reglas del juego viven en módulos puros sin código de Roblox. Los once conjuntos pasan al momento de escribir este documento (16 de noviembre de 2026, compilación `0.11.0-stage11`).

| Qué se verifica | Comando | Resultado |
| :--- | :--- | :--- |
| Balance de la misión: una tripulación que nunca reacciona aun así llega al menos al día 5, ningún plan de energía fijo obtiene 3 estrellas, una tripulación que reacciona a los eventos sí puede, recortar el invernadero se nota después como menos comida, la dosis de tormenta sube en vivo y nunca baja | `lune run tests/balance` | 716 aprobadas, 0 fallidas |
| Misiones de entrenamiento y capítulos de la historia, límites del hielo contra cada velocidad permitida, pagos del camión de hielo, el polvo del mundo abierto | `lune run tests/missions` | 729 aprobadas, 0 fallidas |
| Reglas de construcción y crecimiento: pasos de construcción, niveles de base, habilidades, mascotas, taladros, equipo, aventuras, la línea de hielo, sus letreros y su guardado | `lune run tests/base` | 2201 aprobadas, 0 fallidas |
| Ritmo de la economía con un niño típico simulado; las máquinas ganan del 30 al 50% de lo que gana jugar | `lune run tests/economy` | 234 aprobadas, 0 fallidas |
| Las tomas de cámara del menú de inicio | `lune run tests/cinematic` | 189 aprobadas, 0 fallidas |
| Mundos privados (quién puede entrar, de quién es la base), el candado de sesión, la configuración guardada | `lune run tests/worlds` | 116 aprobadas, 0 fallidas |
| Logros de aprendizaje, el banco de preguntas de C.A.R.L. y el glosario con imágenes | `lune run tests/achievements` | 758 aprobadas, 0 fallidas |
| La cápsula de suministros diaria y la Bitácora lunar | `lune run tests/daily` | 222 aprobadas, 0 fallidas |
| Celebraciones, sacudida de cámara, fichas del reporte, salidas del cráter y el borde del mapa | `lune run tests/feel` | 323 aprobadas, 0 fallidas |
| Tiempos de lectura y la cola de mensajes de C.A.R.L. | `lune run tests/reading` | 102 aprobadas, 0 fallidas |
| Cada clave de texto existe en inglés y en español, con un máximo de 8 palabras | `lune run tests/localization` | 51496 aprobadas, 0 fallidas |

Las pruebas de juego en Roblox Studio cubrieron cada etapa: una misión completa de 7 días que llega al reporte sin errores de script, la consulta en vivo a DONKI (13 llamaradas devueltas en la prueba de la etapa 2, con la hora de la consulta visible), el aviso de tormenta de 45 segundos con la antena enlazada y la llamarada etiquetada como repetición con su fecha real, las funciones de la etapa 10 (panel de signos vitales, tarjetas de aventuras, guardado, tubos transitables, mundos privados, radiación en vivo durante una tormenta) y la prueba rápida de la etapa 11 (menú de inicio, lista de mundos, aparición en la nave, seguimiento de aventuras, tarjeta de la cápsula diaria, línea de hielo, sin errores en la consola). Siete rondas de comentarios de las pruebas de juego del equipo, un reporte de amigos que jugaron la versión en vivo y lo que cambió con cada uno están registrados en `DEVELOPMENT.md`.

## 2. Cómo jugar

Esta sección acompaña a un jugador por el juego actual (Etapa 11, compilación `0.11.0-stage11`), desde el menú de inicio hasta la nave a Marte. Cada número proviene de `src/shared/MissionData.luau` (valores de ajuste GAME, salvo los marcados como REAL) o de la lista de aventuras en `src/shared/Quests.luau`. Los nombres que ve el jugador son los textos en español de `src/shared/Localization.luau`.

### 2.1 El menú de inicio

La primera pantalla reproduce tomas de cámara en vivo de la base detrás del título y los botones. El jugador no tiene personaje hasta que se carga un mundo. Ya no existe el botón "Cargar juego": al equipo le pareció que sonaba a subir un archivo. Los botones son:

| Botón | Qué hace |
| :--- | :--- |
| Continuar | Carga el mundo jugado la última vez. Debajo, una tarjeta dice qué va a cargar: el mundo y cómo se jugó, el nivel de base, el nivel del jugador y cuándo se guardó por última vez. Si todavía no hay mundo, dice "Aún no hay un mundo guardado". |
| Juego nuevo | Abre la lista de los 3 mundos del jugador. En cuanto el jugador tiene un mundo, el botón dice **Mis mundos**. |
| Unirse a un amigo | Muestra a los amigos de Roblox del jugador que tienen abierto un mundo con amigos: nombre, nivel de base y "n de 4 jugadores". |
| Configuración | Abre el panel de Configuración con sus páginas Juego y Ayudas (sección 2.24). |
| Créditos | El equipo, el evento, los créditos de datos, imágenes y sonidos, y la declaración de uso de IA, todo como texto. |

**La lista de mundos.** Una tarjeta vacía empieza un mundo nuevo. Una tarjeta usada abre un cuadro con **Continuar** y **Empezar de nuevo**. Empezar de nuevo vuelve a preguntar ("¿Empezar este mundo otra vez?", "Tu base de este mundo se borrará."), y la opción segura, "No, déjalo así", regresa al cuadro. Solo Empezar de nuevo reemplaza un mundo. Continuar nunca borra uno.

**Cómo jugar.** Después de elegir un mundo, el jugador decide:

- **Solo yo**: "Tu propia Luna, solo para ti". Solo el dueño puede quedarse en ese mundo.
- **Con amigos**: "Tú y hasta 3 amigos". El dueño y hasta 3 amigos de Roblox, 4 jugadores como máximo. Un amigo elige el mundo en Unirse a un amigo y luego decide cuál de sus propias partidas lleva ("Elige tu partida de explorador"). Una partida vacía empieza un explorador nuevo, y nada se borra desde esa pantalla.

Cada mundo corre en su propio servidor reservado, y el servidor público es solo un vestíbulo para el menú de inicio. La base (construcciones, construcciones en curso y el silo) siempre es del dueño del mundo. Los invitados conservan en su propia partida sus créditos, XP, nivel, habilidades, equipo, herramientas, mascotas, vestidor, aventuras, coleccionables y misiones, y la base propia de un invitado nunca cambia en el mundo de un amigo. Cuando el dueño se va, se guarda la partida de cada invitado y todos vuelven al menú: "Tu amigo se fue y su base cerró."

**El viaje.** Una pantalla de teletransporte con el tema del juego ("Volando a tu propia Luna...") se funde con la pantalla de espera al llegar. Si la base tarda en cargar, a los 40 segundos la pantalla de espera dice "Tu base aún se prepara. Espera un poco." y ofrece "Volver al inicio", mientras sigue esperando. Cada cuadro pone la selección del control de videojuegos en su botón seguro.

**El guardado es automático y gratuito.** Las partidas se guardan con DataStores de Roblox, que no tienen costo. El menú de inicio y la Configuración dicen "Tu juego se guarda solo". Una pequeña etiqueta "Juego guardado" aparece después de un guardado automático (como máximo una vez cada 30 segundos) y después de un guardado manual. La Configuración también tiene un botón **Guardar ahora**, que el servidor verifica y limita en frecuencia. Cuando las partidas solo pueden vivir en memoria (por ejemplo, en un lugar no publicado en Studio), la etiqueta dice "Guardado solo para esta prueba".

**Fondo cinematográfico.** Detrás del título y los botones, el menú reproduce en bucle tomas de cámara en vivo de la base: la Tierra saliendo detrás del hábitat mientras el Sol se acerca a ella, un primer plano de las plantas del invernadero, el tubo del invernadero, los taladros de hielo en el cráter, la antena, la base desde el aire, la nave y una toma que se aleja. En el vestíbulo nadie ha cargado un mundo, así que la base se muestra terminada para estas tomas. Las mismas tomas se usaron para el tráiler de 30 segundos.

### 2.2 El aterrizaje

El jugador aparece dentro de la **nave de llegada**, el único refugio al inicio. Afuera hay plataformas de construcción brillantes con hologramas de la futura base. C.A.R.L. saluda al jugador: "¡Aterrizaste! Ahora construyamos nuestra base lunar."

La primera aventura, **¡Hola, Luna!**, da un premio en más o menos un minuto después de aterrizar: empezar el hábitat gratis en su plataforma, tomar una caja de piezas en la nave y traerla de vuelta (10 créditos y 10 XP). Cuando hay una cápsula de suministros diaria esperando, cae junto a la nave unos segundos después (sección 2.19).

### 2.3 La pantalla (HUD)

| Parte | Dónde | Qué muestra |
| :--- | :--- | :--- |
| Seguimiento de aventuras | Columna izquierda, arriba | La aventura principal actual y las aventuras extra abiertas. Los pasos que se cuentan muestran "tienes / necesitas" ("Lleva hielo a la base  0/4") con una barra de avance delgada; los pasos de construcción y de herramientas dicen el nivel ("Mejora la antena al nivel 2"). Las palabras del glosario se ven doradas y subrayadas (sección 2.21). Parpadea cuando algo cambia. |
| Panel de signos vitales | Columna izquierda | Siempre visible durante el juego: aire del traje, comida fresca del invernadero (lista, una cuenta regresiva o la energía extra) y hielo del silo (cuando ya hay un taladro; atenuado en el mundo de un amigo). |
| Cartera | Columna izquierda | Créditos (con un aviso "+N"), nivel del jugador con una barra de XP y el nivel de base. Mientras las máquinas del jugador ganan, una etiqueta delgada debajo dice "Máquinas: +N créditos por minuto". |
| Medidores | Columna izquierda, durante un turno | Aire, comida, radiación, agua y "Por enviar" (datos que la antena todavía no envía). |
| Globo de C.A.R.L. | Arriba al centro, al caminar | Los mensajes de C.A.R.L. Una instrucción que necesita una herramienta muestra el ícono de esa herramienta. Un pequeño botón para repetir, junto al globo, abre "Lo que dijo C.A.R.L.". Mientras el Laboratorio o el Vestidor están abiertos, el globo baja al centro inferior para que sus respuestas se vean. |
| Avisos de aventuras | Lado derecho | "¡Nueva aventura!", "¡Nueva aventura extra!", "Listo: (paso)", "¡Aventura completa!" con los créditos y la XP ganados. Una aventura principal terminada frente al jugador muestra una tarjeta dorada más grande: "¡Aventura principal completa! ¡Muy bien!". Los pasos que ya estaban hechos al abrirse una aventura aparecen como "Ya hecho". Los avisos esperan mientras hay un panel de pantalla completa abierto. |
| Barra superior | Arriba a la derecha | Botones de Configuración, Misiones, Vestidor y Logros. |
| Etiquetas inferiores | Sobre la barra de herramientas de Roblox | "Llevas hielo", "Llevas piezas", "Avanzar solo (X)", la barra del tanque de gas (si se tiene equipo) y un aviso que late, "¡Poco aire! Ve adentro", cuando el traje tiene poco aire afuera. |
| Letreros de obra | Sobre las plataformas de construcción | "Paso 1/2" y lo que se necesita después. |
| Letreros de la línea de hielo | Sobre el silo y la planta de agua | Hielo del silo ("Hielo 12/20"), hielo por minuto, créditos por minuto y una luz de estado con palabras al lado (sección 2.13). |

En los teléfonos, la interfaz del juego se aleja del notch y de las esquinas redondeadas, y en pantallas táctiles ningún texto del juego mide menos de 11 píxeles reales.

### 2.4 C.A.R.L., el robot guía

C.A.R.L. es un pequeño rover con orugas que avanza junto al jugador. La Luna no tiene aire, así que no tiene hélices: rueda sobre orugas y da saltitos con pequeños propulsores de gas cuando el jugador salta.

- **Colores:** cian cuando todo está bien; naranja cuando queda poco aire en el traje, cuando una tarea es urgente o cuando hay aviso de tormenta; rojo mientras las partículas de la tormenta están presentes.
- **Haz guía:** un haz cian apunta exactamente adonde lo envían sus palabras: la bodega de carga de la nave para las piezas, la plataforma de construcción para armar, un panel con polvo para limpiarlo, la consola de misiones para un paso de misión, el Laboratorio para habilidades o equipo. Fuera de las misiones, sigue el paso actual de la aventura. El haz no atraviesa paredes: si el camino está bloqueado, termina en la puerta más cercana que C.A.R.L. pueda ver, y un marcador cian flota sobre el lugar. Solo apunta al silo cuando el silo es del jugador y tiene al menos 5 de hielo (una carga del robot de carga); si no, apunta al hielo del cráter.
- **Haz de tormenta:** un haz naranja apunta a la puerta del refugio hasta que el jugador está adentro.
- **Tiempo para leer:** una frase se queda 2 segundos más 0.75 segundos por palabra (unos 8 segundos para una frase de 8 palabras), nunca menos de 4 segundos y como máximo 12 (16 para los datos curiosos). La ayuda Tiempo de mensajes la deja 1.5 o 2 veces más. Cuando llegan muchas frases a la vez, las repetidas se juntan y las menos útiles no se muestran; las negativas, las felicitaciones, las preguntas y las pistas de tesoros duran más.
- **Historial:** el botón para repetir abre "Lo que dijo C.A.R.L.": las últimas 10 frases, de la más nueva a la más vieja, en el idioma actual. Ahí también están las frases que no se alcanzaron a mostrar.
- **Felicita la estrategia:** al terminar una aventura principal, C.A.R.L. dice qué funcionó ("Más paneles, más energía. ¡Buena construcción!"), no solo el premio.
- **Puntos de habilidad:** "Tienes puntos de habilidad. ¡Construye el Laboratorio!" cuando la base ya es suficientemente grande, y "El Laboratorio está listo. ¡Usa tus puntos!" cuando ya existe.
- **Pistas de tesoros:** mientras la aventura Tesoros escondidos está abierta y pasan 5 minutos sin encontrar nada nuevo, C.A.R.L. da una pista tipo adivinanza de un secreto que falta ("¡Algo se esconde debajo de tu hábitat!"). Las pistas nombran lugares conocidos, nunca puntos cardinales, y nunca llegan durante una misión.
- **Descansos:** después de 45 minutos de juego, la siguiente aventura terminada va seguida, una sola vez, de "Base a salvo. ¡Buen momento para descansar!". No hay rachas ni relojes que castiguen por irse.
- **Preguntas:** después de algunas aventuras, C.A.R.L. hace una pregunta con imagen (sección 2.21).
- **Datos curiosos:** 88 datos verificados aparecen al azar y sin repetirse.
- **Rescate:** si se acaba el aire del traje, C.A.R.L. lleva al astronauta al cuarto presurizado más cercano que ya esté construido, con una recarga parcial. Nadie muere.

Los datos curiosos y la guía se pueden desactivar por separado en la Configuración.

### 2.5 Mundo abierto y aventuras

No hay un menú de misiones al inicio. El juego es un mundo abierto guiado por una serie ordenada de **22 aventuras principales**. En el camino se abren **9 aventuras extra**. Una aventura se completa cuando todos sus pasos están hechos, y sus créditos y su XP se pagan una sola vez. Los pasos de hielo, silo, meteoritos, comida, manejo y visitas cuentan solo lo que ocurre mientras la aventura está activa. Los escaneos, las habilidades, los coleccionables y los paneles limpiados cuentan los totales acumulados del jugador, así que un niño que ya limpió un panel nunca se queda esperando. Las aventuras usan las mismas palabras que las plataformas y el HUD: "Mejora", "nivel de base", "caja de piezas", "carrito lunar".

#### Aventuras principales

| # | Nivel de base | Título | Pasos | Premio |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 1 | ¡Hola, Luna! | Empieza el hábitat, trae una caja de piezas. | 10 créditos, 10 XP |
| 2 | 1 | Construye tu casa en la Luna | Construye el hábitat. Construye los paneles solares. Termina la misión Primeros pasos. | 10, 20 |
| 3 | 1 | Cultiva tu propia comida | Construye el invernadero. Termina la misión Reparte la energía. Come comida fresca: 1. | 10, 20 |
| 4 | 1 | Habla con la Tierra | Construye la antena. Termina la misión Tareas de la base. Limpia un panel solar con polvo: 1. | 10, 20 |
| 5 | 1 | Prepárate para las tormentas | Construye el refugio. Termina la misión Simulacro de tormenta. | 15, 25 |
| 6 | 1 | El hielo es un tesoro | Ve al cráter de hielo. Lleva hielo a la base: 4. | 10, 20 |
| 7 | 1 | Más energía para la base | Mejora los paneles solares al nivel 2. Termina el Capítulo 1: Nuevo hogar. | 20, 30 |
| 8 | 2 | Haz crecer tu base | Mejora el hábitat al nivel de base 2. Construye el Laboratorio. Entra al Laboratorio. | 20, 30 |
| 9 | 2 | Aprende habilidades nuevas | Aprende una habilidad en el Laboratorio: 1. En el Laboratorio, mejora tu taladro al nivel 2. | 15, 25 |
| 10 | 2 | Taladros que trabajan solos | Construye el taladro de hielo 1. Recoge hielo del silo: 2. | 20, 30 |
| 11 | 2 | Temporada de tormentas | Mejora los paneles solares al nivel 3. Termina el Capítulo 2: Temporada de tormentas. | 25, 40 |
| 12 | 2 | Explora la Luna | Escanea lugares para explorar: 2. Escanea un cráter de meteorito nuevo: 1. | 25, 40 |
| 13 | 2 | Un jardín más grande | Mejora el invernadero al nivel 2. Entra al invernadero. Come comida fresca: 3. | 20, 30 |
| 14 | 3 | Una base minera | Mejora el hábitat al nivel de base 3. Construye el taladro de hielo 2. Construye el robot de carga. | 30, 50 |
| 15 | 3 | Ruedas en la Luna | Construye el garaje de rovers. Ve al garaje de rovers. Maneja el carrito lunar. | 30, 50 |
| 16 | 3 | Cuando algo se rompe | Termina el Capítulo 3: Algo se rompe. Mejora la antena al nivel 2. | 40, 60 |
| 17 | 3 | Equípate | Compra las botas de aire en el Laboratorio. Aprende habilidades en el Laboratorio: 4 en total. | 30, 50 |
| 18 | 4 | Base de exploradores | Mejora el hábitat al nivel de base 4. Mejora el garaje de rovers al nivel 2. Lleva hielo a la base: 8. | 50, 80 |
| 19 | 4 | Un láser a la Tierra | Mejora la antena al nivel 3. Construye el taladro de hielo 3. | 50, 80 |
| 20 | 4 | Una plataforma para naves | Construye la plataforma de aterrizaje. Escanea cráteres de meteorito nuevos: 3. | 60, 100 |
| 21 | 5 | Puerto espacial lunar | Mejora el hábitat al nivel de base 5. Mejora el taladro de hielo 2 al nivel 3. | 80, 120 |
| 22 | 5 | Próxima parada: Marte | Construye la nave a Marte. | 100, 150 |

Cuando se completan todas las aventuras principales, el seguimiento dice: "¡Aventuras listas! Busca secretos y aventuras extra." Las partidas guardadas antes de la etapa 11 se saltan ¡Hola, Luna! y conservan su lugar en la serie.

#### Aventuras extra

| Título | Se abre después de | Pasos | Premio |
| :--- | :--- | :--- | :--- |
| Tesoros escondidos | Prepárate para las tormentas | Encuentra tesoros escondidos: 4. | 40 créditos, 60 XP |
| Súper astronauta | Aprende habilidades nuevas | Aprende todos los niveles de habilidad: 15. | 60, 100 |
| Maestro del hielo | Una base minera | Lleva hielo a la base: 40. Mejora el taladro de hielo 1 al nivel 2. | 40, 60 |
| Científico lunar | Explora la Luna | Escanea lugares para explorar: 5. | 40, 60 |
| Granjero lunar | Un jardín más grande | Come comida fresca: 10. | 25, 40 |
| Una semana completa | Cuando algo se rompe | Termina la misión Juego libre. | 60, 100 |
| Vuela como un cohete | Equípate | Compra la mochila propulsora en el Laboratorio. | 40, 60 |
| Cazador de meteoritos | Una plataforma para naves | Escanea cráteres de meteorito nuevos: 10. | 60, 100 |
| Fábrica de hielo | Puerto espacial lunar | Mejora los taladros de hielo 1, 2 y 3 al nivel 3. | 80, 120 |

Antes, Maestro del hielo pedía recoger 10 veces el silo a mano, pero el robot de carga vacía el silo cada minuto, así que el contador parecía descompuesto. Ahora enseña que un taladro más grande saca más hielo por sí solo. Ninguna aventura cuenta recolecciones del silo una vez que se puede construir el robot de carga.

### 2.6 Misiones

Las misiones son pasos de las aventuras. Se inician desde la **consola de misiones** dentro del hábitat o desde el botón **Misiones** de la barra superior. Cada misión necesita que ciertas construcciones ya estén en pie.

| Misión | Tipo | Días | Qué enseña |
| :--- | :--- | :--- | :--- |
| Primeros pasos | Entrenamiento | 1 | Salir, construir el hábitat y un panel solar, y volver a entrar. |
| Reparte la energía | Entrenamiento | 1 | Construir el invernadero, repartir la energía en el tablero y un turno corto de 45 segundos. |
| Tareas de la base | Entrenamiento | 1 | Un día de polvo: construir y conectar la antena, limpiar un panel, perforar hielo y entregarlo. |
| Simulacro de tormenta | Entrenamiento | 1 | Construir el refugio, correr adentro cuando llega el aviso y quedarse a salvo. |
| Capítulo 1: Nuevo hogar | Historia | 3 | Dirigir la base durante 3 días y entregar hielo 2 veces. |
| Capítulo 2: Temporada de tormentas | Historia | 3 | Dirigir la base durante 3 días y sobrevivir a una tormenta. |
| Capítulo 3: Algo se rompe | Historia | 4 | Arreglar la fuga de aire y ganar al menos 2 estrellas. Una gran llamarada es una falsa alarma. |
| Juego libre | Libre | 7 | La semana aleatoria original, disponible después de la historia. |

Las misiones de entrenamiento nunca fallan. El Capítulo 3 tiene un final abierto: "Lo siguiente es Marte. Pero la Luna aún guarda secretos..."

#### El ciclo de una misión

Cada día de misión tiene tres partes.

1. **Planear (sin reloj).** En el tablero de energía, el jugador reparte celdas de energía entre tres sistemas:
   - **Máquina de aire:** convierte agua en aire usando electricidad.
   - **Invernadero:** cultiva comida, que llega al día siguiente, porque las plantas tardan en crecer.
   - **Laboratorio de ciencia:** descubrimientos que dan estrellas, pero solo cuando la antena los envía a la Tierra.

   Cada arreglo solar limpio y con luz del Sol da una celda, más una celda de la batería. Un sistema recibe como máximo 2 celdas. Nunca alcanza la energía para todo.
2. **Turno (150 segundos, en tiempo real).** El jugador recorre la base con la gravedad de la Luna. El aire del traje se gasta afuera (más rápido al correr) y se recarga adentro, usando parte del aire de la base. Las tareas, cada una con su herramienta en mano, son:
   - limpiar paneles solares con polvo (cepillo);
   - perforar hielo en el cráter en sombra y llevarlo a la máquina de agua (taladro de hielo);
   - arreglar una fuga de aire (kit de reparación);
   - apuntar la antena hacia la Tierra (tableta).
3. **Reporte.** Los resultados del día y sus razones, por ejemplo "Paneles con polvo dieron menos energía." o "El grueso refugio de tierra los protegió."

#### Medidores y eventos

Los medidores de **aire, comida, radiación y agua** se mueven durante el turno hacia el resultado de fin del día. Si se acaba el aire o la comida, o si la radiación llega a su límite, la tripulación regresa antes a casa y el reporte explica qué intentar la próxima vez. La dosis de radiación solo sube: los rayos cósmicos de fondo suman un poco cada día, y estar afuera durante una tormenta de partículas suma mucho más.

Los eventos del día son un día tranquilo, polvo en los paneles, una fuga de aire o una posible tormenta solar. En Juego libre, los dos primeros días son tranquilos y los otros cinco se revuelven al azar.

#### Tormentas y el refugio

Las tormentas usan llamaradas solares reales registradas por la base de datos DONKI de la NASA. La tarjeta de tormenta dice el nombre de la llamarada y su fecha, y una llamarada de archivo se marca como repetición ("Repetición de una llamarada real del (fecha)"). El juego pregunta: ¿qué pasaría si una tormenta como esta llegara a tu base? Estas llamaradas se observaron cerca de la Tierra, no en una base lunar.

- Con la antena conectada, los pronosticadores de la Tierra avisan a la tripulación con 45 segundos de anticipación. Sin ella, el aviso llega con 15 segundos.
- El jugador corre al **refugio de regolito**. Protege por su masa (tierra lunar gruesa), no por energía.
- Algunas grandes llamaradas no traen tormenta de partículas. Estas falsas alarmas honestas muestran que una gran llamarada no siempre trae una tormenta de partículas.

### 2.7 Construir por pasos

Solo se construye en las plataformas del mundo (no hay menú de construcción).

1. Caminar hasta una plataforma y pagar (indicación "Construir (N créditos)" o "Construir (gratis)"). Esto inicia el nivel.
2. Tomar una **caja de piezas** de la bodega de carga de la nave ("Tomar caja de piezas").
3. Llevarla a la plataforma ("Entregar piezas: paso N de M").
4. Mantener **Armar** con la **llave** en mano (mantener 2.5 segundos, menos con la habilidad Constructor veloz).
5. La estructura crece un poco con cada paso.

Una estructura nueva toma 3 pasos y una mejora, 2. El hábitat y el primer panel solar toman 2, una mejora del hábitat (un nuevo nivel de base) toma 4 y la nave a Marte toma 6. Cada nivel construido da XP: 10 más una cuarta parte de su costo.

### 2.8 Niveles de base (el hábitat es el ayuntamiento)

El nivel del hábitat es el **nivel de base**. Cada nivel de estructura necesita un nivel de base mínimo, y el hábitat se ve distinto en cada nivel.

| Nivel de base | Nombre | Costo del hábitat | Qué se abre |
| :--- | :--- | :--- | :--- |
| 1 | Campamento de llegada | Gratis | Paneles solares 1-3, invernadero 1, antena 1, refugio |
| 2 | Puesto de ciencia | 15 créditos | Laboratorio, taladro de hielo 1 (con el silo), invernadero 2 |
| 3 | Base minera | 60 | Taladro de hielo 1 nivel 2, taladro de hielo 2, robot de carga, garaje de rovers 1, antena 2 |
| 4 | Base de exploradores | 300 | Taladro de hielo 1 nivel 3, taladro de hielo 2 nivel 2, taladro de hielo 3, garaje 2, antena 3, plataforma de aterrizaje |
| 5 | Puerto espacial lunar | 800 | Taladro de hielo 2 nivel 3, taladro de hielo 3 niveles 2-3, nave a Marte |

El silo guarda 20 de hielo en los niveles de base 1 y 2, y luego 30, 45 y 60.

#### Todas las construcciones

| Construcción | Niveles y costo (créditos) | Necesita | Qué hace cada nivel |
| :--- | :--- | :--- | :--- |
| Hábitat | 0 / 15 / 60 / 300 / 800 | Nivel de base anterior | Casa con aire adentro; define el nivel de base; silo más grande. Desbloquea el kit de reparación. |
| Paneles solares | 0 / 25 / 35 | Hábitat | Cada nivel es un arreglo más, una celda de energía más. Desbloquea el cepillo. |
| Invernadero | 10 / 50 | Solar 1 | El nivel 2 agrega el segundo domo: comida fresca cada 60 s en vez de cada 90 s. Desbloquea la ensalada fresca. |
| Laboratorio | 30 | Hábitat, solar 1 | Habilidades, mejoras de herramientas, equipo, adopción de mascotas. |
| Antena | 10 / 90 / 200 | Solar 1 | El 2 es una antena parabólica más grande y el 3, un enlace láser. Conectarla paga 0 / +3 / +6 créditos extra. Desbloquea la tableta. |
| Refugio | 15 | Antena 1 | La tierra lunar gruesa bloquea las partículas de la tormenta. |
| Taladro de hielo 1 | 40 / 100 / 220 | Refugio, solar 1 | Saca 2 / 3 / 4 de hielo por minuto hacia el silo. |
| Taladro de hielo 2 | 120 / 200 / 350 | Taladro 1, solar 2 | Mismos ritmos. Las máquinas necesitan electricidad: un arreglo más. |
| Taladro de hielo 3 | 250 / 400 / 500 | Taladro 2, solar 3 | Mismos ritmos. |
| Robot de carga | 140 | Taladro 1 | Agrega la máquina de aire y el puerto de suministros; lleva agua o aire de la planta de agua al núcleo, como máximo un viaje por minuto. |
| Garaje de rovers | 90 / 220 | Laboratorio, refugio | El 1 es la cochera del carrito lunar y el 2, la cochera del camión de hielo. |
| Plataforma de aterrizaje | 300 | Garaje 1, antena 2 | Un piso duro para que los cohetes levanten menos polvo. Se necesita para la nave. |
| Nave a Marte | 1000 | Plataforma de aterrizaje | Una nave para un futuro viaje a Marte: la meta a largo plazo (decorativa). |

### 2.9 Herramientas

Las herramientas están en la barra de herramientas de Roblox. Cada tarea necesita su herramienta en mano ("sin taladro, no hay hielo").

| Herramienta | Se obtiene con | Uso |
| :--- | :--- | :--- |
| Llave | Inicio | Arma cada paso de construcción. |
| Taladro de hielo | Inicio | Saca núcleos de hielo en el cráter. Mejoras en el Laboratorio: nivel 2 (60 créditos, nivel de jugador 3) y nivel 3 (150 créditos, nivel de jugador 5) reducen el tiempo que hay que mantener la perforación al 70% y luego al 50%. |
| Cepillo de paneles | Paneles solares | Quita el polvo lunar de los paneles. |
| Kit de reparación | Hábitat | Tapa las fugas de aire. |
| Tableta | Antena | Apunta la antena y escanea lugares de exploración y cráteres de meteoritos. |
| Ensalada fresca | Invernadero | Se recoge en el invernadero y se come adentro (afuera el casco no se quita). Da 20 segundos de energía extra (caminar más rápido) y 3 XP. |

### 2.10 Equipo

El equipo se compra y se mejora en el Laboratorio (pestaña Equipo) y se enciende o apaga con una tecla. Las dos piezas comparten un **tanque de gas** (100) que se recarga dentro de los módulos presurizados. Las mochilas propulsoras reales, como la MMU y la SAFER de la NASA, vuelan con chorros de gas frío, porque no hay aire contra el cual empujar.

| Equipo | Tecla | Costo por nivel | Nivel del jugador | Gas usado |
| :--- | :--- | :--- | :--- | :--- |
| Botas de aire | B | 60 / 100 / 160 | 3 / 5 / 7 | 25 / 18 / 12 por doble salto |
| Mochila propulsora | J | 200 / 300 / 400 | 8 / 10 / 12 | 30 / 22 / 15 por segundo |

Las botas dan un segundo salto en el aire al 80% de un salto normal. La mochila propulsora sube mientras se mantiene Saltar en el aire. Todos ven en el traje las cubiertas de las botas y los tanques de la mochila propulsora.

### 2.11 Habilidades

Cada nivel del jugador da **un punto de habilidad**. Las habilidades se aprenden en el Laboratorio. Hay 15 niveles de habilidad en total, así que un jugador en el nivel máximo (15) puede tener todas las habilidades en su nivel más alto.

| Habilidad | Efecto por nivel | Nivel del jugador para los niveles 1 / 2 / 3 |
| :--- | :--- | :--- |
| Pies veloces | Caminar y correr más rápido | 2 / 4 / 6 |
| Tanque grande | +25 de aire en el traje | 2 / 4 / 6 |
| Constructor veloz | Mantener Armar al 80% / 65% / 50% del tiempo | 2 / 5 / 8 |
| Más créditos | +10% de cada premio en créditos, redondeado hacia arriba | 3 / 6 / 9 |
| Más XP | +10% de cada premio en XP, redondeado hacia arriba | 3 / 6 / 9 |

### 2.12 Créditos, XP, niveles y ritmo

Un mundo nuevo empieza con 25 créditos. Los créditos y la XP solo se obtienen con trabajo útil:

| Trabajo | Créditos | XP |
| :--- | :--- | :--- |
| Hielo entregado a mano | 5 | 8 |
| Panel limpiado | 2 | 4 |
| Antena alineada | 3 (más el bono de la antena) | 4 |
| Fuga reparada | 5 | 8 |
| Día de misión terminado (cada jugador presente) | 5 | 10 |
| Cada estrella del reporte (cada jugador presente) | 5 | 5 |
| Misión completada (primera vez / otra vez) | 20 / 5 | 30 / 10 |
| Coleccionable escondido (primera vez) | 10 | 20 |
| Lugar de exploración (primer escaneo) | 10 | 20 |
| Cráter de meteorito escaneado | 15 | 25 |
| Hielo del silo convertido en agua, por cada hielo | 1 | 1 |
| Una carga de aire del robot con la máquina de aire encendida | 25% más que la misma carga de agua (redondeado hacia abajo) | - |
| Caja de piezas entregada / paso de construcción hecho | 0 | 2 / 5 |
| Logro de aprendizaje (una vez cada uno) | 0 | 10 |
| Pregunta de C.A.R.L. contestada bien (una vez cada una) | 0 | 5 |
| Cápsula de suministros diaria | 10, 15 o 20 (días 1, 3, 5) | 15, 20 o 25 (días 2, 4, 6) |

Las habilidades Más créditos y Más XP aumentan el trabajo propio del jugador, no lo que ganan las máquinas.

Hay **15 niveles de jugador**. XP total necesaria: 0, 40, 100, 180, 280, 400, 550, 750, 1000, 1350, 1800, 2400, 3100, 3900, 4800. El nivel del jugador limita las habilidades, el equipo, las mejoras de herramientas y las mascotas. No limita las estructuras; eso lo hace el nivel de base.

**Ritmo.** `tests/economy.luau` simula a un niño típico que sigue las aventuras, juega un día de misión aproximadamente cada 5 minutos y nunca se queda quieto repitiendo una tarea para acumular recompensas. La prueba falla si no se cumplen las metas. La ejecución actual (etapa 11) da:

| Hito | Minuto (niño típico) | Meta |
| :--- | :--- | :--- |
| Nivel de base 2 | 6.8 | 4-10 |
| Laboratorio | 12.0 | 8-20 |
| Nivel de base 3 | 34.9 | 20-40 |
| Garaje de rovers | 45.1 | 35-70 |
| Nivel de base 4 | 77.6 | 60-110 |
| Nivel de base 5 | 163.8 | 150-300 |
| Nave a Marte | 234.4 | 150-300 |

En la misma ejecución, el jugador llega al nivel 15 alrededor del minuto 128, y la línea de aventuras principales termina con la nave alrededor del minuto 234. El taladro de hielo 1 se paga solo en unos 20 minutos. Desde el robot de carga hasta la nave, las máquinas ganan el 49% de lo que gana jugar (la prueba permite del 30 al 50%), así que ayudan, pero jugar es lo que más cuenta. Los ingresos nunca se multiplican por más de 2.5 de una ventana de 10 minutos a la siguiente. Son minutos simulados, no pruebas de juego medidas.

### 2.13 La línea de hielo: taladros, silo, planta de agua y robot de carga

La línea de hielo es el tycoon de la base, y cada parte está a la vista:

1. Los **taladros** en el fondo oscuro del cráter sacan 2, 3 o 4 de hielo por minuto cada uno (taladro de nivel 1, 2 o 3). Sus brocas giran más rápido en los niveles altos.
2. Unas **bandas elevadoras** suben los cubos de hielo a una tolva en el borde del cráter, y una **banda** abierta sobre postes cruza la ladera exterior hasta el silo. La cantidad y la velocidad de los cubos siguen al hielo por minuto.
3. El **silo** está entre el núcleo y el cráter. Guarda 20 de hielo en los niveles de base 1 y 2, y luego 30, 45 y 60; un anillo dorado marca el tamaño del nivel de base actual. Cuando se llena, la banda y los taladros se detienen.
4. La **planta de agua**, junto al silo, derrite el hielo y lo convierte en agua. Tiene una ventana de agua y un letrero con íconos: hielo, agua, aire.
5. La construcción del **robot de carga** agrega la **máquina de aire** (agua más electricidad da oxígeno, como en la Estación Espacial) y un puerto de suministros en la pared del núcleo. El robot espera a que el silo tenga 5 de hielo, lo carga, lleva tanques de agua o de aire unos 47 studs hasta el puerto, cobra al llegar, descarga y regresa, como máximo un viaje por minuto.

**Pago.** El agua paga 1 crédito por cada hielo. El aire de una máquina de aire con energía paga 25% más (redondeado hacia abajo). La máquina de aire necesita al menos 2 arreglos solares; sin ellos su lámpara se pone ámbar, el robot lleva agua en su lugar y C.A.R.L. dice "El fabricante de aire necesita energía. ¡Más paneles!". Cada entrega del robot y cada recolección a mano muestran un pequeño letrero "+N créditos" con una moneda dorada en el lugar donde ocurrió. Solo el jugador que recibió los créditos ve el número.

**Sin robot de carga,** el jugador vacía el silo a mano con "Manda el hielo a la base" en el silo: "El hielo se hizo agua: +5 créditos."

**Letreros y luces.** Sobre el silo: "Hielo 12/20", "3 de hielo por minuto" y una luz de estado con una razón corta ("Trabajando", "Silo lleno: la banda se paró", "Primero construye un taladro"). Sobre la planta de agua: agua o aire, "+3.8 créditos por minuto" y la luz de la planta ("El fabricante de aire necesita energía" va primero). El anillo superior del silo y la lámpara de la planta están en verde mientras la banda funciona y en rojo cuando el silo está lleno. El color de una luz siempre tiene palabras al lado, y un silo lleno o una planta sin energía hacen que el borde del letrero palpite.

**Lleno y más grande.** C.A.R.L. dice "¡Silo lleno! Manda el hielo a la base." una vez por cada llenado, y "¡Silo lleno! Mejora el hábitat para más espacio." solo cuando el siguiente nivel del hábitat de verdad guarda más. Después de mejorar el hábitat: "¡Silo más grande! Ahora guarda 30 de hielo."

**Juego limpio.** El robot solo le paga al dueño del mundo, y descansa mientras el dueño lleva 5 minutos sin moverse ni hacer nada ("El robot te espera"), así que quedarse quieto no da nada. Solo el dueño puede vaciar el silo a mano ("Este es el silo de tu amigo."). En la pantalla de un invitado, el letrero de la planta dice "Silo de tu amigo" y la cartera no muestra ingresos de máquinas.

**Mientras no estabas.** El silo se guarda con el mundo del dueño. Cuando el dueño regresa, se suma lo que sacaron los taladros mientras no estaba, como máximo 8 horas y nunca más que el tamaño del silo. C.A.R.L. dice "¡Mientras no estabas, los taladros sacaron 24 hielo!" y una tarjeta muestra el hielo, cuánto vale y quién lo lleva a casa: "El robot lo llevará a casa." si hay robot de carga, o "Te espera en el silo." si no lo hay. Nada se paga al cargar: el hielo espera en el silo hasta que se entrega.

### 2.14 Vehículos y el garaje

El garaje de rovers guarda dos vehículos. Usa "Manejar" para subirte y "Traerlo de vuelta" para devolverlo.

- **Carrito lunar** (garaje nivel 1): un auto abierto de dos asientos inspirado en el Lunar Roving Vehicle de Apollo. Un amigo puede ir de copiloto.
- **Camión de hielo** (garaje nivel 2): lleva 4 núcleos de hielo. "Subir hielo" en el cráter y luego "Bajar hielo" en la máquina de agua.

Al manejar, la cámara se aleja a una vista de persecución. Un vehículo volcado se vuelve a poner sobre sus ruedas.

### 2.15 Mascotas y vestidor

Las mascotas siguen al jugador y son solo decorativas.

| Mascota | Cómo conseguirla |
| :--- | :--- |
| Laika | Encontrar el secreto de Laika |
| Quesito lunar | Encontrar el secreto del queso |
| Conejo lunar | Adoptarlo en el Laboratorio: 120 créditos, nivel de jugador 3 |
| Chimpancé espacial | Adoptarlo en el Laboratorio: 200 créditos, nivel de jugador 7 |

El **Vestidor** conserva el avatar propio del jugador y solo agrega equipo espacial. Espacios: Casco (Clásico, Explorador dorado), Mochila (Clásica, Laika), C.A.R.L. (Clásico, Mini Tierra) y Mascota (o "Sin mascota"). Las recompensas se pueden quitar. Las franjas del traje de la cápsula diaria y de la Bitácora se ponen o se quitan en la página Franjas de la Bitácora (sección 2.20).

### 2.16 Explorar la Luna

Cinco **lugares de exploración**, que se escanean con la tableta ("Escanear"), muestran cada uno una tarjeta con un dato real:

| Lugar | Basado en |
| :--- | :--- |
| Nave robot inclinada | El módulo de aterrizaje Odysseus, que en 2024 aterrizó cerca del polo sur y quedó inclinado |
| Cráter del choque LCROSS | LCROSS, que en 2009 se estrelló en un cráter oscuro y encontró agua |
| Huellas de rocas rodantes | Rocas que se sueltan por sismos lunares o impactos |
| Choque del Lunar Prospector | Lunar Prospector, que en 1999 se estrelló a propósito en un cráter oscuro |
| Pico soleado | Picos cerca del polo sur que reciben luz del Sol la mayor parte del año |

Los **meteoritos** caen al azar, cada 4 a 7 minutos. Solo se ve un destello, sin estela de fuego, porque la Luna casi no tiene aire. El cráter nuevo permanece 5 minutos. C.A.R.L. lo señala y la tableta lo escanea.

**Eclipses.** El Sol da vueltas por el horizonte, como en el verdadero polo sur lunar (el cielo del juego va mucho más rápido). Cuando pasa detrás de la Tierra que gira, la base se oscurece y la Tierra muestra un anillo rojo anaranjado. C.A.R.L. dice "¡Eclipse! La Tierra está tapando el Sol."

**El borde del mapa.** Unas paredes invisibles están 12 studs antes de la orilla del terreno, así que ni caminando, ni con la mochila propulsora, ni en el carrito se puede llegar al vacío. Una franja naranja al pie de cada pared aparece a menos de 80 studs, y C.A.R.L. dice "Aquí termina el mapa. ¡Da la vuelta!".

**Salidas del cráter de hielo.** Además de la primera rampa, otras dos rampas de 14 studs de ancho salen del cráter, con delgadas franjas guía cian en sus orillas (el cian indica guía). Siempre hay una rampa cerca de cualquier punto del fondo del cráter.

### 2.17 Secretos, coleccionables y códigos

Cuatro coleccionables se esconden alrededor de la base: **Mini Tierra, Laika, Queso lunar y Papa marciana**. Entre los escondites hay un espacio para gatear, una roca mirador, un tubo de lava y los rincones más oscuros. Cada uno abre una tarjeta de mito contra ciencia y da un premio:

| Coleccionable | Premio |
| :--- | :--- |
| Mini Tierra | Una cabeza de Tierra que gira para C.A.R.L. |
| Laika | Una mochila de aire magenta y la mascota Laika |
| Queso lunar | Pintura amarillo queso para el rover de ciencia y la mascota Quesito lunar |
| Papa marciana | La bandera del equipo en el techo de la base |

Encontrar los cuatro abre un quinto secreto: un **observatorio** escondido con un telescopio que apunta a Marte ("Próxima misión: Marte"). La página Secretos de la Bitácora lunar muestra los secretos encontrados (sección 2.20). Mientras Tesoros escondidos está abierta, C.A.R.L. da pistas tipo adivinanza después de 5 minutos sin un hallazgo nuevo.

**Códigos.** La Configuración tiene un cuadro "¿Tienes un código?". El servidor revisa el código; los códigos nunca se envían a los jugadores. El código del evento da el "Casco dorado Explorador 2026" (visor y detalles dorados), solo una apariencia, nunca una ventaja en el juego.

**Logros de aprendizaje (Etapa 10).** El botón "Logros" de la barra superior (modo base) abre un panel con 13 logros. Cada uno premia entender una parte de la ciencia, y el servidor solo lo desbloquea cuando ve el evento real. Los desbloqueados muestran lo que aprendiste; los bloqueados muestran una pista (y el avance, por ejemplo 3/10). Las pistas dicen adónde ir: las cinco lecciones que solo ocurren en un turno de misión lo indican ("En misión de tormenta, quédate en el refugio"). El panel muestra páginas de mosaicos grandes, y las palabras del glosario en los datos se ven doradas (sección 2.21). Cada logro da 10 XP una sola vez por partida, con una tarjeta "¡Logro desbloqueado!". Cuando el equipo crea la insignia de Roblox correspondiente en Creator Hub, el jugador también recibe la insignia.

| Logro | Cómo se desbloquea | Qué enseña |
| :--- | :--- | :--- |
| Aire del agua | Entregar hielo en un turno con la máquina de aire encendida | El oxígeno sale del agua más electricidad |
| Granjero paciente | Dar energía al invernadero y empezar el día siguiente | Las plantas tardan en crecer (lechuga en la ISS: 33 días) |
| A salvo tras muros gruesos | Quedarse en el refugio durante toda una tormenta de partículas | El refugio protege por su masa, no por la energía |
| No toda llamarada trae tormenta | Vivir una gran llamarada sin tormenta de partículas | Una gran llamarada no siempre trae tormenta de partículas |
| ¡Hola, Tierra! | Conectar la antena con la Tierra | Las señales tardan unos 1.3 segundos en llegar a la Tierra |
| Cazador de hielo | Entregar 10 hielos en total | El hielo de los cráteres polares puede dar agua y aire |
| Limpiador de paneles | Limpiar 5 paneles solares con polvo | El polvo tapa la luz y los paneles dan menos energía |
| Buscador de datos | Abrir la pantalla "Datos reales de la NASA" | Los científicos revisan de dónde vienen sus números |
| Listo para tormentas | Terminar el entrenamiento Simulacro de tormenta | Las partículas pueden llegar en 30 minutos o menos |
| Constructor lunar | Llegar al nivel 3 de la base (en tu propio mundo) | Cada edificio cuesta créditos, piezas y tiempo |
| Listos para Marte | Construir la nave (en tu propio mundo) | Un mensaje a Marte puede tardar hasta 22 minutos |
| Explorador lunar | Escanear todos los lugares de exploración | Los exploradores leen la historia de la Luna en rocas y cráteres |
| Héroe de la historia | Terminar los tres capítulos de la historia | Las tripulaciones reales planean: cada decisión cuesta algo |

### 2.18 Módulos presurizados y tubos transitables

Estos lugares cuentan como **adentro** una vez construidos: el núcleo redondo del hábitat, el tubo del núcleo, los domos 1 y 2 del invernadero, el Laboratorio y la nave. Adentro se recargan el aire del traje y el tanque de gas, y se puede comer comida fresca. Afuera, el aire del traje se gasta.

Los tubos que van del domo A al domo B del invernadero y del núcleo al Laboratorio se pueden recorrer caminando, con pisos, entradas y una rampa suave hacia el piso del Laboratorio. Unas compuertas de vidrio cierran las entradas hasta que se construyen el invernadero nivel 2 y el Laboratorio.

### 2.19 La cápsula de suministros diaria

Una vez por día real se puede abrir una cápsula de suministros. Los días son días UTC del reloj del servidor; el reloj del dispositivo nunca cuenta.

- **La llegada.** Cuando hay una cápsula esperando y el jugador pasa 4 segundos en la base abierta, una pequeña cápsula cae junto al depósito de piezas de la nave de llegada, con un anillo de polvo, un pitido y un golpe. C.A.R.L. dice "¡Una cápsula llegó junto a la nave!" y se abre la tarjeta (nunca encima de otro panel). La cápsula conserva la indicación "Abrir la cápsula" para volver a abrir la tarjeta. Después de abrirla, su tapa se levanta y la cápsula se va 25 segundos después. Con Menos movimiento, se coloca sin caer.
- **Un calendario de 7 días, visible por adelantado.** La tarjeta muestra todos los premios de la semana (tabla abajo). El día 7 da las franjas de amanecer en la semana 1, azul hielo en la semana 2 y verde jardín en la semana 3; después, los días 7 pagan 30 créditos. No hay azar, ni cajas de botín, ni nada que comprar. Una semana paga 45 créditos y 60 XP, no más que tres escaneos de cráteres nuevos, así que jugar siempre da más que esperar.
- **Comprensiva.** El calendario cuenta las cápsulas abiertas, no los días seguidos: "¿Faltaste un día? Tu calendario te espera." Nunca se quita nada.
- **Datos de la carga.** Cada tarjeta muestra uno de siete datos cortos que repiten ciencia que ya está en `DATA_SOURCES.md` (lo que necesita la tripulación, del hielo al agua, agua más energía da aire, el reciclaje de agua de la Estación Espacial, las plantas necesitan tiempo, la masa protege, el oxígeno en las rocas lunares), sin números. La tarjeta también dice "Un regalo del juego, no un vuelo real."
- **Se guarda por mundo,** como los logros, así que un invitado conserva su propio calendario en el mundo de un amigo.

| Día | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Premio | 10 créditos | 15 XP | 15 créditos | 20 XP | 20 créditos | 25 XP | Franjas del traje |

### 2.20 La Bitácora lunar

La Bitácora reemplaza a la antigua pantalla de Colección. Se abre con el botón "Bitácora" de la pantalla de misiones y desde la tarjeta de la cápsula, y es un libro con pestañas:

| Pestaña | Qué contiene |
| :--- | :--- |
| Secretos | Los cuatro coleccionables y el observatorio. |
| Lugares | Los cinco lugares de exploración, con el dato real una vez escaneados. |
| Rocas espaciales | Los primeros 5 cráteres de meteorito nuevos escaneados. |
| Logros | Los 13 logros de aprendizaje, con el dato o la pista. |
| Datos | Los datos de la carga de las cápsulas abiertas y los datos curiosos que compartió C.A.R.L. (no cuentan como registros). |
| Franjas | Las franjas del traje que se tienen, para ponerlas o quitarlas. |

Hay 27 registros: 4 secretos, 5 lugares, 5 rocas espaciales y 13 logros ("12 de 27 registros llenos"). Llenar 5, 12 y 20 registros desbloquea las franjas de estrella dorada, rosa secreto y explorador lunar ("Llena 5 registros", luego "Reclamar"). El servidor cuenta los registros por su cuenta. C.A.R.L. avisa una vez cuando hay un premio listo: "¡Premio listo! Abre tu bitácora."

Las **franjas del traje** son seis apariencias: dos bandas con los colores de Lunar Sunrise alrededor de cada brazo, hechas con piezas simples y visibles para todos. Son solo una apariencia. Las primeras franjas que se ganan se ponen de inmediato.

### 2.21 C.A.R.L. pregunta, y el glosario con imágenes

**C.A.R.L. pregunta.** Después de 11 aventuras (energía, plantas, polvo, refugio, hielo, aire, radiación, cráteres, llamaradas, radio y Marte), unos 12 segundos después de terminar la aventura y solo entre misiones, C.A.R.L. hace una pregunta con imagen, con 2 o 3 botones grandes de respuesta (un ícono y palabras), "Ahora no" y un botón para cerrar.

- Una respuesta correcta da "¡Correcto! +5 XP" con estrellas y una frase que explica por qué, como "¡Sí! Los muros gruesos frenan las partículas."
- Una respuesta equivocada da una pista y "¡Buen intento! Te pregunto otra vez luego."; la pregunta vuelve a los 3 minutos. "Ahora no" también la hace volver después.
- No se pierde nada y nada depende de contestar bien. Cada pregunta paga una sola vez por mundo.
- El servidor elige la pregunta y revisa la respuesta; la respuesta correcta nunca se envía al dispositivo del jugador. Los textos no citan números y siguen las reglas científicas (sección 3.2).
- La tarjeta no bloquea el juego: se oculta mientras hay un panel o una misión y regresa después.

**El glosario con imágenes.** Nueve palabras tienen una tarjeta con imagen: hábitat, caja de piezas, panel solar, cráter de hielo, oxígeno, radiación, llamarada solar, silo y nivel de base. En los pasos de las aventuras y en los datos de los logros, estas palabras se ven doradas y subrayadas, con un pequeño ícono de libro. Al tocar la fila o el mosaico se abre "¿Qué significa?" con el ícono de la palabra y una definición de una línea. También reconoce plurales y otras formas ("paneles solares", "cajas de piezas").

**Panel de logros.** El panel muestra páginas de 6 mosaicos grandes (4 en pantallas pequeñas) con "Página 1 de 3", y los datos largos bajan de renglón en vez de encogerse.

### 2.22 Celebraciones

- **Momentos importantes.** Una aventura terminada, un logro, subir de nivel de jugador, subir de nivel de base y una misión terminada traen confeti con los colores de Lunar Sunrise, un destello suave en la pantalla y, en los niveles, un título grande ("Nivel 4", "Nivel de base 2"). Subir de nivel de base y cada edificio terminado también traen destellos en la plataforma, con los colores de Theme. Los momentos que llegan juntos se muestran uno tras otro, cada uno en menos de 2 segundos, y nunca bloquean un toque.
- **El reporte.** Las estrellas ganadas aparecen una por una con un salto y una nota que sube, y una misión completa hace llover confeti. Cada día se lee como causa y efecto: el evento y su razón, una flecha y hasta tres fichas con lo que cambió ese día (aire o comida que sube o baja, dosis que sube, ciencia enviada). La ficha de la dosis solo apunta hacia arriba, porque la dosis nunca baja.
- **La cámara.** Un meteorito que cae a menos de 170 studs da una sacudida corta y pequeña que disminuye con la distancia: una vibración a través del suelo, porque no hay aire que lleve una onda expansiva. Una tormenta solar nunca sacude la cámara, porque la radiación es silenciosa y no empuja nada; en su lugar, el aviso de la llamarada y la llegada de las partículas hacen palpitar en naranja los bordes de la pantalla (una falsa alarma solo tiene el pulso del aviso).
- **Menos movimiento** (Ayudas): sin sacudidas, sin confeti ni destellos, un destello de pantalla muy suave, títulos que aparecen sin moverse y estrellas que aparecen sin saltar.

### 2.23 Sonido y música

El juego tiene 50 sonidos: 6 pistas de música, 3 remates musicales y 41 efectos. La música y la mayoría de los efectos los sintetizó el código propio del equipo, y cinco efectos mezclan grabaciones CC0 editadas de Freesound (sección 6.2). Ningún sonido viene de la Toolbox ni del Marketplace.

- **La música sigue al juego:** el menú de inicio, la base de día, la construcción (mientras hay una obra en curso y durante un minuto después de un paso), las misiones, las tormentas (aviso y partículas) y el eclipse, con transiciones de 2.5 segundos. Los remates de victoria, de misión fallida y de subir de nivel suenan en el reporte y al subir de nivel.
- **La regla del casco.** En el vacío no hay sonido. Los sonidos del mundo fuera del casco (obras, cajas, hielo, taladros, el carrito, la mochila propulsora, meteoritos) suenan más bajo y apagados mientras el jugador está afuera, como si se sintieran a través del traje y las botas. Los sonidos del radio, la tableta y C.A.R.L. se oyen claros. Dentro de los módulos todo suena normal, y la música no es parte del mundo.
- **Sin sonidos de la Tierra.** Los pasos, saltos y aterrizajes predeterminados de Roblox están silenciados; los pasos solo suenan dentro de los módulos. Un meteorito es un tono de radar en el radio más un golpe que se siente en el suelo, nunca un zumbido en el aire. La estática de la tormenta solo suena cuando de verdad llegan las partículas, así que una falsa alarma queda en silencio después de su alarma.
- **Respuesta al jugador.** Los botones hacen clic (los botones grises dan un "no" suave), los paneles suenan al abrir y cerrar, las monedas, la XP, los niveles, las aventuras y los logros tienen sus propios sonidos, C.A.R.L. pita, y los taladros, la banda y el silo zumban de cerca.
- **Volumen.** Los controles de Música y Efectos de la Configuración controlan todos los sonidos.

### 2.24 Configuración y Ayudas

La Configuración tiene dos páginas:

- **Juego:** idioma (inglés o español), volumen de música y de efectos, los datos curiosos y el haz guía de C.A.R.L., el cuadro "¿Tienes un código?" y **Guardar ahora**.
- **Ayudas:** cada fila tiene una explicación de una línea, y una frase de muestra ("¡Hola! Así se ve tu texto.") enseña el tamaño del texto.

| Ayuda | Opciones | Qué hace |
| :--- | :--- | :--- |
| Tamaño del texto | Normal, Grande | Letras grandes (1.25 veces) en todos los textos, botones y etiquetas de una línea, al momento. |
| Menos movimiento | Sí, no | Sin cámara que tiembla, sin confeti, pantallas más tranquilas. |
| Tiempo de mensajes | Normal, Largo, Más largo | Los mensajes de C.A.R.L. y los avisos de aventuras duran 1, 1.5 o 2 veces más. |
| Ayuda de colores | Sí, no | "Muestra formas, no solo colores." |

**La configuración acompaña al jugador.** El servidor guarda cada ajuste con la cuenta del jugador y revisa cada valor. Los ajustes regresan después de viajar a un servidor de mundo, de volver a entrar o de cambiar de dispositivo; el idioma del dispositivo ya no sobrescribe el idioma guardado al iniciar. Tocar fuera del panel lo cierra.

### 2.25 Controles

| Acción | Teclado y mouse | Táctil |
| :--- | :--- | :--- |
| Moverse | WASD | Palanca virtual |
| Correr (el aire del traje se gasta el doble de rápido) | LeftShift (cambia entre correr y caminar) | Botón de correr |
| Usar una tarea, construir, recoger, escanear | Mantener E | Tocar la indicación |
| Elegir una herramienta | Barra de herramientas de Roblox | Barra de herramientas de Roblox |
| Encender o apagar las botas de aire | B | Botón de botas |
| Encender o apagar la mochila propulsora | J | Botón de mochila propulsora |
| Doble salto (botas de aire) | Espacio dos veces | Botón de saltar dos veces |
| Volar hacia arriba (mochila propulsora) | Mantener Espacio en el aire | Mantener el botón de saltar |
| Avanzar solo | X (X o cualquier tecla WASD lo detiene) | Botón de avanzar solo |
| Manejar | WASD en el asiento del conductor | Palanca virtual |
| Bajarse de un vehículo | Espacio | Tocar saltar |
| Volver a leer a C.A.R.L. | Clic en el botón para repetir junto al globo | Tocar el botón para repetir |
| Contestar la pregunta de C.A.R.L. | Clic en una respuesta | Tocar una respuesta |
| Aprender una palabra dorada | Clic en el paso de la aventura o en el mosaico | Tocarlo |
| Configuración, Misiones, Vestidor, Logros | Botones arriba a la derecha | Igual |
| Bitácora lunar | "Bitácora" en la pantalla de misiones, o la tarjeta de la cápsula | Igual |
| Idioma | Configuración, página Juego (inglés o español) | Igual |

En un control de videojuegos, A sirve para bajarse de un vehículo y mantener A en el aire enciende la mochila propulsora, y cada cuadro pone la selección en su botón seguro. En primera persona, el mouse se libera cada vez que hay una tarjeta o un panel abierto.

Los jugadores no tienen teclas de depuración. Las teclas de prueba del equipo solo existen en Roblox Studio, y el servidor rechaza toda acción de depuración en el juego en vivo (sección 4.11).

## 3. Ciencia y datos de la NASA

Space Base Odyssey es ante todo un juego, pero cada regla que toca la ciencia tiene que ser verdadera. La lista completa de fuentes, con enlaces, está en la sección 6 y en `DATA_SOURCES.md`.

### 3.1 Objetivos de aprendizaje

Después de jugar, un niño o niña debería poder expresar estas cinco ideas con sus propias palabras:

1. **La energía es limitada.** Nunca alcanza para todo, así que hay que elegir, y la elección se nota después.
2. **El aire sale del agua.** Los astronautas producen oxígeno a partir de agua con electricidad. Sin agua, hay menos aire.
3. **Las plantas tardan en crecer.** La comida que se siembra hoy alimenta mañana, no ahora.
4. **Las paredes gruesas protegen, y la radiación se acumula.** La dosis nunca desaparece, por eso hay que esconderse cuando llegan las partículas del Sol.
5. **Hablar con la Tierra requiere un enlace que funcione.** Desde la Luna una señal tarda unos 1.3 segundos; desde Marte, hasta 22 minutos.

Los niños no leen estas ideas en una lección. Las sienten, por ejemplo, cuando el medidor de comida baja el día después de quitarle energía al invernadero.

### 3.2 Reglas científicas que el juego respeta

Estas reglas están escritas en `CLAUDE.md` y se aplican a cada mecánica, cada línea de texto y cada dato curioso.

| Regla | Cómo la respeta el juego | Base real |
| :--- | :--- | :--- |
| El refugio protege por su masa, no por energía. | El refugio es un montículo de regolito con tanques de agua dentro. No usa celdas de energía. Estar dentro durante una tormenta de partículas mantiene baja la dosis. Un refugio sin construir (un holograma sobre su plataforma) no tiene masa, así que no protege a nadie. | NASA-STD-3001 y el informe sobre radiación de la OCHMO de la NASA: un refugio contra tormentas de unos 10 cm de equivalente en agua. |
| La dosis de radiación nunca baja. | `Simulation.luau` solo suma dosis: un poco cada día por los rayos cósmicos de fondo y más por cada astronauta que la tormenta sorprende afuera. Nada la reduce. | La dosis se acumula; el límite de carrera de la NASA cuenta el total. |
| Las plantas tardan en crecer. | La energía que recibe el invernadero un día se convierte en comida al día siguiente. La comida fresca que se cosecha en el invernadero también necesita tiempo antes de que la siguiente esté lista. | NASA Veggie: la primera lechuga que se comió en la Estación Espacial creció durante 33 días. |
| El oxígeno sale del agua más electricidad. | Las celdas de soporte vital hacen funcionar la máquina de aire, que usa agua del tanque. Con muy poca agua produce solo una parte del aire. El hielo aporta aire solo cuando la máquina de aire tiene energía. En la base, la planta de agua derrite el hielo del silo y la máquina de aire convierte esa agua en aire solo mientras haya al menos 2 arreglos solares; sin energía, el robot de carga lleva agua en su lugar. | Hoja informativa del ECLSS de la ISS de la NASA: el oxígeno se produce separando el agua con electricidad. |
| Una gran llamarada no siempre trae una tormenta de partículas. | Algunos días de tormenta son falsas alarmas reales: una llamarada enorme que DONKI no vincula con ningún evento de partículas. Aun así, refugiarse era la decisión correcta. | NASA / CCMC DONKI, por ejemplo la llamarada X9.0 del 3 de octubre de 2024. |
| Los eventos de DONKI se observaron cerca de la Tierra. | Cada tormenta es una repetición: "¿y si una tormenta así llegara a tu base?". El juego nunca dice que una tormenta registrada haya golpeado la Luna. | Los eventos de DONKI se observan desde las cercanías de la Tierra. |
| La Luna casi no tiene aire. | C.A.R.L. avanza sobre orugas y salta con propulsores de gas, porque las hélices necesitan aire. Los meteoritos caen con un destello y sin estela ardiente. El cielo es negro y el Sol se mantiene blanco y bajo. | NASA "The Moon's Atmosphere"; NASA Glenn; NASA Meteoroid Environment Office. |
| En el vacío no hay sonido. | Fuera del casco, los sonidos del mundo suenan más bajo y apagados, como si se sintieran a través del traje; el radio, la tableta y C.A.R.L. se oyen claros. Los pasos terrestres están silenciados. Un meteorito es un tono de radar y un golpe a través del suelo. Las tormentas nunca sacuden la cámara, y su estática solo suena cuando llegan las partículas. | El sonido necesita aire u otro material para viajar; la Luna casi no tiene aire (NASA "The Moon's Atmosphere"). |

El juego también conserva la proporción real entre la gravedad de la Luna y la de la Tierra (1.62 / 9.81). El cielo del juego avanza mucho más rápido que el real: en el verdadero polo sur, el Sol da una vuelta al horizonte por cada día lunar (unos 29.5 días terrestres). El panel de Fuentes lo aclara.

### 3.3 Cómo cada tema del reto se convierte en una decisión con consecuencias

| Tema | Decisión | Consecuencia | Datos reales detrás |
| :--- | :--- | :--- | :--- |
| Presupuesto de energía | Cada mañana, cuántas celdas de energía van a soporte vital, invernadero y ciencia. Cada arreglo solar limpio que los jugadores han construido da una celda y la batería una más, así que una base completa tiene 4. Cada sistema recibe como máximo 2. | Una celda para ciencia es una celda que se le quita al aire o a la comida. El polvo quita una celda hasta que alguien limpia el panel. El tablero recorta primero la ciencia y al final el soporte vital. Cada taladro de hielo automático necesita un arreglo solar más. | Un punto del borde del cráter Shackleton recibe luz solar unos 240 días al año (topografía del LRO), así que la energía solar es adecuada para el polo sur. |
| Soporte vital | Energía para el soporte vital, traer hielo, arreglar fugas y cuándo recargar el traje adentro. Entre misiones: construir la línea de hielo y suficientes arreglos solares para la máquina de aire. | Las celdas de soporte vital convierten agua en aire; el hielo llena el tanque. Respirar, una fuga abierta y cada recarga del traje consumen aire de la base. Sin energía, la máquina de aire se detiene y el robot de carga lleva agua en vez de aire. | NASA BVAD 2022: unos 0.895 kg de oxígeno y 2.5 kg de agua por tripulante al día. LCROSS encontró hielo en un cráter en sombra. |
| Producción de alimentos | Energía para el invernadero; construir la segunda cúpula. | La energía de hoy en el invernadero es la comida de mañana. Recortarla parece gratis hasta el día siguiente. | NASA Veggie: 33 días hasta la primera comida de lechuga. Unas 3,000 kcal por tripulante al día. |
| Protección contra la radiación | Esconderse en el refugio durante una tormenta o seguir trabajando afuera. | Todos los que están afuera cuando llegan las partículas suman dosis. Alcanzar el límite hace que la tripulación regrese antes a casa. | Llamaradas reales de DONKI. Chang'e-4: unos 1.37 mSv al día en la Luna, frente a 6.2 mSv al año en Estados Unidos. Límite de carrera de la NASA: 600 mSv. |
| Retraso en las comunicaciones | Usar tiempo del turno para alinear la antena con la tableta, o hacer otras tareas. | Con el enlace, la Tierra avisa a la tripulación 45 segundos antes de que lleguen las partículas; sin él, 15 segundos. El enlace también envía la ciencia pendiente. Una antena más grande y luego un enlace láser envían más datos. | 1.3 segundos de la Luna a la Tierra; de 3 a 22 minutos desde Marte. NASA: los enlaces láser transmiten de 10 a 100 veces más datos que la radio. |

Los avisos de 45 y 15 segundos son valores de juego. Enseñan una idea real: las partículas más rápidas del Sol pueden llegar en unos 30 minutos o menos, así que cada minuto de aviso cuenta. Además, la ciencia espera en la base hasta que la antena la envía a la Tierra; la ciencia no enviada no gana estrellas.

### 3.4 Clima espacial en vivo de NASA / CCMC DONKI

DONKI es la base de datos de clima espacial del Community Coordinated Modeling Center (CCMC) de la NASA. El juego lee llamaradas solares (FLR) y eventos de partículas solares energéticas (SEP).

#### Cómo se obtienen

`src/server/SpaceWeatherService.luau` se ejecuta una vez cuando arranca un servidor del juego:

1. Consulta `https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR` y `.../SEP` para los últimos 30 días. Este servidor no requiere clave de API.
2. Espera como máximo 15 segundos y necesita ambas respuestas: sin eventos de partículas, una llamarada no puede clasificarse como tormenta ni como falsa alarma.
3. Una llamarada "tiene partículas" cuando DONKI la vincula con un evento SEP medido por los satélites GOES. El vínculo se lee de ambos registros, porque DONKI no siempre lo guarda en los dos.
4. El resultado se queda en la memoria del servidor mientras ese servidor exista. La consulta no se repite, así que la hora que se muestra es la de esa única consulta.

Si las solicitudes HTTP están desactivadas, una solicitud falla o se agota el tiempo, o la respuesta no se puede leer, el juego usa solo el archivo guardado y lo indica. El enlace en vivo requiere **Allow HTTP Requests** en la configuración de seguridad de la experiencia.

#### Qué llamarada repite una tormenta

- Las llamaradas en vivo de clase M5 o más fuertes entran al grupo de opciones y se prefieren cuando alguna encaja.
- Una llamarada en vivo sin evento de partículas vinculado se convierte en falsa alarma solo cuando tiene al menos dos días de antigüedad, porque DONKI vincula los eventos de partículas más tarde.
- La primera tormenta de una misión siempre trae partículas, para que los jugadores aprendan por qué importa el refugio antes de enfrentar una falsa alarma. Las misiones de entrenamiento y de historia pueden elegir para cada tormenta.
- Ninguna llamarada se repite en una misión mientras exista otra opción, y una llamarada siempre conserva su estado real de partículas.

#### El archivo guardado

`src/shared/SpaceWeatherArchive.luau` contiene 11 llamaradas reales de clase X, descargadas de DONKI el 14 de noviembre de 2026:

| Pico de la llamarada (UTC) | Clase | Evento de partículas cerca de la Tierra |
| :--- | :--- | :--- |
| 2024-05-10 06:54 | X3.9 | Sí |
| 2024-05-11 01:23 | X5.8 | Sí (más de 100 MeV) |
| 2024-05-14 16:51 | X8.7 | No (falsa alarma) |
| 2024-10-01 22:20 | X7.1 | No (falsa alarma) |
| 2024-10-03 12:18 | X9.0 | No (falsa alarma) |
| 2024-10-09 01:56 | X1.8 | Sí (más de 100 MeV) |
| 2024-10-26 07:19 | X1.8 | Sí |
| 2025-11-11 10:04 | X5.1 | Sí (más de 100 MeV) |
| 2025-11-14 08:30 | X4.0 | Sí |
| 2026-01-18 18:09 | X1.9 | Sí |
| 2026-02-01 23:57 | X8.1 | No (falsa alarma) |

Cuatro de las llamaradas más grandes no trajeron ninguna tormenta de partículas cerca de la Tierra: el tamaño de la llamarada por sí solo no decide el peligro.

#### En vivo y de archivo, siempre etiquetados

Una llamarada se llama "en vivo" solo cuando proviene de la consulta propia de este servidor, y solo con la hora de esa consulta.

- **Durante una tormenta,** C.A.R.L. dice "¡Como la llamarada real {class} del {date}! ¡Al refugio!". La pantalla del turno muestra "Llamarada real, datos en vivo de la NASA, {date}" o "Repetición de una llamarada real del {date}". Después de una falsa alarma: "¡La llamarada real {class} del {date} no trajo partículas!".
- **El panel "Datos reales de la NASA"** ("De dónde salen nuestros números") se abre desde la pantalla de selección de misiones, el tablero de energía y el reporte de la misión. Muestra:
  - El estado: "NASA en vivo: {n} llamaradas solares en 30 días", la hora de la consulta en UTC y la llamarada más reciente. Mientras la consulta está en curso, o si falló: "Sin conexión: usamos datos guardados de la NASA".
  - La fecha de descarga del archivo (2026-11-14).
  - 18 datos breves, la mayoría con un número real de `MissionData.REAL` (sección 3.5).
  - Una línea de texto por fuente, como "Clima espacial: NASA / CCMC DONKI", y una referencia a `DATA_SOURCES.md`. Roblox no permite enlaces externos dentro de una experiencia.

En la prueba en Studio de la Etapa 2, la consulta en vivo devolvió 13 llamaradas (la más fuerte, M3.5). Ninguna llegó a M5, así que la tormenta repitió la llamarada archivada X5.1 del 11 de noviembre de 2025, etiquetada como repetición.

### 3.5 Números REAL y GAME

Cada número vive en `src/shared/MissionData.luau` con una etiqueta:

- **REAL:** un valor del mundo real que debe aparecer en `DATA_SOURCES.md` con su fuente. Los jugadores ven los valores REAL solo en el panel de Fuentes y en las frases de C.A.R.L., nunca dentro de los medidores.
- **GAME:** un valor de ajuste para la jugabilidad: la misión de 7 días, el turno de 150 segundos, los medidores de 0 a 100, los avisos de tormenta, los costos en créditos.

#### Principales valores REAL

| Valor | Qué es | Fuente |
| :--- | :--- | :--- |
| 1.62 m/s² (16.5%) | Gravedad en la superficie de la Luna | NASA Moon fact sheet (NSSDC) |
| 1.3 s | Tiempo de la señal en un sentido, de la Luna a la Tierra | NASA TM-20250003885 |
| 3 a 22 min | Tiempo de la señal en un sentido, de la Tierra a Marte | Página de la NASA Mars Relay Network |
| 240 días al año | Luz solar en un punto cerca del borde del Shackleton | Mazarico et al. 2011 (LRO) |
| 25 K (unos -250 °C) | Temperatura más fría medida en la Luna, cráter Hermite | NASA LRO Diviner |
| 29.5 días terrestres | Un día y una noche lunares | Litografía del LRO de la NASA; NSSDC |
| 0.895 kg | Oxígeno por tripulante al día (se muestra como 0.9) | NASA BVAD Rev2, 2022 |
| 2.5 kg | Agua para beber y cocinar por tripulante al día | NASA BVAD Rev2, 2022 |
| 3,000 kcal | Energía de los alimentos por tripulante al día | NASA BVAD Rev2; verificación cruzada con la CSA |
| 33 días | Primera lechuga de la Estación Espacial, de la siembra a la comida | Hoja informativa de NASA Veggie |
| 5.6% | Hielo de agua en masa en el sitio de impacto de LCROSS | Colaprete et al., Science, 2010 |
| 1.37 mSv al día | Dosis en la superficie lunar | Chang'e-4 LND, Zhang et al. 2020 |
| 6.2 mSv al año | Dosis promedio por persona en Estados Unidos | US EPA |
| 600 mSv | Límite de radiación de carrera de la NASA | NASA-STD-3001 Vol. 1 Rev C |
| 10 cm de equivalente en agua | Refugio contra tormentas recomendado en una superficie | NASA-STD-3001; informe de la OCHMO de la NASA |
| Unos 30 min o menos | Las partículas más rápidas del Sol en llegar a la Tierra | Página de la NASA "Solar storms and flares" |
| Unos 8 min | La luz de una llamarada en llegar a la Tierra | Página de la NASA "Solar storms and flares" |

Algunos valores REAL más se conservan como referencia, pero todavía no se muestran (por ejemplo, el 98% de recuperación de agua de la ISS). Los 89 datos curiosos de C.A.R.L. también provienen únicamente de filas de `DATA_SOURCES.md`.

#### Cómo se verificaron los datos

`DATA_SOURCES.md` contiene 199 datos: 189 verificados, 9 corregidos y 1 sin verificar. Una investigación con IA los reunió, una revisión independiente con IA volvió a abrir cada fuente, y el equipo revisa cada valor antes de que entre al juego. Los datos sin verificar o descartados nunca aparecen.

### 3.6 Datos de agencias espaciales aliadas y otras referencias

**Agencia Espacial Canadiense (CSA).** El equipo leyó los recursos de la CSA sobre producción de alimentos enlazados por el reto, el Deep Space Food Challenge y el proyecto Naurvik en Nunavut, como contexto sobre cultivar alimentos lejos de las rutas de suministro. La página de la CSA "Eating in space" (de 1,900 a 3,200 calorías al día) sirve como verificación cruzada del valor de 3,000 kcal de la NASA. Ningún número de la CSA determina una mecánica; las reglas del invernadero provienen de NASA Veggie.

**Otras referencias:**

- **Experimento LND de Chang'e-4** (Zhang et al., 2020) y la **US EPA**: las dosis de radiación de la Luna y de la Tierra.
- **NASA Blue Marble** (dominio público): la Tierra que gira en el cielo, en el menú de inicio y en la apariencia de Tierra de C.A.R.L., con crédito en `THIRD_PARTY_NOTICES.md`.
- **Shackleton Base: A Journey to the Moon** (juego de mesa de Fabio Lopiano y Nestore Mangone): solo inspiración temática. No se copia nada de él.

No se usan logotipos, insignias ni parches de misión de la NASA. Cada fuente se acredita como texto.

### 3.7 Referencias del mundo real detrás de los sitios, vehículos y equipo

Los sitios son representaciones inspiradas en lugares reales: el juego nunca dice que un módulo de aterrizaje real o un sitio de impacto real esté junto a la base, y nunca afirma que el equipo que inventa haya existido.

| En el juego | Referencia real | Qué toma el juego de ella |
| :--- | :--- | :--- |
| Nave robot inclinada | Odysseus (IM-1), polo sur, febrero de 2024 | Quedó en reposo inclinado. |
| Cráter del choque LCROSS | Impacto de LCROSS en el cráter Cabeus, 9 de octubre de 2009 | Encontró agua en un cráter en sombra. |
| Huellas de rocas rodantes | Imágenes de la cámara del LRO | Las rocas sueltas ruedan y dejan huellas. |
| Choque del Lunar Prospector | Impacto planeado cerca del polo sur, 31 de julio de 1999 | Se estrelló a propósito para buscar hielo. |
| Pico soleado | Borde del cráter Shackleton | Algunos picos reciben luz solar la mayor parte del año. |
| Cráter de impacto nuevo (aleatorio) | NASA Meteoroid Environment Office; LRO | Un destello sin estela ardiente; siguen apareciendo cráteres nuevos. |
| Carrito lunar y camión de hielo | Apollo Lunar Roving Vehicle | Ruedas de malla de alambre sin aire, agarre en baja gravedad, unos 16 km/h. |
| Plataforma de aterrizaje | Estudios de la NASA sobre el escape de cohetes; Apollo 12 y Surveyor 3 | El escape lanza polvo y rocas; una plataforma detiene la proyección. |
| Arreglos solares altos | Proyectos de arreglos solares verticales de la NASA | El Sol polar se mantiene bajo, así que los paneles se colocan de pie. |
| Taladros de hielo automáticos | Taladro PRIME-1 / TRIDENT, 2025 | Se probó un taladro de 1 metro cerca del polo sur. |
| Saltos, botas de aire y mochila propulsora de C.A.R.L. | Páginas de cohetes de la NASA; MMU (1984) y SAFER | Los chorros de gas funcionan sin aire. Las botas y la mochila propulsora lunar son inventos del juego. |
| Saltos lunares | Apollo Lunar Surface Journal; Apollo 16 | Los astronautas avanzaban sobre todo a saltitos; John Young saltó unos 70 cm. |
| Construir con polvo lunar | NASA MMPACT | El polvo lunar podría convertirse en plataformas, caminos y refugios. |
| Mascotas | Laika (1957); el chimpancé Ham (1961); relatos del conejo de la Luna | Datos amables; la mascota espacial es un chimpancé porque Ham lo era. |

Cada referencia es una fila en las secciones de las Etapas 6 a 8 de `DATA_SOURCES.md`.

### 3.8 La ciencia en las funciones de la etapa 11

- **Del hielo al agua y al aire.** La línea de hielo muestra la cadena del soporte vital una máquina a la vez: los taladros sacan hielo de un cráter polar, la planta de agua lo derrite y la máquina de aire separa el agua en oxígeno con electricidad. El letrero de la planta lo dice con íconos (hielo, agua, aire) y con palabras ("Hielo da agua; agua con energía da aire."). Con menos de 2 arreglos solares la máquina de aire se detiene y el robot lleva agua: sin energía no hay aire. Así fabrica oxígeno la Estación Espacial (electrólisis, ECLSS de la NASA), y por eso importa el hielo de agua que LCROSS encontró en un cráter en sombra para una futura base. El juego no afirma que una base lunar real funcione así hoy.
- **El sonido en el vacío.** El sonido necesita aire u otro material para viajar, y la Luna casi no tiene aire. Por eso los sonidos del mundo fuera del casco son suaves y apagados, como si se sintieran a través del traje y las botas; el radio, la tableta y C.A.R.L. se oyen claros; los pasos terrestres de Roblox están silenciados; un meteorito es un tono de radar y un golpe a través del suelo; y una tormenta no tiene sonido propio hasta que las partículas llegan al radio como estática.
- **Sensaciones sin física falsa.** Un meteorito cercano sacude un poco la cámara, como una vibración a través del suelo, nunca como una onda expansiva en el aire. Una tormenta solar nunca sacude nada: la radiación es silenciosa y no empuja, así que en su lugar los bordes de la pantalla brillan en naranja.
- **La dosis nunca baja, en ninguna pantalla.** La ficha de dosis del reporte solo apunta hacia arriba, y el medidor de radiación en vivo solo sube.
- **Palabras sin números.** Las preguntas de C.A.R.L., las tarjetas del glosario y los datos de la carga de la cápsula no citan números, así que nada puede alejarse de `DATA_SOURCES.md` (`tests/localization` y `tests/daily` lo revisan). Las respuestas científicas del banco de preguntas siguen las reglas de 3.2: el refugio protege por su masa, las plantas tardan en crecer, el oxígeno sale del agua más electricidad, una gran llamarada no siempre trae una tormenta de partículas.
- **Regalos honestos.** La cápsula de suministros dice "Un regalo del juego, no un vuelo real."
- **Diseño para aprender.** C.A.R.L. felicita la estrategia que funcionó, no a la persona (Mueller y Dweck, 1998: felicitar el esfuerzo y la estrategia genera perseverancia), hace preguntas cortas para recordar después de una lección y sugiere un descanso después de 45 minutos de juego. Son referencias de diseño, no números que se muestran a los jugadores.

## 4. Diseño técnico

Esta sección explica cómo está construido Space Base Odyssey, cómo ejecutarlo y cómo está organizado y probado el código. Describe el juego tal como se encuentra en la Etapa 11 (compilación `0.11.0-stage11` en `src/shared/Version.luau`).

### 4.1 Herramientas

| Herramienta | Versión | Para qué se usa |
| :--- | :--- | :--- |
| Roblox Studio | actual | Motor, pruebas de juego, publicación |
| Luau | modo estricto | Cada archivo de código comienza con `--!strict` y una línea de declaración de uso de IA (SI) |
| Rojo | 7.7.1 | Sincroniza los archivos de este repositorio con Studio y genera un archivo de lugar (place) |
| Lune | 0.11.1 | Ejecuta los conjuntos de pruebas fuera de Roblox |
| Python | 3 | Los scripts del equipo que sintetizan el audio (en `promo/audio/synth`, excluido por git) |
| Servidor MCP de Roblox Studio | - | Permite que el asistente de IA inicie el modo Play y lea la consola durante las pruebas de juego dirigidas por el asistente |
| Git y GitHub | - | Control de versiones y el repositorio público |
| Claude (Anthropic), en Claude Code | - | Asistencia de IA, declarada en la sección 6.4 |

Los archivos del repositorio son la fuente de verdad. Los scripts nunca se editan dentro de Studio, y el mundo se construye mediante código, no con piezas colocadas a mano. No se usan recursos de la Toolbox ni del Marketplace.

### 4.2 Estructura del repositorio

| Ruta | Contenido | Se sincroniza con |
| :--- | :--- | :--- |
| `src/shared` | Reglas de la misión, números, contrato de red, aventuras, textos, íconos, lista de sonidos, tema | `ReplicatedStorage.Shared` |
| `src/server` | Constructor del mundo, servicios, datos de la NASA en vivo, partidas guardadas | `ServerScriptService.Server` |
| `src/client` | Interfaz, guía, C.A.R.L., sonido, ayudas de movimiento | `StarterPlayer.StarterPlayerScripts.Client` |
| `tests` | Once conjuntos de pruebas de Lune | no se sincroniza |
| `default.project.json` | Archivo de proyecto de Rojo (las tres asignaciones anteriores) | - |
| `docs-public` | Paquete para docentes: tres planes de clase de 20 minutos, en español y en inglés | - |
| `DATA_SOURCES.md` | Cada número del mundo real con su fuente | - |
| `THIRD_PARTY_NOTICES.md` | Licencias de recursos de terceros (Tabler Icons, mapa Blue Marble de la NASA, grabaciones de sonido CC0) | - |
| `DOCUMENTATION.md`, `DOCUMENTACION.md` | Este documento, en inglés y en español | - |
| `DEVELOPMENT.md` | Bitácora de desarrollo, decisiones, evidencia de pruebas, uso de IA | - |
| `README.md` | Presentación breve, controles, estado y cómo ejecutarlo | - |
| `SUBMISSION.md` | Los campos de la página del proyecto de Space Apps | - |
| `CLAUDE.md` | Reglas del proyecto para asistentes de programación con IA | - |
| `LICENSE` | Apache License 2.0 | - |

### 4.3 Ejecución local

1. Instale Rojo 7.7.1 y su complemento (plugin) para Roblox Studio.
2. Abra un lugar Baseplate vacío en Roblox Studio.
3. Active **Game Settings > Security > Allow HTTP Requests**. La consulta en vivo del clima espacial de la NASA lo necesita. Sin esta opción, el juego recurre al archivo guardado.
4. Ejecute `rojo serve` en la carpeta del repositorio y presione **Connect** en el complemento de Rojo.
5. Presione **Play**.

Para comprobar que el proyecto todavía se compila en un archivo de lugar:

```
rojo build default.project.json -o <temp>.rbxl
```

Para ejecutar las pruebas (desde la carpeta del repositorio):

```
lune run tests/balance
lune run tests/missions
lune run tests/base
lune run tests/economy
lune run tests/cinematic
lune run tests/worlds
lune run tests/achievements
lune run tests/daily
lune run tests/feel
lune run tests/reading
lune run tests/localization
```

### 4.4 Arquitectura

#### Servidor autoritativo

El servidor es dueño del estado del juego: la fase de la misión, los medidores, las construcciones, los créditos, el silo y las partidas guardadas. Un cliente nunca cambia el estado directamente. Solo envía una tabla `Types.Action` a través de un único RemoteEvent, y el servidor revisa cada acción antes de actuar sobre ella (que el jugador tenga una partida cargada, que la fase sea la correcta, que el jugador sea dueño del objeto, que tenga los créditos, que tenga la herramienta en la mano, que esté lo bastante cerca del aviso de interacción, etcétera). El servidor responde con instantáneas (snapshots) y con el estado de cada jugador. La animación que solo muestra el estado (los cubos, las brocas, el robot y el ventilador de la línea de hielo) corre en cada cliente.

#### Reglas puras y comprobables

Las reglas de juego más importantes viven en módulos puros de Luau sin instancias de Roblox, por lo que se ejecutan sin cambios en Roblox y en Lune:

- `Simulation.luau`: el día de misión (inicio del día, planeación, resultado del turno, fin del día) y los medidores en vivo durante un turno.
- `BaseBuild.luau`: créditos, experiencia, nivel del jugador, costos y requisitos de construcción, habilidades, mascotas, equipo, taladros, el silo y el pago de la línea de hielo.
- `Missions.luau` y `Quests.luau`: la lista de misiones y la línea de aventuras, como datos más pequeñas funciones auxiliares.
- `ServerGuard.luau`: las reglas de seguridad del servidor (distancia a los avisos y repeticiones, recorrido del hielo y ritmo de perforación, el candado de sesión, revisión de la configuración).
- `Worlds.luau`: quién puede entrar a un mundo y de quién es la base que muestra.
- `Achievements.luau`, `Quiz.luau` y `Glossary.luau`: logros de aprendizaje, las preguntas de C.A.R.L. y el glosario con imágenes.
- `IceLineView.luau`: lo que muestran los letreros, los avisos "+N" y C.A.R.L. sobre la línea de hielo.
- `Daily.luau`: el calendario de la cápsula de suministros y los registros de la Bitácora lunar.
- `Reading.luau`: los tiempos de lectura y la cola de mensajes.
- `Feel.luau` y `WorldSafety.luau`: detección de celebraciones, fichas del reporte, sacudida de cámara, las salidas del cráter y el borde del mapa.
- `CinematicShots.luau` y `AudioIds.luau`: las tomas de cámara del menú de inicio y la lista de 50 sonidos, como datos.
- `Localization.luau` y `PetModels.luau`: textos y formas de las mascotas como datos simples.

#### Una sola fuente de números

Cada número que usa el juego vive en `src/shared/MissionData.luau`, agrupado en tablas como `REAL`, `WORLD`, `MISSION`, `POWER`, `METERS`, `WATER`, `SCIENCE`, `SUIT`, `STORM`, `BASE`, `EVENTS`, `ACHIEVEMENTS`, `GUARD`, `QUESTS`, `TYCOON_CLIENT`, `DAILY` y `LOGBOOK`. Cada valor está etiquetado como **REAL** (con la sección de `DATA_SOURCES.md` de la que proviene) o **GAME** (un valor de ajuste elegido para que el juego sea jugable). Dos ejemplos: la gravedad superficial de la Luna de 1.62 m/s² es REAL; el turno de 150 segundos es GAME. La gravedad predeterminada de Roblox de 196.2 studs/s² representa a la Tierra, así que la Luna usa 32.4 studs/s², lo que conserva la proporción real entre la Luna y la Tierra (GAME, derivado). Los tiempos técnicos de la interfaz (cuánto dura una frase en pantalla) no son números de juego y viven en `Reading.luau`.

#### Texto e idiomas

Todo el texto que ve el jugador viaja como claves de localización y se traduce en el cliente mediante `Localization.luau`. El inglés es el idioma predeterminado y el español de México es el segundo idioma. Los textos de juego tienen como máximo 8 palabras, con palabras que entiende un niño de 7 años. Algunos tipos de texto más largos tienen sus propios límites, todos verificados por las pruebas: las líneas de la pantalla de Fuentes (`fact.`, `src.`) hasta 10 palabras, y las tarjetas, los textos de misión, los textos de historia, los datos curiosos y los datos de exploración hasta 16.

#### Identidad visual "Lunar Sunrise"

`Theme.luau` contiene la paleta (azul noche, cian, naranja, verde lima, magenta, crema, más rojo y dorado derivados) y los roles semánticos (`Theme.ROLE`, por ejemplo `accent`, `warning`, `danger`, `good`, `reward`). El código usa roles, no colores directos, para la interfaz, las luces y los acentos de la base, y el confeti, las franjas del traje y las lámparas de la línea de hielo usan la misma paleta. `Theme.FONT` define dos fuentes: Fredoka One para títulos y botones, y Gotham Bold para el texto principal. Los únicos recursos de imagen son 68 íconos blancos de Tabler (licencia MIT), listados en `Icons.luau` y teñidos dentro del juego con colores de Theme, además del mapa de la Tierra Blue Marble de la NASA, de dominio público, y una cara del cielo casi negra hecha por el equipo. No hay emojis en ninguna parte de la interfaz.

#### Datos de clima espacial

Al iniciar el servidor, `SpaceWeatherService` consulta a NASA / CCMC DONKI las llamaradas solares (FLR) y los eventos de partículas solares energéticas (SEP) de los últimos 30 días, con un margen de 15 segundos para ambas solicitudes. Una llamarada "tiene partículas" solo cuando DONKI la vincula con un evento de partículas medido por los satélites GOES. Solo las llamaradas obtenidas en la consulta exitosa de este mismo servidor se etiquetan como "en vivo". Todo lo demás proviene de `SpaceWeatherArchive.luau` (llamaradas reales de clase X descargadas de DONKI) y se etiqueta como "archivo". Las tormentas siempre son repeticiones planteadas como "¿y si una tormenta como esta llegara a tu base?", nunca como un evento que haya golpeado la Luna. Una llamarada reciente en vivo sin un evento de partículas vinculado solo se usa como "falsa alarma" cuando tiene al menos dos días de antigüedad, porque los vínculos con partículas pueden llegar después.

### 4.5 Referencia de módulos

#### Módulos compartidos (`src/shared`)

| Módulo | Función |
| :--- | :--- |
| `Achievements` | Los 13 logros de aprendizaje: identificadores, íconos, textos, reglas de desbloqueo, registros guardados |
| `AudioIds` | Los 50 sonidos: recurso, grupo (Música o Efectos), bucle, volumen, duración, tiempo de espera, si es un sonido del mundo |
| `BaseBuild` | Reglas puras de construir y crecer: créditos, XP, niveles, costos, requisitos del hábitat, habilidades, mascotas, equipo, taladros, tamaño del silo, pago de la línea de hielo |
| `CinematicShots` | Las ocho tomas de cámara del menú de inicio, como datos y matemáticas |
| `Daily` | Calendario de la cápsula de suministros, datos de la carga, franjas del traje y registros e hitos de la Bitácora lunar |
| `Feel` | Detección de celebraciones, las fichas de causa y efecto del reporte, disminución de la sacudida de cámara |
| `Glossary` | Las nueve palabras del glosario con imágenes, con sus íconos y formas |
| `IceLineView` | Lo que muestra la línea de hielo: textos de los letreros, luces de estado, avisos "+N", cuándo C.A.R.L. señala el silo |
| `Icons` | ID de recurso de los íconos de Tabler y del mapa de la Tierra |
| `Localization` | Cada texto que ve el jugador, en inglés y en español, consultado por clave |
| `MissionData` | Cada número del juego, etiquetado como REAL o GAME |
| `Missions` | Misiones de entrenamiento, tres capítulos de historia y juego libre, como datos |
| `PetModels` | Datos de piezas de las cuatro mascotas, basados en los diseños de un integrante del equipo |
| `Quests` | Aventuras principales y extra como datos, con funciones auxiliares puras, migración de partidas guardadas y pistas de tesoros |
| `Quiz` | El banco de preguntas de C.A.R.L. (una sola respuesta correcta cada una) y las reglas del registro de respuestas |
| `Reading` | Cuánto dura una frase en pantalla y cuál frase en espera se salta primero |
| `ServerGuard` | Revisiones puras del servidor: distancia a los avisos, límites del hielo, el candado de sesión, límites de la configuración, velocidades de los mensajes |
| `Simulation` | Reglas puras de la misión para un día y los medidores en vivo |
| `SpaceWeatherArchive` | Llamaradas reales de clase X guardadas de DONKI |
| `Theme` | Paleta, roles y fuentes de "Lunar Sunrise" |
| `Types` | Contrato de red: instantáneas, tipos de estado, acciones, nombres de los remotos |
| `Version` | Identificador de compilación, usado para confirmar que la sincronización de Rojo llegó a Studio |
| `Worlds` | Mundos privados: papeles de los servidores, quién puede entrar, de quién es la base que muestra un mundo |
| `WorldSafety` | Las rampas de salida del cráter y sus distancias libres, las paredes del borde del mapa |

#### Módulos del servidor (`src/server`)

| Módulo | Función |
| :--- | :--- |
| `Main.server` | Punto de entrada: construye el mundo, crea los remotos, inicia los servicios y hace aparecer a los jugadores después de cargar una ranura de guardado |
| `AchievementService` | Desbloquea logros de aprendizaje a partir de eventos reales, los guarda en la partida y entrega insignias de Roblox |
| `BaseService` | Construir y hacer crecer la base por pasos: plataformas de construcción, cajas de piezas, créditos, XP, habilidades, compras en el Laboratorio, la línea de hielo (silo, planta de agua, viajes del robot de carga, hielo mientras no estás) |
| `Codes` | Códigos canjeables para cosméticos de eventos; solo en el servidor, para que los jugadores no puedan leerlos |
| `CrewService` | Oxígeno del traje por jugador, zonas presurizadas, hielo transportado, rescate al cuarto presurizado más cercano |
| `DailyService` | La cápsula de suministros diaria, los hitos de la Bitácora lunar y las franjas del traje |
| `ExploreService` | Escaneos de sitios de exploración con la tableta e impactos aleatorios de meteoritos |
| `MissionService` | El ciclo de la misión: fases, reparto de energía, tareas del turno, tormentas, despacho de acciones |
| `PetService` | Construye la mascota equipada y la mueve detrás de su astronauta |
| `ProgressService` | Partidas guardadas: tres ranuras por jugador, registro meta, candado de sesión, configuración, migraciones, guardado automático, "Guardar ahora", viajes a mundos privados |
| `QuestService` | Da seguimiento a las aventuras principales y extra a partir de eventos reales, paga cada recompensa una sola vez, hace las preguntas de C.A.R.L. y da pistas de tesoros y avisos de descanso |
| `SpaceWeatherService` | Consulta en vivo a DONKI con el archivo como respaldo, y elección de llamaradas para las tormentas |
| `SuitService` | Casco de EVA y mochila de soporte vital soldados sobre el avatar del propio jugador, más los modelos del equipo |
| `ToolModels` | Modelos de piezas de las herramientas: llave, taladro de hielo, cepillo, kit de reparación, tableta, charola de ensalada |
| `ToolService` | Entrega las herramientas desbloqueadas, verifica que una herramienta esté en la mano y gestiona comer alimentos del invernadero |
| `VehicleModels` | Modelos de piezas y estructuras físicas del carrito lunar y del camión de hielo |
| `VehicleService` | Bahías del garaje, tomar y devolver vehículos, recuperación tras volcadura, el hielo del camión de hielo |
| `WorldBuilder` | Construye la base del polo sur y su maquinaria de construcción; usa los módulos World* de abajo |
| `WorldParts` | Anclas de distribución, paleta, estado compartido de construcción y funciones auxiliares de piezas |
| `WorldSecrets` | Lugares ocultos, los cuatro coleccionables, la bandera del equipo y el observatorio sellado |
| `WorldSites` | Modelos del Laboratorio, el garaje, la plataforma de aterrizaje y la nave, cinco sitios de exploración, cráteres de meteoritos |
| `WorldSky` | Gravedad lunar, iluminación, cielo negro, la Tierra, Marte, estrellas, la trayectoria del Sol sobre el horizonte y los eclipses |
| `WorldStructures` | Taladros de hielo, bandas, silo, planta de agua, robot de carga, plataformas de construcción y hologramas, la nave de llegada, pasos de construcción, cajas |

#### Módulos del cliente (`src/client`)

| Módulo | Función |
| :--- | :--- |
| `Main.client` | Punto de entrada: construye la interfaz, escucha al servidor y muestra la pantalla correcta |
| `AchievementsPanel` | El panel de Logros: páginas de mosaicos grandes con datos, pistas y avance |
| `Audio` | Todos los sonidos: efectos sueltos reutilizables, bucles que se desvanecen, zumbidos en 3D, música según el estado del juego, la regla del casco |
| `BasePanel` | Panel del Laboratorio: habilidades, equipo, mejoras de herramientas y mascotas; solo se abre en el Laboratorio |
| `CameraFx` | La sacudida por meteoritos a través del suelo y el pulso naranja en los bordes durante las tormentas |
| `CarlDrone` | C.A.R.L., el rover ayudante con orugas, con su haz de guía (que las paredes bloquean) y su haz hacia el refugio |
| `Celebrate` | Confeti, destellos, títulos de nivel y destellos en las plataformas |
| `Cinematic` | Reproduce las tomas de cámara del menú de inicio y el ajuste de color cinematográfico |
| `Collection` | La Bitácora lunar (secretos, lugares, rocas espaciales, logros, datos, franjas) y la tarjeta de hallazgo de mito contra ciencia |
| `DailyCapsule` | La llegada de la cápsula junto a la nave y la tarjeta del calendario de 7 días |
| `DemoKeys` | Atajos con teclas F para pruebas y grabación, solo en Roblox Studio |
| `ExploreCard` | Tarjeta que se muestra después de escanear un sitio o un cráter de meteorito |
| `FunFacts` | Los datos curiosos breves y verdaderos de C.A.R.L., tomados de una bolsa mezclada sin repeticiones |
| `Gear` | Botas de aire (doble salto) y mochila propulsora, sus teclas, botones táctiles y tanque de gas |
| `GlossaryCard` | La tarjeta con imagen "¿Qué significa?" de las palabras doradas |
| `Hud` | HUD del turno, panel de signos vitales siempre visible, cartera con la etiqueta de las máquinas, hielo transportado y etiquetas (pills) |
| `IncomePops` | Avisos "+N créditos" en el silo y en el puerto de suministros, y la tarjeta "Mientras no estabas" |
| `MapEdge` | La franja naranja del borde del mapa y el aviso de C.A.R.L. |
| `Markers` | Marcadores flotantes de tareas, que solo se muestran cuando importan |
| `Messages` | Globo de diálogo de C.A.R.L.: tiempos de lectura, frases juntadas y saltadas, insignias de herramientas, el historial |
| `Meters` | Barras de aire, comida, radiación y agua en distribuciones de fila y de columna |
| `MissionSelect` | La consola de misiones del hábitat: tarjetas de entrenamiento, historia y juego libre, y el botón Bitácora |
| `Movement` | Tiempos más cortos para mantener presionados los avisos, según el nivel del taladro y la habilidad de constructor |
| `Objectives` | Lista de verificación de los objetivos de la misión y el seguimiento de aventuras con barras de avance |
| `Onboarding` | Consejos guiados y resaltados del tablero de energía que nunca bloquean el juego |
| `PowerBoard` | Capa de planeación donde la tripulación reparte las celdas de energía entre los sistemas |
| `ProductionLine` | Anima la línea de hielo (cubos, brocas, robot, ventilador, burbujas) y sus letreros en el mundo |
| `Prompts` | Localiza los avisos y letreros del mundo a partir de sus atributos de clave |
| `QuestToasts` | Tarjetas de "¡Nueva aventura!", "Listo", "¡Aventura completa!" y la tarjeta dorada grande de aventura principal |
| `QuizCard` | La tarjeta con imagen de la pregunta de C.A.R.L. y su resultado |
| `Report` | Reporte de fin de misión con estrellas y una línea de tiempo día por día de causa y efecto |
| `Rewards` | Recompensas de coleccionables del lado del cliente, como abrir la puerta del observatorio |
| `SaveIndicator` | La etiqueta "Juego guardado" después de cada guardado |
| `Settings` | Página Juego (idioma, volumen, opciones de C.A.R.L., código canjeable, "Guardar ahora") y página Ayudas |
| `Sources` | Panel "Datos reales de la NASA": estado en vivo o de archivo, datos reales, créditos de las fuentes |
| `Sprint` | Interruptor para correr, bonificaciones de velocidad y carrera automática |
| `StartMenu` | Primera pantalla: Continuar con su tarjeta, Juego nuevo o Mis mundos, Unirse a un amigo, Configuración, Créditos; la lista de mundos, Continuar o Empezar de nuevo, Solo yo o Con amigos, la pantalla de espera |
| `Store` | Estado del cliente: última instantánea, progreso, estado de la base, ranuras, idioma, configuración y ayudas |
| `Ui` | Bloques compartidos de la interfaz: raíz escalada con márgenes seguros, paneles, etiquetas con tamaño mínimo de texto, botones con sonido, barras, íconos teñidos |
| `VehicleClient` | Controles de manejo, cámara de persecución y el panel del vehículo |
| `Wardrobe` | Elegir casco, mochila, apariencia de C.A.R.L. y mascota |

### 4.6 Remotos y acciones

El servidor crea sus RemoteEvents en `ReplicatedStorage.Remotes`. Sus nombres se definen una sola vez en `Types.Remotes`.

| Remoto | Dirección | Transporta |
| :--- | :--- | :--- |
| `Action` | del cliente al servidor | `Types.Action`, la única forma en que un cliente pide cualquier cosa |
| `Snapshot` | del servidor a todos | El estado completo de la misión, enviado con cada cambio (como máximo uno cada 0.1 s después de las acciones) y a quienes se unen tarde |
| `PlayerStats` | del servidor a uno | Los valores del traje y del terreno de ese jugador |
| `AssistantMessage` | del servidor al cliente | Una frase de C.A.R.L. como clave de localización con parámetros |
| `Progress` | del servidor a uno | Misiones completadas, coleccionables, cosméticos |
| `Collected` | del servidor a uno | La recolección de un coleccionable, justo después de que ocurre |
| `BaseState` | del servidor a uno | Créditos, XP, construcciones, habilidades, herramientas, equipo, mascotas, seguimiento de aventuras, la pregunta pendiente, ingresos de las máquinas |
| `Explore` | del servidor a uno | El resultado del escaneo de un sitio o de un meteorito |
| `Slots` | del servidor a uno | Las tres ranuras de guardado para el menú de inicio, con la configuración guardada |
| `Saved` | del servidor a uno | Un aviso después de cada guardado de la ranura de ese jugador |
| `Worlds` | del servidor a uno | La lista de "Unirse a un amigo" |
| `Achievements` | del servidor a uno | Los logros y contadores de ese jugador |
| `IceLine` | del servidor a uno | Una entrega o recolección (créditos, producto, posición) para los avisos "+N", y el aviso de "mientras no estabas" |
| `Daily` | del servidor a uno | El calendario de la cápsula, la Bitácora y las franjas |

Las acciones se dividen en grupos:

- **Misión:** `SetCells`, `StartMission`, `StartShift`, `Restart`.
- **Configuración del jugador:** `SetLanguage`, `SaveSettings`, `RedeemCode`.
- **Partidas guardadas y mundos:** `ChooseSlot`, `RequestSlots`, `ListFriendWorlds`, `JoinWorld`, `SaveNow` (gestionadas por `ProgressService`).
- **Base:** `Build`, `LearnSkill`, `Equip`, `BuyPet`, `ClaimSilo`, `UpgradeTool`, `BuyGear`, `ToggleGear` (validadas por `BaseService`).
- **Aprendizaje:** `OpenSources`, `AnswerQuiz`.
- **Cápsula diaria y Bitácora:** `ClaimDaily`, `RequestDaily`, `ClaimLogbook`, `WearStripes`, `HeardFact` (validadas por `DailyService`).
- **Depuración:** `DebugMeteor`, `DebugBuildNext`, `DebugForceEvent`, `DebugEndShift`, `DebugEclipse` y otras. Desde la etapa 11 solo se aceptan en Roblox Studio, nunca en un servidor en vivo, y se usan para probar y grabar.

`MissionService` limita a cada jugador a 20 acciones por segundo, y el vestíbulo público no acepta ninguna acción de juego. Las acciones de ranuras y de guardado tienen sus propios límites en `ProgressService` (una solicitud de la lista de ranuras y una solicitud de "Guardar ahora" por segundo), un código canjeable puede intentarse una vez cada 2 segundos, una respuesta a la pregunta de C.A.R.L. una vez por segundo, y la pantalla de Fuentes cuenta una vez cada 5 segundos.

### 4.7 El sistema de guardado

`ProgressService` guarda el progreso de cada jugador en un DataStore de Roblox llamado `SBO_Progress_v1`.

- **Tres ranuras.** Cada jugador tiene tres ranuras de guardado ("mundos"), con la clave `p_<userId>_s<slot>`. Una ranura contiene las misiones completadas, los coleccionables, los cosméticos y el registro de la base: créditos, XP, construcciones, habilidades, herramientas, equipo, mascotas, lo que viste el jugador, los sitios escaneados, el progreso de las aventuras y las respuestas a las preguntas, los logros, el calendario de la cápsula diaria y las franjas, y el silo (`base.silo = { ice, at }`).
- **Registro meta.** `p_<userId>_meta` resume las ranuras para el menú de inicio (usada o vacía, nivel de base, nivel del jugador, créditos, hora del último guardado, solo o con amigos), recuerda la última ranura y guarda la configuración del jugador. Los cosméticos de eventos aplican a toda la cuenta y viven aquí.
- **Mundos privados.** Cada mundo es la ranura de su dueño y corre en su propio servidor reservado, en los dos modos. Continuar, Juego nuevo, Solo yo o Con amigos reservan un servidor y teletransportan ahí al jugador; si el viaje falla, el jugador vuelve al menú con un mensaje. Un mapa de MemoryStore ("SBO_Worlds") lista los mundos con amigos abiertos (código de acceso, jugadores, nivel de base), se actualiza cada 30 segundos y desaparece a los 120. El vestíbulo y el servidor del mundo revisan los dos la amistad, que el mundo esté abierto y que tenga lugar.
- **Candado de sesión.** Una ranura solo se carga después de que el servidor escribe en ella un candado (servidor, visita, hora). Un candado reciente de otro servidor hace que la carga espere hasta 20 segundos el último guardado de ese servidor y luego lo reemplaza; un candado de más de 3 minutos ya no cuenta. Cada guardado revisa y renueva el candado, y el último guardado al salir lo libera. Un servidor que perdió el candado ya no vuelve a escribir. Esto cierra el truco de cambiar de servidor para gastar créditos en un mundo y conservarlos en otro.
- **Continuar nunca borra.** Solo un Empezar de nuevo explícito (Juego nuevo en un mundo usado) reemplaza una ranura.
- **La configuración acompaña al jugador.** El idioma, los volúmenes, los datos curiosos, la guía y las cuatro ayudas se guardan con la acción `SaveSettings`, que el servidor revisa y acota, y regresan en la lista de ranuras, en los TeleportData del viaje y como atributos del jugador. El cliente envía un cambio 0.6 segundos después del último, así que arrastrar un control solo envía una vez.
- **Partidas guardadas antiguas.** La partida guardada de antes de las ranuras (`u_<userId>`) nunca se borra y se convierte en la ranura 1. Las partidas guardadas de etapas anteriores se migran al cargarse, para que nadie pierda su base; el registro de aventuras tiene una versión (`v = 2`), así que las partidas de antes de la etapa 11 se saltan la nueva primera aventura.
- **Sin personaje hasta que se carga una ranura.** El jugador aparece solo después de elegir una ranura, así que no se guarda nada de un jugador que todavía no ha elegido una.
- **Guardado automático.** Una ranura modificada se guarda como máximo una vez cada 10 segundos, y los jugadores inactivos se vuelven a guardar en silencio más o menos cada minuto para mantener vigente el candado. El registro meta se guarda como máximo cada 60 segundos. El silo se escribe como máximo cada 30 segundos mientras cambia, y después de cada pago.
- **Fusión.** Un guardado solo agrega a lo que ya está almacenado, así que el progreso nunca se pierde. Empezar de nuevo y el reinicio de depuración son las únicas escrituras que reemplazan.
- **Al salir.** Un jugador que sale cuenta de inmediato como un guardado en curso, y `BindToClose` lo espera (hasta 25 segundos en un servidor en vivo). Primero se le devuelven a su partida los créditos de las obras que pagó y no terminó, porque un servidor de mundo se cierra cuando su dueño se va.
- **"Guardar ahora".** El botón de Configuración envía `SaveNow`. El servidor escribe en cuanto el DataStore permite una escritura por clave (aproximadamente cada 6 segundos) y lo confirma por el remoto `Saved`. El cliente muestra "Juego guardado"; los avisos del guardado automático se muestran como máximo una vez cada 30 segundos.
- **Comportamiento en Studio.** Si el lugar está publicado, Studio usa un almacén separado, `SBO_Progress_v1_Studio`, para que los créditos de depuración nunca lleguen a las partidas guardadas reales. Una sola lectura de prueba lo decide; si los DataStores no responden en 8 segundos, se usa la memoria. En un lugar no publicado, las partidas guardadas viven en memoria y se pierden cuando se detiene Play, y la etiqueta dice "Guardado solo para esta prueba". Un atributo del workspace, `SBO_StudioDataStores`, puede forzar la memoria (`false`) o el almacén real (`true`). En Studio no existen los servidores reservados, así que ahí el primer jugador cuya ranura se carga es el dueño del mundo y los demás son invitados.
- **Límites en los valores almacenados.** Los créditos y la XP leídos del almacenamiento se acotan, para que un registro dañado no pueda romper el juego.

### 4.8 El mundo construido por código

`WorldBuilder.build` crea toda la base del polo sur a partir de Parts simples cuando se inicia el servidor: los elementos del terreno, el cráter con hielo y tres rampas de salida, la cresta solar, la nave de llegada, las plataformas de construcción con hologramas, la línea de hielo (bandas elevadoras, la tolva del borde, la banda abierta, el silo, la planta de agua y el puerto de suministros), las zonas presurizadas, los sitios de exploración, los secretos y paredes invisibles 12 studs antes del borde del terreno. Nada se coloca a mano en Studio.

Roblox se niega a asignar el código fuente de un script cuando tiene más de 200,000 caracteres. Durante la Etapa 7, el constructor del mundo creció a unos 238,000 caracteres, y la sincronización en vivo de Rojo dejó de funcionar para él. Se dividió en módulos hermanos:

| Módulo | Parte del mundo |
| :--- | :--- |
| `WorldParts` | Anclas de distribución, paleta y funciones auxiliares de piezas compartidas por los demás |
| `WorldSky` | Entorno: gravedad, iluminación, cielo, la Tierra, trayectoria del Sol, eclipses |
| `WorldStructures` | Estructuras de construir y crecer, la línea de hielo, la nave de llegada y los pasos de construcción |
| `WorldSecrets` | Lugares ocultos y coleccionables |
| `WorldSites` | Laboratorio, garaje, plataforma de aterrizaje, nave, sitios de exploración, meteoritos |

`WorldBuilder.luau` ahora tiene unos 149,000 caracteres, y el archivo más grande, `Localization.luau`, tiene unos 155,000. Ambos están por debajo del límite.

Algunos detalles del mundo siguen reglas científicas. El Sol sigue una trayectoria precalculada a lo largo del horizonte, como en el polo sur lunar real, porque el modelo de Sol propio de Roblox no gira alrededor del polo. El cielo se mantiene negro porque la Luna no tiene atmósfera. Los meteoritos caen con un destello y polvo, pero sin estela de fuego. El refugio es un montículo cubierto de regolito, porque lo que protege de la radiación es la masa, no la energía. Las rampas del cráter las coloca `WorldSafety.exitAngles` lejos de los taladros, sus bandas, el nicho del queso, los nodos de hielo y las lámparas, y `tests/feel` revisa las 36 distribuciones posibles del cráter.

### 4.9 Proceso de audio

- **Hecho por el equipo.** La música y la mayoría de los efectos los sintetizó el código propio del equipo (scripts de Python en `promo/audio/synth`, excluido por git, escritos con ayuda de IA; ningún modelo generativo de audio). Cinco efectos mezclan grabaciones CC0 editadas de Freesound, encontradas con Openverse (sección 6.2). Ningún sonido es CC BY, y no se usa audio de la Toolbox ni del Marketplace.
- **Subidos y listados.** El equipo subió los 50 sonidos como audio de Roblox. Sus IDs de recurso, grupos, volúmenes, duraciones y tiempos de espera están en `src/shared/AudioIds.luau`; los archivos fuente y las revisiones de volumen están en `promo/audio/manifest.json`, excluido por git.
- **Un solo módulo reproduce todo.** `src/client/Audio.luau` maneja todos los sonidos: efectos sueltos reutilizables con un pequeño cambio de tono, bucles que se desvanecen, sonidos 3D que solo se oyen de cerca (los taladros, la banda y el silo zumban a unos 75 studs) y remates que bajan la música. Reutiliza los grupos de sonido `SBO_Music` y `SBO_SFX` de `Settings.luau`, así que los dos controles de volumen controlan todo. Cada llamada corre dentro de `pcall`, y nada suena antes de elegir una ranura.
- **La regla del casco en el código.** Los sonidos del mundo pasan por un subgrupo del grupo de efectos. Mientras el atributo del jugador `SBO_Inside` no sea verdadero, un ecualizador apaga ese grupo (medios -7 dB, agudos -22 dB) y su volumen baja. Los sonidos del radio, la tableta y C.A.R.L. no pasan por él. Los sonidos predeterminados de los personajes de Roblox están silenciados en todos los personajes.
- **Música según el estado.** Cada cuarto de segundo el módulo elige una pista: menú, tormenta, misión, eclipse, construcción o base de día, con transiciones de 2.5 segundos; una pista pausada continúa donde se quedó.
- **Ganchos.** Cada gancho de sonido en otro módulo es una línea corta marcada "Stage 11 audio" (botones y paneles en `Ui.luau`, la cartera, los avisos de aventuras, C.A.R.L., el equipo y el carrito); lo demás lo maneja el estado del juego dentro de `Audio.start`.

### 4.10 Pruebas

Los once conjuntos de pruebas de Lune son puros: cargan directamente los módulos compartidos y no necesitan Roblox. Resultados actuales (16 de noviembre de 2026, todos aprueban, 0 fallas):

| Conjunto | Comando | Verificaciones | Qué demuestra |
| :--- | :--- | :--- | :--- |
| Localización | `lune run tests/localization` | 51496 | Cada clave existe en inglés y en español con los mismos marcadores de posición; límites de palabras; sin emojis ni símbolos fuera del texto latino; sin jerga técnica en los textos de juego; los datos curiosos no se repiten y solo usan números que aparecen en `DATA_SOURCES.md`; los pasos que se cuentan no llevan `{n}`; los textos de preguntas y del glosario no citan números; los archivos de código fuente solo usan claves conocidas |
| Base | `lune run tests/base` | 2201 | Datos de construcción; la XP y los 15 niveles del jugador; costos, requisitos y requisitos del hábitat; habilidades, mascotas, taladros, pasos, herramientas, equipo, migración de partidas guardadas, el árbol del hábitat y las aventuras; la primera aventura, las felicitaciones y las pistas de tesoros; la línea de hielo (planta, energía, estados, pago de entregas, carga del robot, hielo mientras no estás, guardado del silo) y lo que muestran sus letreros |
| Misiones | `lune run tests/missions` | 729 | Los identificadores, calendarios y objetivos de las misiones son válidos; una tripulación cuidadosa puede terminar cada capítulo de la historia; un día de entrenamiento nunca vacía un medidor; las construcciones necesarias existen y pueden pagarse; los límites del hielo contra cada velocidad permitida, el ritmo de perforación, los pagos del camión de hielo y el polvo del mundo abierto |
| Balance | `lune run tests/balance` | 716 | "Ninguna decisión es gratis": un jugador pasivo aun así llega al día 5; ningún plan fijo obtiene 3 estrellas; reaccionar a los eventos puede dar 3 estrellas; recortar el invernadero se nota después como menos comida; la dosis de tormenta se cuenta por segundo, sube en vivo y nunca baja; las falsas alarmas no suman nada |
| Economía | `lune run tests/economy` | 234 | Un jugador infantil simulado alcanza cada nivel de base dentro de las metas de ritmo; los ingresos nunca aumentan más de 2.5 veces entre ventanas de 10 minutos; desde el robot de carga hasta la nave, las máquinas ganan del 30 al 50% de lo que gana jugar; recuperación de la inversión en taladros; límite del hielo mientras no estás |
| Cinemática | `lune run tests/cinematic` | 189 | Las tomas de cámara del menú de inicio: claves, curvas, tiempos y encuadre |
| Mundos | `lune run tests/worlds` | 116 | Papeles de los servidores, revisión de TeleportData, solo entran amigos y nunca más de 4, el modo solo sigue privado, la base es del dueño, el candado de sesión (cambio de servidor, robo, candado viejo, liberación), configuración y ayudas guardadas |
| Logros | `lune run tests/achievements` | 758 | Identificadores, íconos, textos en en y es, reglas de desbloqueo, partidas viejas y fusiones; todo el banco de preguntas (una sola respuesta correcta, respuestas científicas, reglas del registro) y el glosario |
| Cápsula diaria | `lune run tests/daily` | 222 | Una cápsula por día UTC, el calendario fijo, el conteo comprensivo, una semana no paga más que tres escaneos de cráteres, franjas, registros e hitos de la Bitácora, datos de la carga sin números |
| Sensaciones | `lune run tests/feel` | 323 | Detección de celebraciones, fichas del reporte (la dosis solo sube), disminución de la sacudida, el borde del mapa y las 36 distribuciones del cráter: dos salidas extra en cada una, todas las distancias libres, una rampa a menos de 90 studs de cualquier punto del fondo |
| Lectura | `lune run tests/reading` | 102 | Tiempos de lectura, el mínimo y el máximo, los factores de Tiempo de mensajes, frases repetidas que se juntan y cuál frase en espera se salta primero |

Además de los conjuntos de pruebas de Lune, el asistente de IA jugó cada etapa en Studio usando pulsaciones de teclas y acciones remotas reales, revisando la consola en busca de errores de script. La etapa 11 pasó una prueba rápida en Studio: el menú de inicio sin Cargar juego, la lista de mundos, la aparición en la nave, el seguimiento de aventuras, la tarjeta de la cápsula diaria, la línea de hielo y ningún error en la consola. Estas pruebas de juego se listan en `DEVELOPMENT.md`. Todavía faltan pruebas de juego con personas ajenas al equipo.

### 4.11 Notas de rendimiento y seguridad

- **Actualizaciones de red pequeñas.** Durante un turno, la instantánea con los medidores en vivo se envía como máximo unas cuatro veces por segundo, y las instantáneas después de las acciones se agrupan en una cada 0.1 segundos. El servidor ya no mueve nada en la línea de hielo: publica el estado de la línea como atributos, y cada cliente anima localmente los cubos, las brocas, el robot y el ventilador, y se detiene cuando la cámara está lejos. Antes, el servidor enviaba las posiciones de los taladros, los cubos y el robot de 15 a 20 veces por segundo a cada jugador. Las mascotas solo mueven su pieza raíz unas 20 veces por segundo y giran sus articulaciones con `Motor6D`.
- **Efectos visuales económicos.** La carcasa del casco se crea una sola vez con CSG al iniciar el servidor, se guarda en caché y se clona para cada personaje (si CSG falla, se usan esferas simples). Las mascotas nunca colisionan, no bloquean rayos ni proyectan sombras. La Tierra es un disco giratorio de bajo costo. Los marcadores de tareas solo se muestran cuando importan. El haz de C.A.R.L. revisa su camino con un rayo cuatro veces por segundo.
- **Aislamiento de fallas.** Cada servicio posterior al núcleo se inicia dentro de `pcall`, así que una pieza averiada se reporta con una advertencia y nunca detiene el servidor.
- **Clientes no confiables (`ServerGuard`).** Cada acción se verifica en el servidor. Los avisos de tareas (paneles, hielo del cráter, la máquina de agua, la fuga, la antena, la consola, la comida del invernadero) revisan que el jugador esté junto al aviso e ignoran repeticiones más rápidas que 0.25 segundos. La perforación se limita a 15 núcleos por minuto por jugador, uno por segundo como máximo, y un núcleo solo se acepta en la máquina de agua cuando de verdad pudo haber viajado hasta ahí a 50 studs por segundo. Cada núcleo del camión de hielo le paga al jugador que lo cargó. Un cráter de meteorito recuerda por cuenta quién lo escaneó. Las acciones de misión necesitan una partida cargada, y el vestíbulo no acepta ninguna.
- **Las acciones de depuración son solo de Studio.** Las teclas F del equipo (`DemoKeys`) y cada acción de depuración solo funcionan en Roblox Studio. El juego en vivo las rechaza, incluso para el dueño del lugar.
- **Los códigos canjeables** viven solo en el servidor.
- **Datos honestos.** La etiqueta de en vivo aparece solo cuando la consulta a DONKI de este servidor tuvo éxito. De lo contrario se usa el archivo y se etiqueta como tal.
- **Movimiento controlado por el cliente.** Roblox le da al cliente el control de su propio personaje. Por eso, el doble salto, el empuje de la mochila propulsora, la velocidad de carrera y los tiempos más cortos para mantener presionados los avisos se aplican en el cliente, con valores que el servidor establece como atributos del jugador. Las paredes del borde del mapa detienen al carrito y a la mochila propulsora en la orilla.

### 4.12 Accesibilidad

- **Dos idiomas.** Los botones EN y ES de la Configuración (a la que también se llega desde el menú de inicio) cambian entre inglés y español en cualquier momento. La elección se guarda, y los avisos y letreros del mundo se actualizan de inmediato.
- **Palabras sencillas.** Los textos de juego son breves (como máximo 8 palabras) y evitan la jerga, y las pruebas lo hacen cumplir. Un glosario con imágenes explica nueve palabras clave.
- **Página de Ayudas.** Texto grande (1.25 veces, al momento), Menos movimiento, mensajes más largos (1.5 o 2 veces) y un interruptor de Ayuda de colores. La Ayuda de colores se guarda y se envía al cliente; ninguna pantalla la usa todavía, porque las zonas de los medidores y los botones de encendido ya muestran formas.
- **Tiempo para leer.** Las frases de C.A.R.L. y los avisos de aventuras duran lo suficiente para un niño de 7 años (unos 8 segundos para 8 palabras), el reloj se pausa mientras está el menú de inicio, y el historial vuelve a mostrar las últimas 10 frases.
- **Íconos y palabras además del color.** Los medidores muestran un ícono, una etiqueta y un ícono de zona además del color de la barra; las luces de la línea de hielo siempre tienen palabras al lado; C.A.R.L. muestra el ícono de la herramienta que necesita una tarea.
- **Teléfonos.** En pantallas táctiles, ningún texto de la interfaz del juego mide menos de 11 píxeles reales, los dispositivos solo táctiles usan una distribución para 560 unidades de alto (cerca de 1.3 veces más grande), y la interfaz se aleja del notch y de las esquinas redondeadas (`ScreenInsets.DeviceSafeInsets`). Los botones para correr, avanzar solo y el equipo están cerca del botón de salto.
- **Interfaz escalada.** La interfaz está diseñada para una pantalla de 720 unidades de alto, y un `UIScale` la ajusta a la altura real de la pantalla, así que conserva sus proporciones en teléfonos y en pantallas grandes.
- **Control de videojuegos.** Cada cuadro pone la selección en su botón seguro y la regresa después.
- **Primera persona.** En primera persona, Roblox fija el mouse al centro de la pantalla. Un botón modal oculto lo libera cada vez que hay una tarjeta o un panel abierto.
- **Guía tranquila.** Los consejos nunca bloquean el juego, las celebraciones nunca bloquean un toque, y los datos curiosos y el haz de guía de C.A.R.L. pueden desactivarse en Configuración.

### 4.13 Limitaciones técnicas conocidas

- **Restricción de edad.** Las experiencias nuevas de Roblox solo están abiertas para cuentas con verificación de edad de 16 años o más, hasta que pasen la evaluación de Roblox. Los niños del rango de edad al que va dirigido el juego todavía no pueden jugar la versión pública.
- **Roblox necesita una cuenta y una instalación.** No es un juego de navegador sin inicio de sesión; por eso el video y el archivo de lugar de Studio son importantes para el jurado.
- **Teléfonos.** La distribución para teléfonos todavía no se ha revisado en un dispositivo real.
- **Una base por servidor.** La gravedad y la iluminación son globales en Roblox, así que cada servidor de mundo tiene una sola base: la de su dueño.
- **Los medidores usan unidades de juego.** El aire, la comida y la radiación van de 0 a 100 para que los niños puedan leerlos. Los valores reales se muestran aparte en el panel de Fuentes.
- **El retraso de la señal desde la Luna es corto.** Con 1.3 segundos, el retraso en sí no es un problema en la Luna, así que el juego convierte el enlace de la antena en la decisión y lo compara con Marte, donde serían de 3 a 22 minutos.
- **Sonido en el vacío.** En el espacio no hay sonido. Afuera, los sonidos del mundo son suaves y apagados, como sentidos a través del traje; los pitidos de radio se oyen claros. Dentro de los módulos los sonidos son normales. La música no es parte del mundo.
- **Los datos en vivo necesitan HTTP.** Sin "Allow HTTP Requests", o si DONKI no responde en 15 segundos, el juego usa el archivo. Una llamarada solo se repite como falsa alarma cuando su estado de partículas ha tenido dos días para asentarse.
- **Partidas guardadas y mundos en Studio.** En un lugar no publicado, las partidas guardadas viven en memoria y se pierden cuando se detiene Play. Los servidores reservados y la lista de "Unirse a un amigo" funcionan únicamente en el juego publicado.
- **Ritmo del DataStore.** Roblox permite aproximadamente una escritura por clave cada 6 segundos, así que un "Guardar ahora" puede tardar unos segundos.
- **Un mundo con amigos se cierra con su dueño.** Cuando el dueño se va, las partidas de los invitados se guardan y ellos vuelven al menú.
- **Efectos solo locales.** Algunas recompensas, como la puerta abierta del observatorio y la apariencia de Tierra de C.A.R.L., y la llegada de la cápsula diaria existen solo en el cliente de ese jugador.
- **Sin enlaces externos.** Roblox no permite enlaces que salgan de la experiencia, así que las fuentes se acreditan como texto (por ejemplo "NASA / CCMC DONKI").
- **Tamaño de los scripts.** El límite de 200,000 caracteres de Roblox para el código fuente de un script significa que los módulos grandes deben mantenerse divididos.

## 5. Registro de desarrollo

Cómo se construyó Space Base Odyssey durante NASA Space Apps 2026 (14–15 de noviembre, evento local de Querétaro), seguido de la publicación de la etapa 10 y de la actualización nocturna de la etapa 11 el 16 de noviembre. Registra qué se decidió, quién lo decidió, qué se probó y cómo se usó la IA. Las horas son locales (UTC−6).

### 5.1 Equipo y roles

Un equipo de cuatro personas:
- Un integrante trabaja en Roblox Studio con un asistente de programación con IA.
- Los otros tres se encargan de la ciencia y los datos, del diseño del juego y las pruebas de juego, y de la presentación y la entrega.
- El concepto, las decisiones de diseño, las pruebas de juego y las decisiones de balance corresponden al equipo.

### 5.2 Cronología

#### Sábado 14 de noviembre

**Hacia las 11:30 – Investigación antes de escribir código.** Se realizaron cinco tareas de investigación en paralelo:
- La página oficial del reto y las reglas de Space Apps: fechas límite, formato de la demostración, declaración del uso de IA, requisito de datos de la NASA y criterios de evaluación.
- Una verificación de 25 afirmaciones científicas del primer documento de diseño del equipo.
- Una revisión de 15 supuestos sobre el motor de Roblox contra la documentación vigente.
- Cómo se desarrollan los videojuegos en general y en Roblox Studio.
- Las funciones de Claude Code disponibles para dirigir varios agentes de IA.

**Hallazgo clave: el primer diseño no correspondía al reto.**
- El primer documento del equipo describía un simulador de vuelo: lanzamiento, acoplamiento y aterrizaje.
- El reto pide un juego en el que niñas y niños de 7 a 12 años **administren un puesto avanzado en la Luna o en Marte** y equilibren soporte vital, blindaje contra la radiación, energía, alimentos y retraso en las comunicaciones.
- Una auditoría del primer documento encontró:
  - 39 diferencias entre sus dos versiones.
  - 15 inconsistencias numéricas. Por ejemplo, la escala indicada (1 stud = 0.35 m) no coincidía con los valores de gravedad por un factor de 7.
  - 32 requisitos poco especificados.
  - 123 funciones distintas: demasiadas para un fin de semana.
- **Decisión del equipo:** cambiar el enfoque a la administración de un puesto avanzado.

**Planeación.**
- Se redactó un plan por etapas (primero una porción vertical jugable, después más contenido) y lo revisaron tres críticos independientes: ajuste al reto, viabilidad y diseño para niños.
- La crítica cambió el diseño:
  - Días por turnos en lugar de un reloj en tiempo real.
  - Tres sistemas en lugar de cinco.
  - El refugio contra la radiación es una decisión durante una tormenta, no un consumo de energía. Un refugio protege por su masa.
  - El retraso de las comunicaciones se percibe por medio de los avisos de la Tierra, que llegan tarde o con anticipación.
- **Decisiones del equipo:**
  - Nombre: *Space Base Odyssey*.
  - Escenario: el polo sur de la Luna, cerca del cráter Shackleton.
  - Mecánicas propuestas en las notas de diseño de un integrante del equipo: astronauta en tercera persona, oxígeno del traje en el exterior, correr hacia un refugio de regolito, paneles solares en la cresta iluminada, hielo en el cráter en sombra, invernadero y el ayudante "C.A.R.L.".
  - El equipo aceptó los valores predeterminados recomendados: 7 días de misión, tres medidores y estrellas por la ciencia.

**12:45 – Herramientas.**
- Rojo 7.7.1 sincroniza los archivos con Studio.
- Lune 0.11.1 ejecuta las pruebas fuera de Roblox.
- El servidor MCP de Roblox Studio permite que el asistente ejecute el juego y lea la consola.
- Se creó un repositorio público en GitHub.

**12:56 – Reglas centrales y datos.**
- `Simulation.luau`: reglas puras de la misión.
- `MissionData.luau`: cada número etiquetado como REAL o GAME.
- Un archivo de 11 llamaradas reales de clase X descargado de NASA DONKI.
- Pruebas de balance:
  - Un jugador pasivo aun así llega al día 5.
  - Ninguna asignación fija obtiene 3 estrellas.
  - Solo reaccionar a los eventos obtiene 3 estrellas.
  - Recortar el invernadero se refleja en menos comida al día siguiente.

**13:57 – Etapa 1: ciclo jugable.** Construido por cuatro agentes de IA en paralelo, con una revisión de integración:
- La base lunar construida con código.
- El tablero de energía, los turnos con oxígeno del traje, las tormentas con llamaradas reales y falsas alarmas honestas.
- La pantalla de reporte y los textos en inglés y español.

Probado en Studio: una misión completa de 7 días y una tormenta con un astronauta expuesto. La escena era demasiado oscura, así que se reajustó la iluminación.

**16:32 – Etapa 2: datos de la NASA en vivo.**
- Al arrancar el servidor, el juego consulta NASA CCMC DONKI para obtener las llamaradas y los eventos de partículas de los últimos 30 días. Si falla, recurre al archivo e indica cuál de los dos usó.
- Una pantalla "De dónde salen nuestros números" muestra el estado en vivo con la hora de la consulta, datos reales y fuentes.
- Alinear la antena da un aviso de tormenta más largo (45 s en lugar de 15 s) y enseña el retraso de la señal Tierra–Luna frente a Tierra–Marte.
- Borradores en inglés de todos los campos de la entrega.

Probado en Studio:
- La consulta en vivo devolvió 13 llamaradas (la más intensa M3.5, la más reciente M1.7).
- La antena se alineó con una pulsación real de tecla.
- Apareció un aviso de 45 s para una repetición de la llamarada real X5.1 del 11 de noviembre de 2025.

**16:53 – Etapa 3: la base reacciona y guía.**
- Las decisiones de energía se ven en el mundo:
  - Las luces de cultivo del invernadero (magenta, como los LED rojos y azules reales) se atenúan o se intensifican según sus celdas.
  - El ventilador y la luz de la máquina de aire se aceleran con el soporte vital.
  - Un rover de seis ruedas recorre el borde del cráter solo mientras la ciencia tiene energía.
- Primeros dos días guiados: el tablero de energía señala los sistemas que conviene probar primero, y el invernadero se presenta el día 2 ("Las plantas te alimentan mañana").
- Marcadores flotantes muestran cada tarea activa durante un turno.
- El dron C.A.R.L. sigue al astronauta. Su núcleo se vuelve amarillo con las tareas urgentes y morado durante las tormentas, y un haz apunta hacia el refugio.
- Una corrección de color mantiene blanco el Sol bajo y gris el regolito, porque la Luna no tiene atmósfera que tiña de naranja la luz solar.
- Los atajos F8 y F9 (solo en Studio) fuerzan una tormenta o terminan un turno para grabar la demostración.

Probado en Studio:
- Los resaltados guiados.
- Los marcadores de tarea en la antena, en un panel con polvo y en los nodos de hielo.
- Las luces del invernadero.
- F9 y F8 con pulsación de tecla.
- Un aviso de tormenta de 15 s sin la antena, con el haz del dron hacia el refugio y la etiqueta de repetición de la llamarada real X3.9 del 10 de mayo de 2024.

**Hacia las 17:15 – Revisión de la versión por parte del equipo.** El equipo pidió:
- Una identidad visual real e íconos propios en lugar de emoji.
- Corregir gráficos desagradables: el hábitat se veía deslavado.
- Misiones de tutorial y un modo historia con un final parcial.
- Secretos verdaderamente ocultos.

El equipo eligió:
- La paleta "Lunar Sunrise".
- El conjunto abierto de íconos Tabler, con colores propios.
- Sus cuatro coleccionables originales (Mini Tierra, Laika, queso con casco, Papa marciana) como secretos ocultos. Cada uno da una recompensa, y los cuatro juntos abren un quinto secreto.

**18:42 – Etapa 4: misiones, secretos e identidad.**
- **Identidad visual:**
  - `Theme.luau` contiene la paleta y los colores semánticos.
  - 45 íconos Tabler (MIT) subidos y teñidos dentro del juego; ya no queda ningún emoji en la interfaz.
- **Iluminación:**
  - Se quitaron el segundo resplandor (bloom) y el desenfoque de la plantilla, y se limitaron las luces interiores, para que el hábitat se vea con claridad.
  - Se reequilibró la luz exterior: regolito gris, sombras duras y cielo negro.
- **Misiones:**
  - Cuatro misiones de entrenamiento: primeros pasos, tablero de energía, tareas de la base y simulacro de tormenta.
  - Tres capítulos de historia: llegada, temporada de tormentas y algo se rompe.
  - El tercer capítulo termina de forma parcial ("lo siguiente es Marte... y aún quedan secretos").
  - El juego libre se desbloquea después de la historia.
  - El progreso se guarda con DataStores una vez publicado el juego.
- **Secretos:**
  - La Mini Tierra, en cornisas ocultas detrás de la antena.
  - Laika, en un tubo de lava lunar. Ciencia real: LRO fotografió fosas lunares.
  - El queso, en un nicho en la esquina más oscura del cráter.
  - La Papa marciana, en un espacio angosto debajo del hábitat.

  Cada uno muestra una tarjeta de mito contra ciencia y da una recompensa: un aspecto de la Tierra para C.A.R.L., una mochila magenta, pintura amarillo queso para el rover y la bandera del equipo. Los cuatro juntos abren un observatorio oculto con un telescopio apuntando a Marte ("Próxima misión: Marte").

Probado en Studio:
- La pantalla de selección de misiones.
- El entrenamiento 1 completado al salir y volver a entrar.
- Laika recogida en el tubo de lava con una pulsación real de tecla, y después la tarjeta.
- La puerta del observatorio que se abre solo después de los cuatro hallazgos, con el adelanto traducido.
- Las recompensas de la mochila y la bandera del equipo.

**Hacia las 19:00 – Comentarios del equipo tras la prueba de juego.** El equipo pidió:
- Medidores compactos a la izquierda y barras que se muevan.
- Una razón para enlazar la antena y para ir por agua.
- Una Tierra real que gire, con fases y eclipses.
- Un traje de astronauta que le quede a cualquier avatar.
- Que C.A.R.L. señale el camino y cuente datos curiosos.
- Un menú de configuración con un código de evento.
- Palabras más sencillas en todas partes.

**20:42 – Etapa 5: comentarios incorporados.**
- **Medidores en vivo:** aire, comida, radiación y agua se mueven durante el turno hacia el resultado de fin de día. Las acciones se notan de inmediato: el hielo sube el agua y el aire, y una fuga baja el aire.
- **El agua importa:** el oxígeno se produce a partir de agua con electricidad. Sin hielo, el tanque de agua se vacía y la máquina de aire produce menos aire.
- **La antena importa:** la ciencia solo cuenta cuando se envía a la Tierra. Los rovers reales necesitan un enlace de radio para enviar datos. Sin la antena, los datos esperan y no dan estrellas.
- **Tierra real:** mapa Blue Marble de la NASA (dominio público) sobre un disco giratorio ligero. La línea entre el día y la noche sigue al Sol.
  - El modelo del Sol de Roblox no da vueltas alrededor del polo por sí solo, así que el Sol sigue una trayectoria sobre el horizonte calculada de antemano, como en el polo sur lunar real.
  - Cuando el Sol pasa detrás de la Tierra, un eclipse oscurece la base y muestra el anillo rojo anaranjado de la Tierra.
  - Un skybox negro liso mantiene negro el cielo sin aire.
- **Traje de astronauta para todos los avatares:** casco de burbuja con visor dorado, lámpara en el casco, panel en el pecho y mochila (magenta con la recompensa de Laika).
- **C.A.R.L.:**
  - Un haz de guía apunta a la siguiente tarea.
  - Unos 60 datos curiosos verificados aparecen al azar sin repetirse.
  - El aspecto de la Tierra ahora usa el mapa real de la Tierra.
- **Configuración:** idioma, volumen de música y de efectos, interruptores de datos curiosos y de guía, y un cuadro para canjear códigos que se valida en el servidor.
- **Reescritura en lenguaje sencillo** de todos los textos para edades de 7 a 12 años.

Probado en Studio:
- HUD compacto con el agua y el indicador de "datos en espera".
- Medidores en vivo en movimiento.
- Traje en un avatar R15.
- Haz de guía.
- Cielo negro.
- Tierra real con continentes y sombreado de fases.
- Eclipse activado con F10.

**Hacia las 21:00 – Comentarios del equipo tras la prueba de juego, ronda 2.** El equipo pidió:
- Empezar con una base casi vacía: instalar uno mismo la antena y los paneles solares, y luego hacer crecer la base con hielo como en un tycoon de Roblox (primero hielo a mano, después líneas de producción automáticas, mejoras, una moneda, experiencia y habilidades como un doble salto).
- Conservar el avatar propio del jugador. Los niños pagan por sus aspectos, así que el traje solo debe añadir un casco detallado y una mochila, no reemplazar el avatar.
- Un lugar para ver y cambiar lo que se lleva puesto, incluida la opción de quitar las recompensas que no gusten.
- Que C.A.R.L. no vuele con hélices: en la Luna no hay aire.
- Quitar el contorno alrededor de la Tierra y el punto rosa sin explicación cerca de la antena (era una piedrita que daba una pista de la entrada de un secreto).
- Usar lo que encaje del paquete de prototipo de Santiago, integrante del equipo (plataformas de tycoon, mascotas, herramientas).

**El paquete de Santiago, evaluado.** Un prototipo de tycoon completo: plataformas de créditos con vistas previas en holograma, siete módulos, rangos, cuatro mascotas, tres herramientas y un traje.
- Se conservó: los cuatro modelos de mascotas (convertidos a datos en `src/shared/PetModels.luau`, con crédito para él) y estas ideas: plataformas de construcción con un holograma del edificio, edificios que surgen del suelo, rangos por experiencia y la mejora de enlace láser de la antena.
- No se conservó: el código en sí. Duplicaba sistemas que ya funcionaban, usaba emoji y algunas líneas rompían las reglas científicas (C.A.R.L. "limpiando" la radiación del traje, temperaturas inventadas).

**23:00 – Etapa 6: construir y crecer.**
- **Arma tu base:** al inicio solo están el hábitat y el tanque de agua. Los paneles solares (gratis), el invernadero, la antena y el refugio se construyen en plataformas brillantes que primero muestran un holograma. Las misiones de entrenamiento piden cada construcción antes de usarla.
- **Ciclo de tycoon:**
  - Los créditos vienen del trabajo útil: hielo, reparaciones, días terminados, estrellas y misiones.
  - La experiencia sube el nivel del jugador de 1 a 10. Cada nivel desbloquea construcciones más grandes y da un punto de habilidad.
  - Hasta tres taladros de hielo automáticos en el fondo oscuro del cráter llenan un silo, y un robot de carga lo vacía por ti.
  - Cada taladro necesita un arreglo solar más, porque las máquinas necesitan electricidad.
  - Los arreglos construidos son las celdas de energía en las misiones.
  - La antena se mejora a una antena parabólica más grande y después a un enlace láser.
- **Habilidades:** caminar más rápido, un tanque de aire más grande, un doble salto (un soplo de gas desde la mochila) y perforar más rápido.
- **Mascotas:** cuatro mascotas basadas en los modelos de Santiago te siguen. Laika y el queso vienen de los secretos; el conejo lunar y el chimpancé espacial (Ham era un chimpancé) se compran con créditos.
- **Traje:** el avatar nunca se modifica. Solo se añaden un casco hecho con CSG (cubierta blanca, visor oscuro reflejante, anillo de cuello y lámparas) y una mochila con mangueras. El código de evento da un visor y detalles dorados.
- **Vestidor:** elige el casco, la mochila, el aspecto de C.A.R.L. y la mascota, o desactiva las recompensas.
- **C.A.R.L.:** ahora es un pequeño rover de orugas. Avanza a tu lado y da saltitos con propulsores de gas cuando saltas (los propulsores funcionan en el vacío; las hélices necesitan aire). En el modo base señala la siguiente construcción que puedes pagar.
- **Modo base:** la pantalla de misiones se puede cerrar para explorar, construir y recolectar hielo entre misiones.
- **Nuevos datos verificados:** hélices y propulsores, comunicación láser, las leyendas del conejo lunar, Ham, Laika, taladros lunares y construir con polvo lunar. Están listados en `DATA_SOURCES.md`.

Probado en Studio (dirigido por el asistente, con acciones remotas reales):
- Un jugador nuevo ve solo el hábitat con hologramas.
- Construir cada estructura por la ruta de acciones de las plataformas.
- El silo llenándose con los taladros.
- Comprar y equipar una mascota que después sigue al jugador.
- El casco en un avatar R15.
- Los paneles de base y del Vestidor.
- El entrenamiento 1 iniciando con la construcción solar ya contada.

Corregido después de esa prueba de juego: el visor se veía gris pálido (ahora es oscuro y reflejante), el casco era demasiado grande, una etiqueta de pestaña se partía a la mitad de una palabra y los taladros no se veían desde el borde (se añadieron mástiles con balizas).

**Hacia las 23:30 – Comentarios del equipo tras la prueba de juego, ronda 3.** El equipo pidió:
- Un juego más largo y con más por hacer.
- Herramientas por desbloquear, cada una necesaria para su tarea (sin taladro, no hay hielo): un taladro, una tableta para la antena y comida del invernadero para comer.
- Construir por pasos en lugar de todo de una vez.
- Más por explorar, con referencias reales.
- Un rover que se pueda manejar, un garaje para dos vehículos, una plataforma de aterrizaje y una nave para construir (decorativa).
- Un evento aleatorio de meteorito para investigar.
- Un edificio de laboratorio para mejorar el equipo.
- Quitar el menú Base, porque los jugadores podían mejorar todo sin moverse.
- Empezar en el módulo de aterrizaje que trajo a la tripulación, y una distribución de la base como un concepto moderno de base lunar (núcleo, tubos, domos de vidrio, hileras solares).
- Mascotas más detalladas.
- Un error: en primera persona, el mouse no alcanzaba los botones de la tarjeta de secreto nuevo.

#### Domingo 15 de noviembre

**00:45 – Etapa 7: inicio en el módulo de aterrizaje, pasos, herramientas, vehículos y exploración.**
- **Corrección en primera persona:** Roblox fija el mouse al centro de la pantalla en primera persona. Un botón Modal oculto ahora lo libera siempre que hay una tarjeta o un panel abierto.
- **Sin menú Base:** solo se construye en las plataformas del mundo.
- **Inicio en el módulo de aterrizaje:** el jugador aparece en el módulo de aterrizaje de llegada, el único refugio al principio. El hábitat es la primera construcción.
- **Construir por pasos:** pagar inicia un nivel. Cada paso necesita una caja de piezas llevada desde la bodega de carga del módulo de aterrizaje hasta la plataforma, y luego "Armar" con la llave en la mano. La estructura surge del suelo paso a paso; la nave necesita seis pasos.
- **Herramientas en la barra de la mochila:**
  - La llave y el taladro están desde el inicio; el cepillo llega con los paneles, el kit de reparación con el hábitat y la tableta con la antena.
  - La comida fresca se cosecha en el invernadero y se come para un breve aumento de velocidad.
  - Cada tarea necesita su herramienta en la mano.
- **Laboratorio:** habilidades, mejoras del taladro y adopción de mascotas. Solo se abre en el edificio del laboratorio.
- **Garaje:** un carrito lunar que se puede manejar, inspirado en el Apollo Lunar Roving Vehicle, y un camión de hielo que lleva cuatro núcleos de hielo a la máquina de agua.
- **Plataforma de aterrizaje y nave:** una construcción a largo plazo ligada al adelanto "Próxima misión: Marte".
- **Exploración:** cinco sitios basados en misiones y ciencia reales del polo sur, que se escanean con la tableta: un módulo de aterrizaje robótico volcado, el cráter del impacto de LCROSS, huellas de rocas que rodaron, el sitio del impacto de Lunar Prospector y un pico con luz solar la mayor parte del año.
- **Meteoritos:** caen al azar. Solo hay un destello, sin estela encendida: la Luna casi no tiene aire.
- **Distribución de la base:** inspirada en un concepto de base lunar. Un núcleo con un domo y un tubo hacia los domos del invernadero, el refugio como un montículo cubierto de regolito y los paneles solares en hileras. Sin logotipos.
- **Otros cambios:**
  - Las mascotas tienen unas 20–35 piezas cada una, con animaciones de cola y orejas.
  - Hay 15 niveles de jugador.
  - Las partidas guardadas de la etapa 6 conservan su base.

Probado en Studio (dirigido por el asistente):
- Inicio limpio en el módulo de aterrizaje con hologramas de todas las construcciones.
- La construcción del hábitat iniciando desde su plataforma con una pulsación real de tecla.
- Aparición paso a paso del núcleo a medio construir.
- Todas las estructuras construidas por la ruta de depuración.
- Ambos vehículos apareciendo en el garaje; el carrito lunar recorrió 87 studs en 3 s y se mantuvo derecho.
- La mascota chimpancé espacial siguiendo al jugador.
- La aparición de un cráter de meteorito, con C.A.R.L. señalándolo.

Encontrado en esa prueba: Roblox no permite asignar el código fuente de un script de más de 200,000 caracteres, así que el constructor del mundo, de 238,000 caracteres, detuvo la sincronización en vivo de Rojo. Se dividió en módulos más pequeños.

**02:30 – Comentarios del equipo tras la prueba de juego, ronda 4, y correcciones.** Lo que reportó el equipo y las correcciones:
- **Cuadros encimados y HUD debajo de la barra de herramientas:** la barra de aire del traje y las píldoras de carga ahora se apilan por encima de la barra de acceso rápido de Roblox. La burbuja de C.A.R.L. se ubica arriba al centro durante el juego. El letrero "Paso 1/2" sobre una plataforma de construcción es más pequeño y está más arriba, para que nunca tape el aviso de la plataforma.
- **Demasiados marcadores en pantalla:** un marcador aparece solo cuando el jugador está cerca, cuando C.A.R.L. lo señala o cuando el objetivo actual lo necesita.
- **Dos herramientas con el mismo ícono:** el kit de reparación ahora usa su propio ícono de estuche (Tabler briefcase-2), distinto del de la llave.
- **C.A.R.L. señalaba el lugar equivocado:** su haz ahora sigue lo que acaba de decir. "Trae piezas" apunta a la bodega de carga del módulo de aterrizaje; llevar piezas o armar apunta a la plataforma de construcción, nunca a la estructura; limpiar apunta solo a una hilera con polvo.
- **Pista visual para niños:** cada instrucción de C.A.R.L. que necesita una herramienta muestra el ícono de esa herramienta entre el robot y el texto.
- **Error al armar:** después de entregar las piezas, mantener presionada E con la llave no hacía nada hasta que el jugador se alejaba. La causa: el único aviso de la plataforma cambiaba su tiempo de pulsación mientras estaba en pantalla, y Roblox conserva el tiempo anterior. Cada plataforma tiene ahora un aviso separado para Armar. Además, los avisos ya no comparten un límite de frecuencia con otras acciones.
- **"{n}" sin procesar en las etiquetas de los marcadores:** las etiquetas ahora muestran los números.
- **Mascota de queso:** ya no tiene el casco que le atravesaba el cuerpo; ahora lleva una antenita con una luz que parpadea.

**04:20 – Etapa 8: módulos presurizados, equipo, nuevas habilidades y avance automático.** A partir de la prueba de juego del equipo, ronda 5:
- **Zonas interiores:** el invernadero, el laboratorio, el tubo y el anillo exterior del núcleo contaban como exterior (el aire del traje se gastaba y no se podía comer). Cada módulo presurizado ahora tiene una zona con forma (caja, cilindro o domo) que cuenta una vez construido: todo el núcleo redondo, el tubo, los domos 1 y 2 del invernadero, el laboratorio y el módulo de aterrizaje. Una revisión geométrica confirmó que las zonas se traslapan a lo largo del camino.
- **Equipo, que se compra y mejora en el laboratorio (nueva pestaña Equipo) y se activa con una tecla:**
  - Botas de aire (B): un doble salto, con gas que sale de las suelas.
  - Mochila propulsora (J): mantener presionado Saltar en el aire para subir volando con chorros de gas frío, como el MMU y el SAFER de la NASA.
  - Ambas comparten un tanque de gas con su propia barra. Se rellena dentro de los módulos presurizados, y las mejoras hacen que cada uso gaste menos gas.
  - Todos ven en el traje las cubiertas de las botas y los dos tanques de la mochila propulsora.
- **Habilidades:** la habilidad de salto se convirtió en las botas; las partidas guardadas anteriores reciben botas gratis en ese nivel y recuperan sus puntos. Nuevas habilidades:
  - créditos y xp: cada nivel suma el 10% de cada recompensa, redondeado hacia arriba, para que los niños solo vean números enteros;
  - constructor: una pulsación más corta para Armar.
- **Avance automático:** X hace caminar hacia adelante en la dirección de la cámara. X o cualquier tecla WASD lo cancela, y Shift sigue alternando entre correr y caminar.
- **Corrección encontrada en la prueba en Studio:** el HUD llamaba al renderizador del equipo antes de que estuviera definido, lo que detenía el HUD al inicio.
- **Otros:** la pista "Arma tu base" se oculta una vez que están el hábitat y los paneles.

Probado en Studio (dirigido por el asistente):
- Zonas interiores en el centro y los bordes del núcleo, el tubo, ambos domos y el laboratorio; exterior entre los domos.
- Equipo comprado en el laboratorio; los modelos de las botas y de la mochila propulsora visibles en el traje.
- Mantener presionada la barra espaciadora con la mochila propulsora subió 42 studs en 2.5 s.
- El avance automático con X recorrió 46 studs en 2 s; presionar A lo detuvo de inmediato.

**Hacia las 06:30 – Comentarios del equipo, ronda 6.** El equipo pidió:
- Un mundo abierto guiado por aventuras principales (como Palworld) en lugar de un menú de misiones al inicio.
- Un menú de inicio con tres ranuras de guardado, para mundos de un jugador o con amigos.
- Una jerarquía de la base al estilo de Clash of Clans, con el hábitat como ayuntamiento.
- Una economía calibrada para que los jugadores no puedan desbloquear todo de una vez.

**07:35 – Etapa 9: progresión en mundo abierto.**
- **Menú de inicio:** Continuar, Juego nuevo, Cargar juego (tres ranuras que muestran nivel de base, nivel de jugador, créditos y fecha), Configuración y Créditos (equipo, fuentes de datos, declaración del uso de IA). Después, Solo yo o Con amigos.
  - Las partidas se guardan con DataStores de Roblox, que no tienen costo.
  - Solo yo usa un servidor reservado en el juego publicado.
  - El personaje aparece solo después de cargar una ranura.
- **Aventuras principales:** 21 aventuras principales y 9 aventuras extra guían cada mecánica en orden. Las misiones de entrenamiento y de historia ya existentes son pasos de las aventuras y se inician desde la consola de misiones del hábitat. El rastreador de aventuras y el haz de C.A.R.L. siguen el paso actual.
- **Jerarquía de la base:** el hábitat es el nivel de base, del 1 al 5:
  - 1, campamento de llegada: lo que necesita un día de misión;
  - 2, puesto de ciencia: laboratorio, primer taladro, segundo domo del invernadero;
  - 3, base minera: robot de carga, carrito lunar, antena parabólica más grande;
  - 4, base de exploradores: camión de hielo, enlace láser, plataforma de aterrizaje;
  - 5, puerto espacial: la nave.
  - Cada nivel del hábitat se ve diferente, y cada nivel de estructura indica qué mejora.
- **Economía:** un nuevo simulador en Lune de un niño típico (tests/economy.luau) comprueba el ritmo:
  - nivel de base 2 en unos 7 min, laboratorio 16, nivel de base 3 34, garaje 44, nivel de base 4 92, nivel de base 5 179, nave 254;
  - el ingreso nunca salta más de 2.5x entre ventanas de 10 minutos;
  - el silo sigue siendo una ayuda, nunca una granja pasiva.
- **Teclas de depuración:** F3 ahora construye en el orden de los niveles de base.

Probado en Studio (dirigido por el asistente):
- El menú de inicio, luego Juego nuevo, ranura 1, Solo yo.
- Aparición en el módulo de aterrizaje.
- La primera aventura principal mostrada en el rastreador, sin menú de misiones.
- F3 construyendo según el árbol de la base.
- El aviso de la consola de misiones activo en el hábitat.

**Hacia las 08:00 – Comentarios del equipo, ronda 7 (prueba de juego).** El equipo pidió:
- Cuadros de texto más pequeños, porque tapaban la pantalla.
- Una forma visible de guardar: un jugador presionó Salir en una prueba en Studio y perdió el mundo.
- Tubos transitables entre los domos del invernadero y hacia el laboratorio.
- Un panel de aire y comida que se quede en pantalla.
- Avisos cuando una aventura se abre o se completa, porque los jugadores terminaban pasos sin verlos.

**09:20 – Etapa 10: pulido tras las pruebas de juego.**
- **Cuadros más pequeños:**
  - La burbuja de C.A.R.L. mide alrededor del 60% de su tamaño anterior.
  - Las píldoras inferiores (llevar hielo, piezas, avance automático, gas) tienen alrededor de dos tercios de su altura anterior.
- **Panel de signos vitales:**
  - Un panel en la columna izquierda está siempre visible durante el juego. Muestra el aire del traje, la comida fresca del invernadero (lista, una cuenta regresiva o el aumento de energía) y el hielo del silo.
  - Ya no está la barra grande de aire del traje en la parte inferior. Una pequeña píldora pulsante "¡Poco aire!" aparece solo cuando el aire se está acabando en el exterior.
- **Avisos de aventuras (QuestToasts.luau):** una tarjeta a la derecha dice:
  - "¡Nueva aventura!" o "¡Nueva aventura extra!";
  - "Listo: &lt;paso&gt;";
  - "¡Aventura completa!" con los créditos y la XP obtenidos.
  - Los pasos que ya estaban hechos cuando se abrió una aventura aparecen como "Ya hecho". El rastreador de aventuras también destella.
  - Las tarjetas esperan mientras hay un panel de pantalla completa abierto.
- **Guardado que se ve:**
  - Una pequeña píldora "Juego guardado" aparece después de los guardados automáticos (como máximo cada 30 s) y después de un guardado manual.
  - Configuración tiene un botón "Guardar ahora" (una acción SaveNow validada, con límite de frecuencia por los DataStores).
  - El menú de inicio y Configuración dicen "Tu juego se guarda solo".
  - Studio usa un DataStore real separado cuando el lugar está publicado; si no, usa la memoria. Cuando las partidas solo viven en la memoria, la píldora dice "Guardado solo para esta prueba".
- **Tubos transitables:**
  - Del domo A al domo B y del núcleo al laboratorio ahora hay tubos transitables con piso, entradas y una rampa suave hasta el piso del laboratorio.
  - Las zonas presurizadas cubren todo el camino.
  - Escotillas de vidrio cierran las entradas hasta que se construyen el nivel 2 del invernadero y el laboratorio.
  - Seguimiento del equipo: el domo A del invernadero ahora está sobre la línea del tubo del núcleo (estaba desplazado 8 studs, así que el tubo llegaba al domo en diagonal). El domo B y la plataforma del laboratorio se movieron con él.
  - Seguimiento del equipo: el domo A tenía una abertura encima de la entrada del tubo del núcleo (el tubo terminaba antes del vidrio). Las tablillas superiores del tubo ahora entran en el domo como vidrio, y la conexión del domo A al B hace lo mismo. Rayos lanzados desde arriba en cada stud sobre ambas entradas no encontraron ningún hueco.

Probado en Studio (dirigido por el asistente):
- Menú de inicio, Juego nuevo, Solo yo.
- El panel de signos vitales mostró el aire del traje, la comida fresca y el hielo del silo.
- Las tarjetas de paso y de "¡Aventura completa!" aparecieron con la recompensa y esperaron detrás del reporte de la misión.
- "Guardar ahora" mostró la píldora de solo memoria (el lugar no está publicado).
- Caminar del núcleo al laboratorio y del domo A al domo B nunca contó como exterior.
- Sin errores de script.

#### Domingo 15 de noviembre, tarde y noche

**Seguimientos de la etapa 10.** Las entradas completas están en `DEVELOPMENT.md`.
- **Menú de inicio cinematográfico.** Ocho tomas de cámara en vivo se reproducen detrás del menú (`CinematicShots.luau`, `Cinematic.luau`, `tests/cinematic`), con una base de exhibición terminada mientras nadie en el servidor ha cargado una partida. Con las mismas tomas se editó el tráiler de 30 segundos, con música original sintetizada con código.
- **Aire del traje al manejar.** Ir en un vehículo ahora usa el ritmo de descanso, no el de correr.
- **Tormentas y radiación.** Unos amigos que jugaron la versión publicada en una tripulación de tres reportaron tormentas "muy, muy seguido" y una barra de radiación que casi no se movía. El Simulacro de tormenta ahora solo se repite después de una pausa de 45 segundos y como máximo 3 veces por turno, quedarse a salvo cuenta por jugador, y la dosis de la tormenta se cuenta segundo a segundo mientras hay partículas, así que el medidor sube para quien está afuera y no se mueve para una tripulación en el refugio.
- **Mundos privados.** Un jugador presionó Juego nuevo y apareció en el mundo de un amigo. Ahora cada mundo corre en su propio servidor reservado, la base siempre es del dueño, y "Con amigos" admite hasta 3 amigos de Roblox mediante "Unirse a un amigo" (`Worlds.luau`, `tests/worlds`).
- **Logros de aprendizaje.** 13 logros de ciencia ligados a eventos reales, de 10 XP cada uno, con un panel, avisos e insignias opcionales de Roblox (`Achievements.luau`, `tests/achievements`).
- **Un archivo de documentación por idioma:** este archivo y `DOCUMENTATION.md`.

#### Lunes 16 de noviembre

**Publicación de la etapa 10.** Los mundos privados, las correcciones de tormentas y radiación y los logros de aprendizaje se probaron en Studio y se publicaron en la experiencia en vivo. El tamaño de servidor del lugar se fijó en 4.

**00:03 – Teclas de depuración solo en Studio.** Las teclas F del equipo y cada acción de depuración ahora solo funcionan en Roblox Studio, nunca en el juego en vivo, ni siquiera para el dueño del lugar.

**01:30 – Etapa 11, primera ola: servidor, datos y sonido.** Una auditoría del juego en vivo, una auditoría de experiencia de los primeros minutos e investigación sobre cómo aprenden los niños llevaron a una renovación durante la noche, construida por agentes de IA en paralelo con una revisión de cada parte.
- **Servidor más seguro (`ServerGuard.luau`, `MissionData.GUARD`).** Los avisos de tareas revisan en el servidor que el jugador esté junto a ellos. La perforación se limita a 15 núcleos por minuto, y un núcleo solo cuenta en la máquina de agua cuando de verdad pudo haber viajado hasta ahí. El vestíbulo no acepta acciones de juego. Un candado de sesión evita el truco de cambiar de servidor para gastar créditos en un mundo y conservarlos en otro, y Continuar nunca borra una ranura. La configuración se guarda con el jugador. El polvo ahora también cae en un panel solar entre misiones, y un traje sin aire lleva al niño al cuarto presurizado más cercano.
- **Aventuras que enseñan (`Quests.luau`, `Quiz.luau`, `Glossary.luau`).** Una primera aventura, "¡Hola, Luna!", da un premio en más o menos un minuto. Los pasos muestran su número una sola vez y usan las mismas palabras que las plataformas y el HUD. Maestro del hielo enseña que un taladro más grande saca más por sí solo. C.A.R.L. felicita la estrategia que funcionó, hace una pregunta con imagen después de 11 aventuras, da pistas de tesoros tipo adivinanza y sugiere un descanso después de 45 minutos.
- **Sonido y música (`AudioIds.luau`, `Audio.luau`).** El juego no tenía sonido. Ahora tiene 50: 6 pistas de música, 3 remates y 41 efectos, sintetizados con el código propio del equipo más cinco mezclas CC0, con una regla honesta del casco para el sonido en el vacío.
- **La línea de hielo es un tycoon de verdad.** Reporte del equipo: la línea de producción "no se ve y ni siquiera da dinero". Los taladros ahora sacan 2, 3 o 4 de hielo por minuto, los cubos viajan por una banda abierta hasta un silo más alto, una nueva planta de agua derrite el hielo, la construcción del robot de carga agrega una máquina de aire y el robot lleva agua o aire a un puerto de suministros, a la vista. El servidor publica el estado de la línea y cada cliente la anima. El silo se guarda, y los taladros siguen trabajando mientras el dueño no está (como máximo 8 horas). Desde el robot de carga hasta la nave, las máquinas ganan el 49% de lo que gana jugar.

**02:06 – Etapa 11, segunda ola: lo que ve el jugador.**
- **El tycoon en pantalla.** Avisos "+N créditos", la tarjeta "Mientras no estabas", letreros sobre el silo y la planta de agua, la etiqueta de las máquinas bajo la cartera, y el haz de C.A.R.L. ya no atraviesa paredes.
- **Menú de inicio, configuración guardada y ayudas.** Sin "Cargar juego" (petición del equipo: sonaba a subir un archivo). Continuar con una tarjeta, Mis mundos con Continuar o Empezar de nuevo, "Volver al inicio" si la carga tarda, pantallas de teletransporte con el tema del juego, una configuración que sobrevive a los viajes y a volver a entrar, y una página de Ayudas (texto grande, menos movimiento, tiempo de mensajes, ayuda de colores).
- **Interfaz fácil de leer.** Tiempos de lectura para un niño de 7 años, frases juntadas y saltadas, un historial con las últimas 10 frases de C.A.R.L., barras de avance en el seguimiento, una tarjeta dorada grande para las aventuras principales, logros por páginas, la tarjeta de la pregunta de C.A.R.L. y el glosario con imágenes (`Reading.luau`, `tests/reading`).
- **Celebraciones, sensación de cámara, teléfonos y un mapa más seguro.** Confeti, destellos y títulos de nivel; estrellas una por una en el reporte y fichas de causa y efecto; una pequeña sacudida a través del suelo por los meteoritos cercanos y un pulso naranja en los bordes durante las tormentas; un tamaño mínimo de texto y márgenes seguros en los teléfonos; paredes en el borde del mapa; y dos rampas más para salir del cráter de hielo (`Feel.luau`, `WorldSafety.luau`, `tests/feel`).
- **Cápsula de suministros diaria y Bitácora lunar.** Una cápsula por día real con un calendario fijo de 7 días y sin azar, un conteo comprensivo, datos de la carga sin números, franjas del traje y la Bitácora con 27 registros y tres hitos (`Daily.luau`, `DailyService.luau`, `tests/daily`).

**02:10 – Correcciones de prueba de la etapa 11, versión 0.11.0.** El tamaño mínimo de texto ahora solo aplica en pantallas táctiles, la etiqueta del día 7 cabe en una línea, y los destellos usan la partícula suave predeterminada de Roblox, porque el ícono de estrella no tiene versión de textura 3D.

Probado en Studio (prueba rápida): el menú de inicio sin Cargar juego, la lista de mundos, la aparición en la nave, el seguimiento de aventuras, la tarjeta de la cápsula diaria, la línea de hielo y ningún error en la consola. Los once conjuntos de pruebas de Lune pasan y el proyecto se compila con Rojo.

### 5.3 Decisiones

| Decisión | Quién decidió | Por qué |
| :--- | :--- | :--- |
| Cambiar de simulador de vuelo a administración de un puesto avanzado | Equipo | El reto pide equilibrar recursos en un puesto avanzado. |
| Polo sur de la Luna, mecánicas de un integrante del equipo | Equipo | Luz y sombra reales en el polo, hielo de agua y un tema atractivo. |
| Nombre *Space Base Odyssey* | Equipo | — |
| Planeación por turnos más un turno de trabajo en tiempo real | Equipo, por recomendación de la IA | La planeación es tranquila para niños pequeños; el turno es la parte divertida. |
| Tres sistemas, tres medidores | Equipo, por recomendación de la IA | El reto aconseja 2–3 recursos principales. |
| El refugio como decisión, no como consumo de energía | Equipo, por recomendación de la IA | Precisión científica: protege la masa, no la energía. |
| Llamaradas reales de DONKI, con las repeticiones etiquetadas como repeticiones | Equipo, por recomendación de la IA | El reto prohíbe presentar datos estáticos como si fueran en vivo. |
| Sin logotipos de la NASA, solo atribución en texto | Equipo | Reglas de marca de la NASA y reglas de IA de Space Apps. |
| Identidad visual "Lunar Sunrise", íconos Tabler | Equipo | Aspecto coherente y apto para niños; íconos MIT hechos por personas. |
| Cuatro coleccionables originales más un observatorio | Equipo | La primera idea propia del equipo, conservada sin siglas de ninguna agencia. |
| Tutorial más una historia de 3 capítulos | Equipo, por recomendación de la IA | Enseña cada mecánica y luego deja que los niños la apliquen. |
| Agua y antena con consecuencias reales | Equipo, por recomendación de la IA | Cada tarea debe desbloquear algo o costar algo. |
| Mapa real de la Tierra de la NASA con eclipses | Equipo | Da una razón a la iluminación de la base y enseña los eclipses lunares. |
| El mismo traje de astronauta para todos los avatares | Equipo | Aspecto coherente sin importar el aspecto del jugador. |
| Sin camiseta de Space Apps ni de la NASA como recompensa del evento | Equipo, por recomendación de la IA | No se permite la insignia de la NASA; en su lugar, un aspecto original Explorer 2026. |
| Empezar con una base casi vacía y hacerla crecer al estilo tycoon | Equipo | Más dinámico y atractivo para los niños; enseña para qué sirve cada sistema. |
| Conservar el avatar del jugador; solo un casco y una mochila | Equipo | Los niños pagaron por sus aspectos. |
| C.A.R.L. como rover de orugas con saltitos de propulsores de gas | Equipo, por recomendación de la IA | Las hélices necesitan aire; los propulsores funcionan en el vacío. |
| Chimpancé espacial en lugar de mono espacial | Recomendación de la IA, pendiente de confirmar por el equipo | Ham, quien voló en 1961, era un chimpancé. |
| Empezar en el módulo de aterrizaje, construir por pasos, herramientas necesarias para las tareas | Equipo | Un juego más largo y práctico; enseña para qué sirve cada herramienta. |
| Quitar el menú Base; habilidades solo en el laboratorio | Equipo | Los jugadores mejoraban todo sin moverse. |
| Misiones reales del polo sur como sitios de exploración | Equipo, por recomendación de la IA | Referencias reales que los niños pueden investigar. |
| Mundo abierto con aventuras principales; tres ranuras de guardado; el hábitat como nivel de base | Equipo | Progresar mientras se juega, conservar el progreso, crecimiento coherente. |
| Economía con ritmo definido por un jugador simulado | Equipo, por recomendación de la IA | Evita que los jugadores desbloqueen todo en minutos. |
| Roblox Studio como motor | Equipo | Habilidades del equipo; Roblox se usó en ediciones anteriores de Space Apps. |
| Mundos privados: cada mundo en su propio servidor, la base es del dueño | Equipo | Un jugador apareció en el mundo de un amigo; los niños deben conservar su propia base. |
| Teclas de depuración solo en Studio | Equipo | El juego en vivo no debe dar atajos a los jugadores. |
| Sin "Cargar juego" en el menú de inicio | Equipo | Sonaba a subir un archivo; Continuar y Mis mundos son más claros. |
| Una línea de hielo que se ve funcionar y que paga con un viaje real del robot | Equipo, por recomendación de la IA | Al equipo el tycoon le parecía invisible y sin pago; las máquinas siguen siendo una ayuda (del 30 al 50% de lo que gana jugar). |
| Sonido honesto: apagado fuera del casco, sin sacudida por tormentas | Equipo, por recomendación de la IA | En el vacío no hay sonido y la radiación no empuja nada. |
| Cápsula diaria con calendario fijo, sin azar y con conteo comprensivo | Equipo, por recomendación de la IA | Un motivo para volver sin cajas de botín ni presión; jugar da más que esperar. |
| Felicitar la estrategia, preguntas cortas, un aviso de descanso | Equipo, por recomendación de la IA | Investigación sobre el aprendizaje en niños pequeños; nada se pierde por una respuesta equivocada. |

### 5.4 Evidencia de pruebas

| Qué | Cómo | Resultado |
| :--- | :--- | :--- |
| Balance de las misiones | `lune run tests/balance` | 716 comprobaciones aprobadas. |
| Ritmo de la economía | `lune run tests/economy` | 234 comprobaciones aprobadas (línea de tiempo de un niño simulado, máquinas al 49% de lo que gana jugar). |
| Misiones y reglas de construir y crecer | `lune run tests/missions`, `lune run tests/base` | 729 y 2201 comprobaciones aprobadas. |
| Tomas cinematográficas | `lune run tests/cinematic` | 189 comprobaciones aprobadas. |
| Mundos privados y el candado de sesión | `lune run tests/worlds` | 116 comprobaciones aprobadas. |
| Logros, preguntas y glosario | `lune run tests/achievements` | 758 comprobaciones aprobadas. |
| Cápsula diaria y Bitácora lunar | `lune run tests/daily` | 222 comprobaciones aprobadas. |
| Celebraciones, salidas del cráter, borde del mapa | `lune run tests/feel` | 323 comprobaciones aprobadas. |
| Tiempos de lectura | `lune run tests/reading` | 102 comprobaciones aprobadas. |
| Longitud de los textos y traducciones | `lune run tests/localization` | 51496 comprobaciones aprobadas: todas las claves en en y es, con 8 palabras como máximo. |
| El lugar se compila | `rojo build default.project.json -o <temp>.rbxl` | Se compila. |
| Misión completa en Roblox | Prueba de juego en Studio dirigida por el asistente | 7 días, se llegó al reporte, sin errores de script. |
| Datos de la NASA en vivo | Prueba de juego en Studio | 13 llamaradas obtenidas; se muestra la hora de la consulta. |
| Aviso de tormenta con antena | Prueba de juego en Studio, pulsación real de tecla | Aviso de 45 s, llamarada etiquetada como repetición con su fecha. |
| Radiación en vivo | Prueba de juego en Studio (publicación de la etapa 10) | Subió de 0.5 a 23.1 estando afuera durante la tormenta de entrenamiento. |
| Prueba rápida de la etapa 11 | Prueba de juego en Studio | Menú de inicio sin Cargar juego, lista de mundos, aparición en la nave, seguimiento de aventuras, tarjeta de la cápsula diaria, línea de hielo, sin errores en la consola. |
| Prueba de juego con personas ajenas al equipo | Pendiente | — |

### 5.5 Cómo se usó la IA

Las reglas la llaman "Super Intelligence (SI)".

**Lo que hizo la IA (Claude, de Anthropic, en Claude Code):**
- Investigación y verificación de datos. Cada dato se volvió a verificar en una revisión independiente de IA que abrió de nuevo la fuente. Los valores están en `DATA_SOURCES.md`.
- Una auditoría de los primeros documentos de diseño del equipo.
- Borradores del plan y críticas independientes.
- Generación de código con agentes en paralelo, con revisiones de integración.
- Pruebas automatizadas y pruebas de juego en Studio.
- Borradores de textos.
- Los scripts de síntesis de audio que el equipo usó para hacer la música y la mayoría de los efectos, y la auditoría e investigación detrás de la etapa 11.

**Lo que hizo el equipo:**
- El concepto y cada decisión de diseño.
- La elección del escenario y de las mecánicas.
- La aprobación de los números.
- Las pruebas de juego, la publicación, el video y la presentación.

Cada archivo de código hecho con ayuda de la IA empieza con una línea de declaración. No se usan imágenes ni video generados por IA. La música y los efectos de sonido se sintetizan con código propio del equipo (escrito con ayuda de IA, sin ningún modelo generativo de audio), y cinco efectos mezclan grabaciones CC0 editadas.

### 5.6 Problemas conocidos

- Las experiencias nuevas de Roblox solo se abren a cuentas de 16 años o más con edad verificada hasta que pasan la evaluación de Roblox. Los niños del rango de edad objetivo todavía no pueden jugar la versión pública.
- El diseño para teléfono todavía no se ha revisado en un dispositivo real.
- La etapa 11 pasó una prueba rápida en Studio, no una prueba de juego completa con niños; los sonidos, la cápsula diaria a lo largo de varios días reales y un mundo con amigos con la etapa 11 todavía necesitan una revisión en vivo.
- La Ayuda de colores se guarda, pero ninguna pantalla la usa todavía (las zonas de los medidores y los botones de encendido ya muestran formas).

## 6. Fuentes, créditos y licencias

Esta sección reúne todas las fuentes de datos, todos los créditos de terceros y la licencia de Space Base Odyssey. La subsección 6.1 reproduce `DATA_SOURCES.md` completo: cada número que el juego muestra a los jugadores debe aparecer ahí, y cada valor REAL de `src/shared/MissionData.luau` remite a una de sus filas. La subsección 6.2 reproduce `THIRD_PARTY_NOTICES.md` completo. La subsección 6.3 resume la licencia, y la subsección 6.4 es la declaración de "Uso de Superinteligencia" que exigen las reglas de Space Apps.

### 6.1 Fuentes de datos

El texto siguiente es `DATA_SOURCES.md` tal como está en el repositorio. Solo se ajustaron los niveles de encabezado para que encajen en este documento.


Cada número que se muestra en Space Base Odyssey debe venir de este archivo. Si un valor no está aquí, no se muestra a los jugadores.

- **Compilado:** 14 de noviembre de 2026, durante NASA Space Apps 2026.
- **Método:** los datos se reunieron con ayuda de investigación de IA (Claude, Anthropic). Después, cada dato se volvió a comprobar en una pasada de verificación independiente por IA que abrió de nuevo la fuente citada. El equipo revisa cada valor antes de que entre al juego.
- **Totales:** 199 datos. 189 verificados, 9 corregidos durante la verificación, 1 sin verificar. (Los 14 datos de la sección de la Etapa 6 se agregaron el 14 de noviembre de 2026; los 17 datos de la sección de la Etapa 7 y los 5 datos de la sección de la Etapa 8, el 15 de noviembre de 2026. Los candidatos descartados se enumeran en las notas de cada sección y no se cuentan.)

#### Leyenda de estados

| Estado | Significado | ¿Puede aparecer en el juego? |
| :--- | :--- | :--- |
| Verificado | El verificador abrió la fuente y el valor coincidió. | Sí |
| Corregido | El primer valor era incorrecto; la fila muestra el valor y la fuente corregidos. | Sí |
| Sin verificar | No se confirmó en ninguna fuente abierta, o no se encontró. | No |

#### Reglas para usar estos datos en el juego

1. **Valor real o parámetro de juego.** Cada constante de `src/shared/MissionData.luau` está etiquetada como valor real (con la fila de este archivo de la que proviene) o como parámetro de juego (un número de ajuste elegido para que el juego sea jugable).
2. **En vivo frente a archivado.** Los datos archivados nunca se presentan como datos en vivo. La pantalla de fuentes del juego indica si el clima espacial vino de una consulta en vivo, con la hora de la consulta, o del archivo, con la fecha del evento.
3. **Observado cerca de la Tierra.** Los eventos de DONKI se observan desde las cercanías de la Tierra. El juego dice "¿Y si una tormenta como la del (fecha) llegara a tu base?", nunca que el evento golpeó la base.
4. **Fuentes congeladas.** Las fuentes públicas de clima de Marte (InSight, Perseverance, Curiosity) dejaron de actualizarse hace años y deben etiquetarse como archivadas. Consulta la sección de energía y entorno.
5. **Atribución.** Las fuentes se acreditan como texto dentro del juego (por ejemplo, "Clima espacial: NASA / CCMC DONKI"). Roblox no permite enlaces externos dentro de una experiencia, así que las URL viven en este archivo y en el README. Ninguna insignia, logotipo ni parche de misión de la NASA en ningún lugar.

#### Comprobación de endpoints de clima espacial (14 de noviembre de 2026, 11:58 UTC-6)

| Endpoint | Resultado |
| :--- | :--- |
| `https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=...&endDate=...` | HTTP 200, JSON, no requiere clave de API. Usar este. |
| `https://api.nasa.gov/DONKI/FLR?...&api_key=DEMO_KEY` | HTTP 429 (límite de solicitudes excedido). Una clave registrada podría funcionar; no se probó. |
| `https://kauai.ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?...` | Se agotó el tiempo de espera. |

Ejemplo de registro devuelto: llamarada `2026-10-16T15:38:00-FLR-001`, clase M1.3, pico el 2026-10-16 a las 15:42 UTC, ubicación de origen S16W15, región activa 14551.

#### Soporte vital y alimentos

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Metabolismo de la tripulación: oxígeno consumido | La NASA BVAD Rev2 (NASA/TP-2015-218570 Rev2, feb. 2022), Tabla 3-31, da un consumo nominal de oxígeno de 0.895 kg por tripulante por día (la nota al pie 77 lo redondea a 0.90) para un astronauta de referencia de 82 kg que hace 30 min de ejercicio aeróbico + 60 min de ejercicio de resistencia al día. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 2 | Metabolismo de la tripulación: CO2 producido | La Tabla 3-31 de la BVAD Rev2 da una carga nominal de dióxido de carbono de 1.085 kg por tripulante por día (cociente respiratorio 0.86). | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 3 | Metabolismo de la tripulación: agua para beber y agua potable | BVAD Rev2: 2.00 kg/día de agua para beber + 0.50 kg/día de agua para rehidratar alimentos = 2.50 kg/CM-d de consumo humano total (Tabla 4-20, igual para la ISS, el vehículo de tránsito y las bases planetarias); la Tabla 3-31 usa 3.217 kg/CM-d de agua potable una vez que se suman 0.717 kg extra por la transpiración durante el ejercicio. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 4 | Necesidad de agua de la tripulación (cifra pública sencilla) | La hoja informativa de ECLSS de NASA Marshall (MSFC-02-2025-G-657270) dice que cada astronauta necesita alrededor de un galón de agua al día para consumo, preparación de alimentos e higiene, y que los astronautas necesitan beber medio galón de agua cada día. | Verificado | <https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf> |
| 5 | Uso total de agua, incluida la higiene (base planetaria) | Consumo total de agua por tripulante por día según la Tabla 4-20 de la BVAD Rev2: ISS 5.38 kg (2.50 de consumo humano + 0.7 de higiene + 2.18 de carga útil); vehículo de tránsito 3.2 kg (2.50 + 0.7, carga útil por definir); base planetaria inicial 4.48 kg (2.50 + 1.98 de higiene, incluidos 1.08 kg de ducha); base planetaria madura 9.12 kg (2.50 + 6.62 de higiene, incluidos ducha 1.08, lavandería 1.1 y lavado de trastes 3.54). | Corregido | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 6 | Masa de alimentos (seca y empacada) | BVAD Rev2: el valor de planeación del suministro de alimentos de la ISS es de 2.39 kg por tripulante por día, incluido el empaque (0.43 kg son empaque); en realidad se consumen 1.56 kg con 48.7% de hidratación, es decir, 0.80 kg de sólidos alimenticios secos al día. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 7 | Energía de los alimentos / calorías por día | La BVAD Rev2 fija la energía de los alimentos en 12.778 MJ por tripulante por día (unas 3,050 kcal, derivado) y cita el requisito actual de la NASA de 12.707 MJ/CM-d (~3000 kcal); la Agencia Espacial Canadiense dice que los astronautas consumen entre 1900 y 3200 calorías al día según su peso, sexo y necesidades específicas. | Verificado | <https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp> |
| 8 | Calor metabólico | La Tabla 3-31 de la BVAD Rev2 da una carga total de calor metabólico de 12.426 MJ por tripulante por día (sensible 6.308 MJ, latente 6.118 MJ), equivalente a unos 144 W continuos (derivado). | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 9 | Método de generación de oxígeno de la ISS | En la ISS, el Sistema de Generación de Oxígeno produce oxígeno por electrólisis: la corriente eléctrica de los paneles solares de la estación separa el agua en oxígeno (que se envía a la cabina) e hidrógeno, que se expulsa al espacio o se lleva, junto con el CO2 de la tripulación, a un reactor Sabatier que produce agua (que se conserva) y metano (que se libera al espacio). | Verificado | <https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf> |
| 10 | Producción del Ensamble de Generación de Oxígeno de la ISS | El OGA de la ISS genera oxígeno a una tasa seleccionable de hasta 9.25 kg/día (20.4 lb/día) a 46.9 A, suficiente para 10.88 tripulantes suponiendo 0.85 kg de O2 por persona por día; se diseñó para una tasa nominal máxima de 5.4 kg/día (12 lb/día) en ciclos orbitales de día y noche (para 4 tripulantes más especímenes y fugas) y una tasa seleccionable de 2.3-9.2 kg/día en operación continua. | Verificado | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 11 | Eliminación de CO2 en la ISS (CDRA, LiOH) | El Ensamble de Eliminación de Dióxido de Carbono de la ISS es un tamiz molecular (zeolita) regenerable heredado, de cuatro lechos, que elimina 4.2 kg de CO2/día a 2 mmHg y 6.5 kg/día a 3 mmHg de CO2 en cabina, y elimina de forma continua el CO2 de seis personas equivalentes con ambos lechos en funcionamiento; los cartuchos de hidróxido de litio son el respaldo y solo pueden usarse una vez. | Verificado | <https://ntrs.nasa.gov/api/citations/20260005251/downloads/ICES_CO2_ESM_2026.pdf> |
| 12 | Límite de CO2 en cabina | La NASA-STD-3001 (Vol. 2, V2 6004) exige que la presión parcial promedio de CO2 en 1 hora dentro del volumen habitable no sea mayor de 3 mmHg. | Verificado | <https://www.nasa.gov/ochmo-tb-004-carbon-dioxide-2/> |
| 13 | Tasa de recuperación de agua de la ISS (hito del 98%) | La NASA anunció el 20 de junio de 2023 que el ECLSS de la ISS demostró una recuperación total de agua del 98% gracias al Ensamble Procesador de Salmuera; antes del BPA, la recuperación total estaba entre 93 y 94%. | Verificado | <https://www.nasa.gov/missions/station/iss-research/nasa-achieves-water-recovery-milestone-on-international-space-station/> |
| 14 | Consumo eléctrico de las unidades del ECLSS | Ni el investigador ni yo encontramos, en ninguna fuente de la NASA abierta, una cifra publicada de potencia eléctrica por unidad (kW) para el OGA, el CDRA o el Sistema de Recuperación de Agua de la ISS; los artículos sobre el OGA solo dan la corriente de la pila de celdas (10-46.9 A), y ni la BVAD Rev2 ni el artículo de ESM sobre eliminación de CO2 de 2026 enumeran la potencia de los racks de la ISS. | Sin verificar | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 15 | Totales de MOXIE | MOXIE, a bordo del rover Perseverance, produjo un total de 122 gramos de oxígeno en 16 corridas, con una tasa máxima de 12 gramos por hora y una pureza de 98% o más; su 16.ª y última corrida, el 7 de agosto de 2023, produjo 9.8 g, y la NASA anunció la conclusión el 6 de septiembre de 2023. | Verificado | <https://www.nasa.gov/missions/mars-2020-perseverance/perseverance-rover/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/> |
| 16 | Potencia y tamaño de MOXIE | La NASA describe MOXIE como un instrumento de 300 watts con una masa de 17.1 kg (37.7 lb), de 23.9 x 23.9 x 30.9 cm, que produce hasta 10 gramos de oxígeno por hora, durante aproximadamente una hora de producción de oxígeno por experimento. | Verificado | <https://science.nasa.gov/mission/mars-2020-perseverance/science-instruments/> |
| 17 | Primera corrida de MOXIE y necesidad de escalar | La primera corrida de MOXIE, el 20 de abril de 2021 (sol 60), produjo unos 5.4 gramos de oxígeno, suficientes para unos 10 minutos de respiración de un astronauta; la NASA dice que sacar a cuatro astronautas de Marte requiere unas 25 toneladas métricas de oxígeno (55,000 lb), mientras que los astronautas que pasen un año en la superficie usarían quizá una tonelada métrica entre todos; la atmósfera de Marte es 96% CO2. | Verificado | <https://www.nasa.gov/news-release/nasas-perseverance-mars-rover-extracts-first-oxygen-from-red-planet/> |
| 18 | Hielo de agua en Marte como recurso | Un mapa de la NASA/JPL (10 de diciembre de 2019) muestra hielo de agua en Marte a tan solo una pulgada (2.5 cm) bajo la superficie, con hielo a menos de un pie (30 cm) de profundidad en zonas cartografiadas de Arcadia Planitia, que los astronautas podrían extraer para obtener agua potable y combustible para cohetes; el agua expuesta no se mantiene líquida en el delgado aire marciano. | Verificado | <https://www.nasa.gov/solar-system/nasas-treasure-map-for-water-ice-on-mars/> |
| 19 | Hielo de agua en los polos lunares | Con el Moon Mineralogy Mapper de Chandrayaan-1, los científicos confirmaron directamente hielo de agua en la superficie, en cráteres en sombra permanente en los polos de la Luna (PNAS, 20 de agosto de 2018), donde las temperaturas más cálidas nunca superan los -250 °F (unos -157 °C, derivado); el hielo está en los primeros milímetros, concentrado en cráteres del polo sur y repartido de forma más amplia pero dispersa en el polo norte. | Verificado | <https://www.jpl.nasa.gov/news/ice-confirmed-at-the-moons-poles> |
| 20 | Medición de agua lunar de LCROSS | El impacto de LCROSS en el cráter Cabeus, el 9 de octubre de 2009, levantó un máximo de 155 ± 12 kg de vapor de agua y hielo de agua dentro del campo de visión del instrumento, y la concentración de hielo de agua en el regolito del sitio de impacto se estima en 5.6 ± 2.9% en masa (Colaprete et al., Science 330, 463-468, 22 de octubre de 2010); el comunicado de la NASA del 21 de octubre de 2010 agrega que hasta el 20 por ciento del material levantado eran volátiles y que, en algunos lugares, el agua era sobre todo cristales de hielo puro. | Verificado | <https://experts.arizona.edu/en/publications/detection-of-water-in-the-lcross-ejecta-plume/> |
| 21 | Veggie: primera lechuga comida y días hasta la cosecha | El primer cultivo cultivado y consumido en equipo de la NASA fue la lechuga romana roja 'Outredgeous' en Veggie (VEG-01 B): Scott Kelly la inició el 8 de julio de 2015 con seis almohadillas de plantas, creció durante 33 días y la tripulación se comió la mitad de las hojas el 10 de agosto de 2015. | Verificado | <https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf> |
| 22 | Veggie: potencia, tamaño, cultivos | Veggie funciona con unos 70 watts para las luces, los ventiladores y la electrónica de control, tiene aproximadamente el tamaño de una maleta de mano y normalmente aloja seis plantas; según la hoja informativa de la NASA de 2020, en Veggie habían crecido 15 tipos distintos de plantas, incluidos ocho tipos de hortalizas de hoja que comieron los astronautas (tres tipos de lechuga, col china, mostaza mizuna y kale rojo ruso, entre otras) además de flores de zinnia. | Verificado | <https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf> |
| 23 | Advanced Plant Habitat | El Advanced Plant Habitat (lanzamiento registrado el 18 de abril de 2017) es una cámara de cultivo automatizada y totalmente cerrada con más de 180 sensores y LED rojos, azules, verdes y blancos de espectro amplio, que admite investigaciones de hasta 135 días; en ella se han cultivado Arabidopsis, trigo enano, rábanos y chiles verdes Hatch de Nuevo México. | Verificado | <https://smd-cms.nasa.gov/wp-content/uploads/2023/06/advanced-plant-habitat.pdf> |
| 24 | Por qué los cultivos frescos todavía no pueden aportar todas las calorías | R. M. Wheeler, científico de plantas de NASA Kennedy, estima que unos 20-25 m2 de cultivos podrían cubrir las necesidades de oxígeno de una persona y unos 50 m2 podrían aportar sus alimentos (calorías de la dieta); una unidad Veggie normalmente aloja seis plantas, y la NASA señala que las vitaminas de los alimentos preempacados se degradan con el tiempo, así que hoy los cultivos frescos son un complemento. | Verificado | <https://ntrs.nasa.gov/citations/20205008786> |
| 25 | Ciclo de cultivo de lechuga en ambientes controlados | La BVAD Rev2 señala que los esquemas de espaciado variable o de trasplante pueden reducir el ciclo de producción de lechuga de 28 a unos 14 días (Wheeler et al., 2008), con un semillero que solo necesita del 1% al 10% del área de las plantas maduras; sus modelos de crecimiento de lechuga se limitan a 200-500 µmol/m2/s porque se recomienda una integral de luz de solo 17 mol/m2/d para evitar la quemadura de las puntas de las hojas. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 26 | Deep Space Food Challenge de la CSA | En el Deep Space Food Challenge (Agencia Espacial Canadiense e Impact Canada, en colaboración con la NASA), el jurado eligió en febrero de 2024 a Ecoation Innovative Solutions Inc., con sede en Vancouver, como ganadora del gran premio, con $380,000 en fondos de subvención, por su CANGrow Modular Indoor Food Production System, que podría producir más de 700 kg de alimentos ricos en nutrientes al año (fresas, jitomates cherry, sustituto de carne a base de micelio, etc.). | Verificado | <https://www.asc-csa.gc.ca/eng/sciences/food-production/deep-space-food-challenge.asp> |
| 27 | Proyecto Naurvik de la CSA | Naurvik ('el lugar donde crecen las cosas' en inuktitut) es un sistema comunitario de producción de alimentos en Gjoa Haven, Nunavut, unos 250 km al norte del Círculo Polar Ártico, que opera desde octubre de 2019 en tres contenedores de carga reciclados y adaptados como Grow Pod, Utility Pod y Power Pod, alimentados casi por completo con fuentes renovables como la eólica y la solar; su primera cosecha fue lechuga mantequilla y microvegetales. | Verificado | <https://www.asc-csa.gc.ca/eng/sciences/food-production/naurvik-project-in-nunavut.asp> |
| 28 | Análogo CHAPEA: tripulación, duración, hábitat | Cada misión CHAPEA de la NASA pone a cuatro tripulantes en un hábitat aislado e impreso en 3D de 1,700 pies cuadrados (unos 158 m2, derivado) en el Johnson Space Center durante 378 días: la Misión 1 fue del 25 de junio de 2023 al 6 de julio de 2024 y la Misión 2 del 19 de octubre de 2025 al 31 de octubre de 2026 (ya concluida); el hábitat tiene habitaciones privadas para la tripulación, una cocina, áreas dedicadas a medicina, recreación, acondicionamiento físico, trabajo y cultivo, un área de trabajo técnico y dos baños. | Verificado | <https://www.nasa.gov/humans-in-space/chapea/> |
| 29 | Retraso de comunicación en CHAPEA | El artículo de la NASA del 10 de julio de 2024 sobre el final de la Misión 1 de CHAPEA dice que la misión usó retrasos de comunicación realistas para Marte de hasta 44 minutos ida y vuelta (es decir, hasta 22 minutos en un solo sentido, derivado); un reportaje de la NASA del 11 de julio de 2024 cita de forma imprecisa un 'retraso de transmisión de aproximadamente una hora'. El artículo de la NASA del 19 de octubre de 2026 sobre la Misión 2 dice que los datos podrían ayudar a tripulaciones que enfrenten retrasos de comunicación de hasta 45 minutos en cada sentido, sin indicar el retraso que realmente se simuló en el hábitat; la Misión 2 también incluyó un apagón de comunicaciones simulado de dos semanas. | Corregido | <https://www.nasa.gov/missions/analog-field-testing/chapea/first-mars-crew-completes-yearlong-simulated-red-planet-nasa-mission/> |
| 30 | Periodos reales de crecimiento de cultivos (Tabla 4-89 de la BVAD) | La Tabla 4-89 de la BVAD Rev2 enumera periodos nominales de crecimiento en días después de la siembra: lechuga 28, rábano 25, espinaca 30, acelga 45, jitomate 85, pimiento 85, trigo 75-90, soya 97, fresa 100, papa blanca 132; la lechuga y el rábano usan un fotoperiodo de 16 h/día a 23 °C. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 31 | Rendimiento de cultivos, oxígeno y agua por metro cuadrado (Tablas 4-90 y 4-91 de la BVAD) | Valores nominales de cultivos de la BVAD Rev2 por metro cuadrado de área de cultivo por día: la lechuga rinde 131.35 g de masa comestible fresca (6.57 g secos), produce 7.78 g de O2, absorbe 10.70 g de CO2 y usa 2.10 kg de agua; rábano 91.67 g comestibles frescos, 11.86 g de O2, 1.77 kg de agua; jitomate 173.76 g comestibles frescos, 26.36 g de O2, 2.77 kg de agua; trigo 20.00 g comestibles secos, 56.00 g de O2, 77.00 g de CO2 absorbido, 11.79 kg de agua. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 32 | Potencia de una cámara de cultivo por área (Tabla 4-88 de la BVAD) | La Tabla 4-88 de la BVAD Rev2 (de Drysdale 1999) estima que una cámara de cultivo de plantas requiere 2.6 kW de potencia eléctrica y 2.6 kW de control térmico por metro cuadrado de área de cultivo, de los cuales las lámparas son 2.1 kW/m2, con una masa total de 101.5 kg/m2 y 13.1 horas-tripulante por m2 al año. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 33 | Masa, potencia y producción de plantas ISRU (Tabla 4-85 de la BVAD) | La Tabla 4-85 de la BVAD Rev2 enumera sistemas ISRU conceptuales: una planta lunar de oxígeno a partir de agua polar que produce 1 tonelada métrica de O2 y 0.125 t de H2 al año tiene una masa de sistema de 1.2 t y necesita 6.7 kW; una planta lunar de oxígeno a partir de regolito que produce 10 t de O2/año pesa 2.7 t y necesita 11.8 kW; una planta marciana solo de oxígeno que produce 22.7 t de O2/año pesa 0.93 t y necesita unos 32 kW; una planta marciana de metano + oxígeno + agua (24.6 t de O2, 3.1 t de H2O y 7.0 t de CH4 al año) pesa 2.2 t y necesita unos 80 kW. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 34 | Flujos de aguas residuales que recoge un reciclador (Tabla 3-31 de la BVAD) | La Tabla 3-31 de la BVAD Rev2 da, por tripulante por día: agua de la orina 1.420 kg (rango de 0.8 a 2.45), agua de la respiración y la transpiración 2.946 kg, y agua fecal 0.101 kg. | Verificado | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 35 | Producción de oxígeno del OGA a lo largo de su vida | Al 13 de mayo de 2024, el Ensamble de Generación de Oxígeno de la ISS había producido un total de 13,288 kg (29,296 lbm) de oxígeno y 1,661 kg (3,662 lbm) de hidrógeno desde su activación inicial en 2007. | Verificado | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 36 | Agua en la Luna iluminada por el Sol (SOFIA) | La NASA anunció el 26 de octubre de 2020 que SOFIA detectó moléculas de agua en el cráter Clavius, en la superficie lunar iluminada por el Sol, en concentraciones de 100 a 412 partes por millón, más o menos una botella de agua de 12 onzas en un metro cúbico de suelo; el desierto del Sahara tiene 100 veces esa cantidad. | Verificado | <https://www.nasa.gov/news-release/nasas-sofia-discovers-water-on-sunlit-surface-of-moon/> |
| 37 | Rábanos y chiles en el Advanced Plant Habitat | En el APH, la astronauta de la NASA Kate Rubins cosechó 20 plantas de rábano el 30 de noviembre de 2020 (PH-02; los rábanos maduran en 27 días y se enviaron de regreso a la Tierra); PH-04 comenzó el 12 de julio de 2021 con 48 semillas de chile Hatch, con un crecimiento previsto de unos cuatro meses, y el 29 de octubre de 2021 la tripulación probó siete chiles, la primera vez que astronautas comieron chiles cultivados en el espacio. | Verificado | <https://www.nasa.gov/missions/station/astronauts-harvest-radish-crop-on-international-space-station/> |

<details><summary>Notas de verificación de esta sección</summary>

Método: abrí personalmente cada fuente. Los PDF de la NASA (BVAD Rev2, hoja informativa de ECLSS de 2025, hojas informativas de Veggie y del APH, artículos sobre el OGA de ICES 2024 y 2023, artículo sobre el OGS de 2008, artículo sobre CO2 de ICES 2026) se descargaron y se les extrajo el texto con pdftotext solo en el espacio temporal de la sesión; no se escribió nada en el proyecto. Las páginas web se leyeron con una herramienta de descarga que devuelve fragmentos citados breves, así que las citas que aparezcan en pantalla deben volver a cotejarse con la página.  Resultado: se revisaron 29 datos del investigador. 26 verificados, 2 corregidos, 1 se mantiene como NO ENCONTRADO/sin verificar, 0 descartados. Se agregaron 8 datos.  Correcciones: 1. Tabla 4-20 de la BVAD: el "total de la ISS de 3.2 kg/CM-d" del investigador corresponde a la columna del vehículo de tránsito. El total de la columna de la ISS es 5.38 kg/CM-d porque incluye 2.18 kg/CM-d de agua de carga útil. Se confirman los valores de 4.48 para la base inicial y 9.12 para la base madura (la extracción en modo tabla de la página 86 del PDF da columnas limpias). 2. Retraso de comunicación de CHAPEA: la cifra de 22 minutos en un solo sentido está respaldada por la NASA. El artículo de la NASA del 10 de julio de 2024 sobre la conclusión de la Misión 1 dice "hasta 44 minutos ida y vuelta". El artículo del 19 de octubre de 2026 sobre la Misión 2 no dice que la tripulación experimentara 45 minutos en cada sentido; esa oración trata de datos que ayudan a tripulaciones con retrasos de esa magnitud. No se encontró la duración del retraso simulado en la Misión 2. Usar 44 minutos ida y vuelta.  Mejorados desde solo fragmento: el 5.6 ± 2.9% de hielo de agua en masa y los 155 ± 12 kg de LCROSS se confirman con el resumen del artículo de Science en el registro de publicaciones de la Universidad de Arizona (science.org devolvió 403; PubMed bloqueó la herramienta de descarga). Aplica solo al sitio de impacto de Cabeus.  Aún no encontrado: la potencia de los racks del ECLSS de la ISS (OGA, CDRA, WRS). Dos pistas no abiertas, tomadas de fragmentos de búsqueda, no coinciden (fuente de alimentación del OGA de "más de 3800 Watts" en ICES-2020-190; "1.5 kW" en un póster de NIAC de 2025); ambos PDF superaron el límite de tamaño de descarga. No mostrar ninguna de las dos. Cifras de potencia reales publicadas disponibles en su lugar: MOXIE 300 W, Veggie 70 W, cámara de cultivo de la BVAD 2.6 kW/m2 (estimación de 1999 con lámparas HPS), plantas conceptuales ISRU de la BVAD (6.7 kW para 1 t de O2/año a partir de agua polar lunar; ~32 kW para 22.7 t de O2/año en Marte).  Vigencia a finales de 2026: la Misión 2 de CHAPEA terminó el 31 de octubre de 2026 (artículo con imagen de la NASA del 10 de noviembre de 2026), así que debe describirse como concluida. MOXIE ya terminó (última corrida el 7 de agosto de 2023). La recuperación de agua del 98% es un hito de 2023 y el total de 13,288 kg del OGA es una instantánea del 13 de mayo de 2024; ninguno de los dos es un dato en vivo. El conteo de Veggie de "15 tipos de plantas / 8 hortalizas de hoja" corresponde a la hoja informativa de 2020.  Valores derivados (no están en las fuentes; etiquetar como derivados): ~3,050 kcal a partir de 12.778 MJ; ~144 W a partir de 12.426 MJ/día; 3.8 L por galón; -157 C a partir de -250 F; 158 m2 a partir de 1,700 pies cuadrados; 1.9 kg/día a partir de 700 kg/año; 22 min en un solo sentido a partir de 44 min ida y vuelta; Wh por gramo de MOXIE y unidades por persona; 109 días para la primera cosecha de chiles; 130 kW para 50 m2 de cultivos; 16 m2 de trigo para el oxígeno de una persona.  Otras precauciones: según el artículo del OGA de 2024, el rack del OGS se trasladó del Nodo 3 (Tranquility) al Laboratorio de EE. UU. en septiembre de 2022, aunque la hoja informativa de 2025 todavía dice que los racks están en Tranquility. El artículo de 2008 da un rango de corriente del OGA de 10-55 A; el de 2024, de 10-46.9 A. La cifra de lechuga de la BVAD de "28 a ~14 días" es el tiempo en el área de cultivo principal con un semillero separado. La fuente de CO2 de ICES 2026 es una presentación tipo diapositivas. La tabla de CO2 por persona del documento técnico de la OCHMO tiene encabezados de unidades inconsistentes, así que se usa el valor de la BVAD de 1.085 kg/día.

</details>

#### Radiación y clima espacial

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Tasa de dosis - superficie de la Tierra | La EPA (citando al NCRP) indica que la dosis de radiación anual promedio por persona en EE. UU. es de 6.2 mSv (620 mrem). La EPA dice que la mayor parte proviene de fuentes naturales de fondo y que el 48 por ciento proviene de procedimientos médicos. | Verificado | <https://www.epa.gov/radiation/radiation-sources-and-doses> |
| 2 | Tasa de dosis - ISS | Zhang et al. 2020 (Science Advances) citan una dosis equivalente dentro de la ISS de 731 microsieverts por día, de los cuales 523 microsieverts por día provienen de rayos cósmicos galácticos, e indican que la dosis equivalente de GCR en la superficie lunar es aproximadamente 2.6 veces mayor que dentro de la ISS. | Verificado | <https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/> |
| 3 | Tasa de dosis - tránsito en espacio profundo (crucero de MSL RAD) | Durante el crucero de Curiosity hacia Marte, el instrumento RAD, dentro de la nave, midió una dosis equivalente promedio de rayos cósmicos galácticos de 1.8 mSv por día; el JPL la compara con una tomografía de cuerpo completo cada cinco o seis días y dice que solo alrededor del tres por ciento de la dosis provino de partículas solares. | Verificado | <https://www.jpl.nasa.gov/news/data-from-nasa-rovers-voyage-to-mars-aids-planning/> |
| 4 | Tasa de dosis - superficie de Marte (RAD de Curiosity) | En la superficie marciana (cráter Gale), RAD midió una tasa promedio de dosis equivalente de GCR de 0.67 mSv por día entre agosto de 2012 y junio de 2013. | Verificado | <https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars> |
| 5 | Tasa de dosis - superficie lunar (LND de Chang'e-4) | El experimento Lunar Lander Neutrons and Dosimetry de Chang'e-4 midió una dosis equivalente promedio de 1,369 microsieverts por día en la superficie lunar (tasa de dosis equivalente de partículas cargadas de GCR 57.1 +/- 10.6 uSv/hora; tasa de dosis absorbida total en silicio 13.2 +/- 1 uGy/hora; factor de calidad promedio 4.3 +/- 0.7; partículas neutras 23 +/- 8% de la dosis total), con datos tomados del 3 al 12 de enero y del 31 de enero al 10 de febrero de 2019. | Verificado | <https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/> |
| 6 | Tasa de dosis - Luna (CRaTER de LRO) | CRaTER de LRO (Schwadron et al. 2012, JGR 117, E00H13) reporta una tasa máxima observada de dosis absorbida de GCR de unos 11.7 cGy por año durante el mínimo solar profundo, las tasas de dosis más altas observadas en la era espacial. El artículo indica que sus tasas de dosis están referidas a la superficie lunar (corregidas por altitud) y ajustadas a la deposición de dosis en agua, detrás de unos 0.22 g/cm2 de Al. Esto es dosis absorbida (Gy), no dosis equivalente (Sv). | Corregido | <https://prediccs.sr.unh.edu/papers/schwadron2011JE003978.pdf> |
| 7 | Límite de la NASA - carrera | Requisito [V1 4030] de la NASA-STD-3001 Volumen 1: la dosis efectiva total de radiación de toda la carrera de un tripulante, debida a la exposición a la radiación de los vuelos espaciales, deberá ser menor de 600 mSv; el límite es universal para todas las edades y sexos (fijado para mantenerse por debajo de un riesgo medio del 3% de muerte por cáncer inducida por la exposición). Valor idéntico en la Rev B (2022-01-05) y en la Rev C vigente (aprobada el 2023-09-15). | Verificado | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 8 | Límite de la NASA - 30 días y 1 año | Límites de dosis no cancerígenos de corto plazo y de carrera de la NASA-STD-3001 Vol 1: órganos formadores de sangre 250 mGy-Eq (30 días) y 500 mGy-Eq (1 año), carrera no aplica; piel 1,500 / 3,000 / 6,000 mGy-Eq; cristalino 1,000 / 2,000 / 4,000 mGy-Eq; sistema circulatorio 250 / 500 / 1,000 mGy-Eq (30 días / 1 año / carrera). Tabla 3 en la Rev B; Tabla 4.8-1 en la Rev C vigente, con los mismos valores para estos órganos. | Verificado | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 9 | Límite de la NASA - límite de diseño para eventos de partículas solares | NASA-STD-3001 [V1 4031]: el programa deberá proteger a los tripulantes de la exposición al espectro de energía de protones del entorno del evento de partículas solares de referencia de diseño (la suma de los eventos de octubre de 1989) a menos de una dosis efectiva NASA de 250 mSv; el documento técnico de la OCHMO lo resume como 250 mSv por evento. | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 10 | Entorno diario de referencia usado por la norma de la NASA | La NASA-STD-3001 Vol 1 indica que, para una misión en superficie (fuente de la cifra: un análisis de misión humana a Marte), la exposición al entorno de radiación espacial es de aproximadamente 0.5 mSv por día, y usa 1.5 mSv/día en su ejemplo de tránsito a Marte (1.5 mSv/día x 90 días = 135 mSv). La Rev C además identifica 1.5 mSv/día como la tasa de dosis efectiva de GCR en el espacio libre, sin blindaje, en el mínimo solar. | Verificado | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 11 | GCR frente a SPE | Según NASA OCHMO-TB-020: los rayos cósmicos galácticos se presentan de forma continua, llegan desde todas las direcciones, son menores durante el máximo solar y no responden al blindaje (solo una reducción promedio del 7% de la dosis con aluminio/polietileno), mientras que los eventos de partículas solares son ráfagas poco frecuentes de protones de energía baja a media que ocurren sobre todo durante el máximo solar, contra los cuales el aluminio y el polietileno dan una reducción promedio del 50% de la dosis. | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 12 | SPE real en Marte - septiembre de 2017 | Un evento solar del 11 de septiembre de 2017 produjo niveles de radiación en la superficie marciana más del doble de cualquiera medido antes por el RAD de Curiosity, con lecturas altas que duraron más de dos días, y una aurora global más de 25 veces más brillante que cualquiera vista antes por MAVEN. | Verificado | <https://www.jpl.nasa.gov/news/large-solar-storm-sparks-global-aurora-and-doubles-radiation-levels-on-the-martian-surface/> |
| 13 | SPE real en Marte - 20 de mayo de 2024 | El 20 de mayo de 2024, una llamarada solar que después se estimó como X12 (según datos de Solar Orbiter) alcanzó Marte; fue el mayor aumento medido por el RAD de Curiosity desde su aterrizaje, y un astronauta parado junto al rover habría recibido 8,100 micrograys, equivalentes a 30 radiografías de tórax; las partículas cargadas llegaron a Marte en decenas de minutos. | Verificado | <https://www.jpl.nasa.gov/news/nasa-watches-mars-light-up-during-epic-solar-storm/> |
| 14 | Evento de agosto de 1972 | Un video de NASA Goddard indica que la intensa radiación solar de agosto de 1972 ocurrió justo entre las misiones Apollo 16 y Apollo 17, cuando no había astronautas en su camino. | Verificado | <https://svs.gsfc.nasa.gov/vis/a010000/a013200/a013275/AstronautRadiation.en_US.srt> |
| 15 | Tormenta geomagnética G5 de mayo de 2024 | La tormenta de mayo de 2024 alcanzó G5, el nivel más alto de la escala de tormentas geomagnéticas, que no se veía desde 2003; SDO observó 82 llamaradas notables del 3 al 9 de mayo de 2024, al menos siete CME dirigidas hacia la Tierra del 7 al 11 de mayo a velocidades de hasta 3 millones de mph, y DONKI registra Kp 9.0 el 2024-05-11T00:00Z, 03:00Z y 12:00Z (gstID 2024-05-10T15:00:00-GST-001, fuente NOAA). | Verificado | <https://science.nasa.gov/science-research/heliophysics/how-nasa-tracked-the-most-intense-solar-storm-in-decades/> |
| 16 | Eventos reales de DONKI - llamaradas más fuertes de 2024 | DONKI registra una llamarada X9.0 con pico el 2024-10-03T12:18Z en la región activa 13842 (la más fuerte en DONKI para el periodo 2024-01-01 a 2026-11-14), una X8.7 con pico el 2024-05-14T16:51Z en la AR 13664 y una X5.8 con pico el 2024-05-11T01:23Z en la AR 13664. | Verificado | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2024-10-01&endDate=2024-10-05> |
| 17 | Eventos reales de DONKI - noviembre de 2025 | DONKI registra una llamarada X5.1 (inicio 2025-11-11T09:49Z, pico 10:04Z, AR 14274) y un evento de protones GOES >100 MeV registrado el 2025-11-11T10:20Z, es decir, 31 minutos después del inicio de la llamarada y 16 minutos después de su pico. Por separado, DONKI registra una tormenta geomagnética que alcanzó Kp 8.67 el 2025-11-12T03:00Z, que DONKI vincula con CME anteriores del 7, 9 y 10 de noviembre (la CME del 10 de noviembre llegó con una llamarada X1.2), no con la CME de la llamarada X5.1; la CME de la X5.1 (2025-11-11T10:23Z) está vinculada con una segunda tormenta (gstID 2025-11-12T18:00:00-GST-001) que tuvo su pico en Kp 7.33. | Corregido | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/GST?startDate=2025-11-10&endDate=2025-11-14> |
| 18 | Eventos reales de DONKI - enero de 2026 (tormenta de radiación S4) | DONKI registra una llamarada X1.9 con pico el 2026-01-18T18:09Z (AR 14341, inicio 17:27Z) con una CME vinculada (inicio 18:09Z) analizada a 1,820 km/s, un evento de protones GOES >10 MeV el 2026-01-18T22:55Z, un choque interplanetario en la Tierra el 2026-01-19T18:55Z (24 h 46 min después del inicio de la CME) y Kp 8.67 el 2026-01-20T00:00Z; NOAA SWPC informó de una tormenta de radiación solar S4 (Severa) en curso el 19 de enero de 2026, un nivel que no se observaba desde octubre de 2003. | Verificado | <https://www.spaceweather.gov/news/s4-severe-solar-radiation-storm-progress-january-19th-2026> |
| 19 | Eventos reales de DONKI - llamaradas de 2026 y ventana más reciente | DONKI registra una llamarada X8.1 con pico el 2026-02-01T23:57Z en la AR 14366, que produjo seis llamaradas de clase X del 1 al 4 de febrero de 2026 (X1.0, X8.1, X2.8, X1.6, X1.5, X4.2); para el periodo 2026-10-01 a 2026-11-10, DONKI devuelve 22 llamaradas, la más fuerte M6.7 (pico 2026-10-08T15:48Z, AR 14549), ninguna llamarada de clase X y ningún evento SEP. | Verificado | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2026-10-01&endDate=2026-11-10> |
| 20 | Llamarada solar (definición en una línea + llegada) | Una llamarada solar es una ráfaga intensa de radiación, o luz, en el Sol; su energía viaja a la velocidad de la luz y llega a la Tierra unos 8 minutos después de que ocurre la llamarada; las llamaradas se clasifican en A, B, C, M y X, y cada clase superior representa un aumento de 10 veces en la energía. | Verificado | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 21 | Eyección de masa coronal (definición en una línea + llegada) | Una eyección de masa coronal es una enorme nube de gas con carga eléctrica, llamado plasma, que el Sol expulsa en una erupción; cuando se dirige a la Tierra, las más rápidas pueden llegar en tan solo 15 horas y las más lentas tardan varios días. | Verificado | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 22 | Partículas solares energéticas (definición en una línea + llegada) | En una tormenta de radiación, las erupciones solares aceleran partículas cargadas (electrones y protones) hacia el espacio a velocidades muy altas; las más rápidas pueden recorrer los aproximadamente 93 millones de millas del Sol a la Tierra en unos 30 minutos o menos. | Verificado | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 23 | Blindaje - espesor equivalente en agua de un refugio contra tormentas | NASA OCHMO-TB-020: un refugio contra tormentas con 10 cm adicionales de equivalente en agua protege contra un evento de partículas solares centenario (1 en 100 años) y se necesitan unos 20 cm de equivalente en agua para un evento de 1 en 1,000 años; las misiones de más de 6 meses deberían tener un blindaje del vehículo de al menos 20 g/cm2. La NASA-STD-3001 Vol 1 (Tabla 6 en la Rev B, Tabla 4.8-4 en la Rev C) recomienda un blindaje contra SPE de 10 cm (o g/cm2) de equivalente en agua alrededor del tripulante en una superficie celeste (cualquier duración), 15 cm más allá de LEO por menos de 6 meses y 20 cm más allá de LEO por más de 6 meses. | Verificado | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 24 | Blindaje - efecto de bolsas de agua / carga estibada | Tabla de trazado de rayos del OCHMO-TB-020 para un SPE más allá de la órbita terrestre baja en una cápsula: dosis efectiva según la ubicación del tripulante de 214 / 210 / 259 / 231 mSv, que baja a 68 / 65 / 66 / 66 mSv al usar como refugio la carga estibada optimizada antes del lanzamiento (83 / 75 / 73 / 83 mSv con la carga estibada optimizada para el regreso). | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 25 | Blindaje - cubierta de regolito | Matthia y Berger 2024 (Space Weather 22, e2024SW004095; modelo Geant4): más de 4 g/cm2 de regolito reduce la dosis de un evento de partículas solares por debajo de los límites actuales de 30 días y más de 10 g/cm2 da un margen de seguridad del doble. Para GCR en el mínimo solar, la dosis equivalente modelada es de 0.84 mSv/día (310 mSv/año) sin blindaje (solo traje espacial), baja a un mínimo local de 0.6 mSv/día (220 mSv/año) a unos 20 g/cm2, sube a 0.65 mSv/día (240 mSv/año) a 90 g/cm2 y queda en 0.55 mSv/día (200 mSv/año) a 180 g/cm2. La densidad del regolito en el modelo es de 3 g/cm3. | Corregido | <https://elib.dlr.de/210448/1/ME-SBA-2024-Matthi%C3%A4-Berger%20Radiation%20Exposure%20and%20Shielding%20Effects%20on%20the%20Lunar%20Surface-SPACE%20WEATHER.pdf> |
| 26 | Procedimiento de refugio contra tormentas de Orion | Durante un evento de partículas solares, la tripulación de Orion se colocaría en la parte central del módulo de tripulación y armaría un refugio con las bolsas de carga a bordo, construyéndolo en menos de una hora, y podría tener que permanecer dentro hasta 24 horas; el Hybrid Electronic Radiation Assessor (HERA) integrado en Orion da un aviso si la tripulación necesita refugiarse. | Verificado | <https://www.nasa.gov/humans-in-space/scientists-and-engineers-evaluate-orion-radiation-protection-plan/> |
| 27 | Tiempo de aviso / regla de EVA | OCHMO-TB-020: los tiempos de desarrollo de los SPE dejan tiempo suficiente para reconfigurar el refugio; la dosimetría de alerta en tiempo real da un nivel de protección muy alto si la EVA se termina en menos de 2 horas; una gran mayoría (~95%) de los SPE solo requiere consideraciones ALARA y no se acerca a los límites de dosis; la probabilidad de dosis en órganos durante una EVA de más de 100 mSv es menor de una en un millón. | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 28 | Endpoints de DONKI en api.nasa.gov | api.nasa.gov documenta DONKI en https://api.nasa.gov/DONKI/{CME\|CMEAnalysis\|GST\|IPS\|FLR\|SEP\|MPC\|RBE\|HSS\|WSAEnlilSimulations\|notifications} con startDate y endDate (yyyy-MM-dd; por defecto desde 30 días antes de la fecha UTC actual hasta la fecha actual; 7 días para WSAEnlilSimulations y notifications) y api_key; CMEAnalysis agrega mostAccurateOnly, completeEntryOnly, speed, halfAngle, catalog y keyword; IPS agrega location y catalog; notifications agrega type (all, FLR, SEP, CME, IPS, MPC, GST, RBE, report) y su rango está limitado a 30 días. | Verificado | <https://api.nasa.gov/assets/json/apis.json> |
| 29 | Endpoints de DONKI en el servidor del CCMC (sin clave) y estado actual | Los mismos datos se sirven sin clave de API en https://ccmc.gsfc.nasa.gov/DONKI/WS/get/{FLR\|SEP\|GST\|CME\|CMEAnalysis\|IPS\|notifications}?startDate=...&endDate=... (también en https://ccmc.gsfc.nasa.gov/DONKI-API/get/FLR). El 2026-11-14 este servidor rechazó un rango de más de 60 días con HTTP 400 ('API Error: Date range cannot exceed 60 days'), devolvió un encabezado X-Rate-Limit-Remaining: 119, y el antiguo servidor kauai.ccmc.gsfc.nasa.gov agotó el tiempo de espera; el CCMC indica sustituir kauai.ccmc.gsfc.nasa.gov por ccmc.gsfc.nasa.gov. NO se pudo volver a probar el reporte del investigador de que https://api.nasa.gov/DONKI/FLR devolvía 404 mientras GST y SEP devolvían 200. | Verificado | <https://ccmc.gsfc.nasa.gov/tools/DONKI/> |
| 30 | Límites de solicitudes de api.nasa.gov | api.nasa.gov documenta para DEMO_KEY límites de 30 solicitudes por dirección IP por hora y 50 por dirección IP por día, frente a un límite predeterminado de 1,000 solicitudes por hora con una clave registrada; el uso se informa en los encabezados X-RateLimit-Limit y X-RateLimit-Remaining. Las respuestas en vivo con DEMO_KEY del 2026-11-14 traían X-Ratelimit-Limit: 10. Según el manual para desarrolladores de api.data.gov, la clave puede enviarse en el encabezado HTTP X-Api-Key, como parámetro de consulta api_key o como nombre de usuario de autenticación básica HTTP. | Verificado | <https://api.nasa.gov/assets/html/authentication.html> |
| 31 | Campos JSON de DONKI - FLR | Cada registro FLR contiene flrID, catalog, instruments[].displayName, beginTime, peakTime, endTime, classType (p. ej., 'M6.7'), sourceLocation, activeRegionNum, note, link, linkedEvents[].activityID, sentNotifications, submissionTime y versionId; las horas son cadenas UTC como 2026-10-08T15:48Z. | Verificado | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2026-10-01&endDate=2026-11-10> |
| 32 | Campos JSON de DONKI - GST y SEP | Los registros GST contienen gstID, startTime, allKpIndex[] (cada uno con observedTime, un kpIndex como 8.67 y source 'NOAA'), link, linkedEvents, sentNotifications, submissionTime y versionId; los registros SEP contienen sepID, eventTime, instruments[].displayName (p. ej., 'GOES-P: SEISS >10 MeV', 'GOES-P: SEISS >100 MeV', 'SOHO: COSTEP 15.8-39.8 MeV', 'MODEL: REleASE:...'), link, linkedEvents, sentNotifications, submissionTime y versionId. Los registros SEP no incluyen ningún valor de flujo ni de dosis. | Verificado | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/GST?startDate=2024-05-08&endDate=2024-05-14> |
| 33 | Redacción de atribución / licencia | La NASA dice que, en general, su contenido no está sujeto a derechos de autor en Estados Unidos y puede usarse con fines educativos o informativos, siempre que se reconozca a la NASA como fuente y no se implique respaldo; la insignia, el logotipo y los identificadores de la NASA no son de dominio público. Las notificaciones de DONKI incluyen la advertencia de que el Space Weather Prediction Center de la NOAA es la fuente oficial del Gobierno de Estados Unidos para los pronósticos de clima espacial y de que DONKI es 'Experimental Research Information' que consiste en productos preliminares de investigación de la NASA; la página del CCMC dice que los datos de DONKI se ofrecen 'tal cual', sin garantía, y que los opera principalmente la Moon-to-Mars Space Weather Analysis Office. | Verificado | <https://www.nasa.gov/nasa-brand-center/images-and-media/> |
| 34 | API de dosimetría de la ISS de RadLab / OSDR | NASA OSDR RadLab ofrece una API GET en https://visualization.osdr.nasa.gov/radlab/api que acepta filtros como spacecraft, module (solo ISS), instrument y timestamp, y devuelve los campos absorbed_dose_rate (uGy/hora), dose_equivalent_rate (uSv/hora), flux (cm-2 sr-1 s-1) y de posición en csv (predeterminado), tsv, json o html; los instrumentos de ejemplo documentados incluyen TEPC, IV-TEPC, ALTEA, Liulin-5, Lidal, REM y DosTel. Una consulta en vivo sin clave para la ISS con instrument=DosTel el 2022-04-01 devolvió 2,389 lecturas que abarcan tanto DosTel1 como DosTel2. | Verificado | <https://visualization.osdr.nasa.gov/radlab/gui/data-api/> |
| 35 | HttpService de Roblox | Los servidores de experiencias de Roblox pueden enviar solicitudes HTTP a servicios web de terceros con HttpService GetAsync / PostAsync / RequestAsync; estos métodos no están habilitados por defecto y requieren activar 'Allow HTTP Requests' en File > Experience Settings > Security en Studio. Las solicitudes externas se limitan a 500 por minuto por servidor de juego (las solicitudes de Open Cloud tienen un límite aparte de 2,500 por minuto); se bloquean el puerto 1194 y los puertos menores a 1024, excepto el 80 y el 443; Roblox aconseja envolver las llamadas en pcall y prever fallas. Los secretos (HttpService:GetSecret) pueden guardar una clave de API, pero no están disponibles cuando la experiencia se ejecuta localmente. | Verificado | <https://create.roblox.com/docs/cloud-services/http-service> |
| 36 | Límite de diseño de la NASA para GCR (norma vigente) | La NASA-STD-3001 Vol 1 Rev C (aprobada el 2023-09-15) agrega el requisito [V1 4033]: para sistemas espaciales habitables diseñados para sostener a una tripulación más de 60 días, el programa deberá proteger a los tripulantes del entorno de rayos cósmicos galácticos a una tasa de dosis efectiva NASA menor de 1.3 mSv/día para sistemas en el espacio libre y menor de 0.9 mSv/día para sistemas en superficies planetarias. Justificación: el blindaje puede reducir la tasa de dosis efectiva de GCR en el espacio libre sin blindaje, de 1.5 mSv/día, en aproximadamente un 15%, hasta 1.3 mSv/día; las reducciones se logran con 10-40 g/cm2, mientras que 40-100 g/cm2 tiene un efecto insignificante o negativo. | Verificado | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 37 | Escalas de clima espacial de la NOAA (G, S, R) | Escalas de la NOAA: las tormentas geomagnéticas G1-G5 corresponden a Kp 5, 6, 7, 8 (incluido 9-) y 9; las tormentas de radiación solar S1-S5 corresponden a un flujo de protones >=10 MeV de 10, 10^2, 10^3, 10^4 y 10^5 pfu, con S3 'se recomienda evitar el peligro de radiación para astronautas en EVA' y S4 'peligro de radiación inevitable para astronautas en EVA'; los apagones de radio R1-R5 corresponden a una clase de pico de rayos X de GOES de M1, M5, X1, X10 y X20. | Verificado | <https://www.spaceweather.gov/noaa-scales-explanation> |
| 38 | Fondo natural mundial (UNSCEAR 2026) | El informe de UNSCEAR publicado el 12 de febrero de 2026 estima la dosis efectiva anual promedio mundial por fuentes naturales en aproximadamente 3.0 mSv (inhalación de radón/torón 1.8 mSv, ingestión 0.5 mSv, externa terrestre 0.4 mSv, radiación cósmica 0.3 mSv); el aumento respecto a los 2.4 mSv reportados antes (UNSCEAR 2008) refleja mejores datos y métodos, no un aumento real. | Verificado | <https://unis.unvienna.org/unis/en/pressrels/2026/unisous453.html> |
| 39 | Fuentes JSON en tiempo real de NOAA SWPC (realmente en vivo) | NOAA SWPC ofrece JSON casi en tiempo real y sin clave: Kp planetario en https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json (valores cada 3 horas, campos time_tag, Kp, a_running, station_count), flujo integral de protones de GOES en https://services.swpc.noaa.gov/json/goes/primary/integral-protons-1-day.json (valores cada 5 minutos para los canales >=1, >=10, >=50, >=60, >=100 y >=500 MeV), flujo de rayos X de GOES en https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json (valores a intervalos de 1 minuto, 0.05-0.4 nm y 0.1-0.8 nm), y niveles actuales y pronosticados de las escalas R, S y G en https://services.swpc.noaa.gov/products/noaa-scales.json. | Verificado | <https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json> |
| 40 | Dosis de una misión completa a Marte frente al límite de carrera | El SwRI (institución del investigador principal de RAD) indica que, a las tasas medidas por RAD, el total solo durante las fases de tránsito de una misión a Marte sería de aproximadamente 0.66 Sv para un viaje redondo, y una estancia de 500 días en la superficie llevaría la exposición total a alrededor de 1 Sv. | Verificado | <https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars> |
| 41 | Mediciones de radiación de Artemis I dentro de Orion | La NASA informa que Artemis I llevó 5,600 sensores pasivos y 34 detectores activos de radiación dentro de Orion (incluidos HERA y el Crew Active Dosimeter de la NASA, el Active Dosimeter de la ESA y los torsos de maniquí MARE), midió distintos niveles de radiación en áreas con distinto blindaje y vio que los niveles de radiación bajaron casi a la mitad cuando Orion cambió su orientación durante un encendido del motor de la Interim Cryogenic Propulsion Stage. | Verificado | <https://www.nasa.gov/humans-in-space/artemis-i-radiation-measurements-validate-orion-safety-for-astronauts/> |
| 42 | La equivalencia en radiografías de tórax no es consistente entre páginas de la NASA | La página 'Why Space Radiation Matters' de la NASA indica que los astronautas se exponen a dosis efectivas de 50 a 2,000 mSv y que 1 mSv de radiación ionizante equivale a unas 10 radiografías de tórax; la página del JPL sobre Marte de mayo de 2024 equipara 8,100 micrograys a 30 radiografías de tórax (unos 0.27 mGy por radiografía). | Verificado | <https://www.nasa.gov/analogs/nsrl/why-space-radiation-matters> |
| 43 | Registros SEP de DONKI: muchas entradas por evento y horas de cruce de umbral | En DONKI, un solo evento de partículas solares aparece como varios registros SEP, uno por instrumento y canal de energía, incluidas entradas de modelo etiquetadas 'MODEL: REleASE:...'; por ejemplo, la actividad del 10 al 12 de noviembre de 2025 tiene 16 registros SEP y la tormenta del 18 al 21 de enero de 2026 tiene 9. De los 214 registros SEP del periodo 2024-01-01 a 2026-11-14, solo 9 son eventos GOES >100 MeV (2024-02-12, 2024-05-11, 2024-06-08, 2024-07-23, 2024-10-09, 2024-11-21, 2025-11-11, 2026-07-30, 2026-09-05). | Verificado | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/SEP?startDate=2025-11-10&endDate=2025-11-13> |

<details><summary>Notas de verificación de esta sección</summary>

MÉTODO. Todo lo marcado como verificado lo abrí personalmente el 2026-11-14: páginas web mediante descarga, PDF descargados al espacio temporal de la sesión con extracción de texto (NASA-STD-3001 Vol 1 Rev B y Rev C, OCHMO-TB-020, Matthia y Berger 2024, Schwadron et al. 2012) y llamadas GET en vivo a DONKI en ccmc.gsfc.nasa.gov, a OSDR RadLab y a services.swpc.noaa.gov. No se escribieron archivos del proyecto; los archivos temporales están solo en el espacio temporal de la sesión.  RESUMEN DE RESULTADOS. 35 datos del investigador: 32 verificados, 3 corregidos, 0 descartados. Se agregaron 8 datos.  CORRECCIONES QUE IMPORTAN PARA EL JUEGO. 1. La cadena de noviembre de 2025 es incorrecta tal como se insinuaba: DONKI vincula la tormenta de Kp 8.67 (12 de noviembre, 03:00Z) con CME del 7, 9 y 10 de noviembre, no con la llamarada X5.1. La CME de la X5.1 está vinculada con una segunda tormenta con pico en Kp 7.33. Además, se registró un evento GOES >10 MeV a las 09:45Z, antes de que comenzara la X5.1, y el eventTime de los SEP de DONKI es una hora de cruce de umbral. '16 minutos después del pico de la llamarada' es un intervalo cierto (31 minutos después del inicio de la llamarada), pero no un tiempo limpio de viaje de las primeras partículas. 2. Los 11.7 cGy/año de CRaTER de LRO ya están verificados en el artículo abierto, pero NO son un valor en órbita lunar: el artículo dice que las tasas de dosis están corregidas por altitud a la superficie lunar y ajustadas a agua. El uso propuesto de órbita frente a superficie no es válido. 3. Artículo sobre regolito: el resumen dice que 180 g/cm2 está 'alrededor de 25%' por debajo del valor sin blindaje; las conclusiones del artículo dicen 35% (200 frente a 310 mSv/año; 35% es la aritmética). Mostrar los valores absolutos. La densidad del regolito del modelo se indica en el artículo (3 g/cm3). 4. La NASA-STD-3001 Vol 1 Rev B quedó sustituida por la Rev C (aprobada el 2023-09-15). Los 600 mSv, los 250 mSv, los valores de las tablas, el blindaje de 10/15/20 cm y el texto de 0.5 / 1.5 mSv/día no cambian, pero cambiaron los números de tabla (Tabla 3 -> 4.8-1, Tabla 6 -> 4.8-4) y la Rev C agrega un requisito de GCR [V1 4033] (1.3 mSv/día en espacio libre, 0.9 mSv/día en superficie). Citar la Rev C. No pude abrir la página índice de standards.nasa.gov (404) para descartar una revisión posterior. 5. La tabla de blindaje de 10/15/20 se puede leer en la NASA-STD-3001, no en el texto del documento técnico de la OCHMO (ahí es una imagen). 6. Fondo mundial: el informe de UNSCEAR de febrero de 2026 da un promedio natural de unos 3.0 mSv/año; la cifra de 2.4 mSv que recordaba el investigador es el valor de 2008.  NO REPRODUCIBLE / AÚN SIN VERIFICAR. - Que api.nasa.gov/DONKI/FLR devuelva 404 mientras GST/SEP devuelven 200: no se pudo volver a probar. Todas las solicitudes con DEMO_KEY desde mi lado (directas y mediante la herramienta de descarga) devolvieron HTTP 429 OVER_RATE_LIMIT con X-Ratelimit-Limit: 10 y Retry-After de unas 6 horas. Esto sí confirma que DEMO_KEY no se puede usar; el equipo debe volver a probar api.nasa.gov con una clave registrada el día del evento. - La nota 5 del investigador dice que la página de documentación de la API del CCMC da 404: es cierto para /tools/DONKI/api/, pero https://ccmc.gsfc.nasa.gov/DONKI/api/ devolvió 200. - Límite de solicitudes del servidor del CCMC: solo se vio el encabezado X-Rate-Limit-Remaining: 119; no se encontró un límite documentado. - Encabezado X-Api-Key: documentado en el manual para desarrolladores de api.data.gov (abierto), pero no se probó en vivo contra api.nasa.gov, y la redacción de la guía de Roblox sobre la limitación de encabezados es ambigua; probar antes de depender de él. - RadLab: no se encontraron en una página abierta la oración de descripción, la ubicación del módulo de DosTel ni el requisito de cita. - Estimaciones de dosis de agosto de 1972 (400 rem): ninguna fuente abierta; la antigua URL de noticias científicas de la NASA da 404. No mostrar. - ISS '80-160 mSv cada seis meses': no se encontró en la página del NSRL de la NASA que se abrió. - Un tiempo de aviso previo a un SPE, en minutos, indicado por la NASA: no se encontró (la NASA solo dice que las tripulaciones 'podrían no tener mucho aviso'). - Espesor de regolito en metros para el suelo lunar real: no se encontró en una fuente abierta. - Las dosis numéricas de Artemis I (26.7-35.4 mSv, diferencia de cuatro veces por blindaje) solo aparecieron en fragmentos de búsqueda del artículo de Nature; no se abrió, no mostrar. - No se probó ninguna llamada HTTP en vivo de Roblox a la NASA.  CONFIRMADO A PARTIR DE LAS NOTAS DEL INVESTIGADOR. Los totales de DONKI para 2024-01-01 a 2026-11-14 se reprodujeron exactamente (1,941 FLR, 85 de clase X, 214 SEP, 62 GST); la lista de 11 tormentas con Kp máximo >= 7.67; la lista de llamaradas X de 2026; los eventos GOES >100 MeV del 2026-07-30 y el 2026-09-05; el límite de rango de 60 días (HTTP 400); el tiempo de espera agotado del servidor kauai; el valor de encabezado 10 de DEMO_KEY; la proporción de partículas solares de 'alrededor del tres por ciento' del JPL (usar 3%, no 5%); la errata de 'ciclos de ~22 años' en el documento técnico de la OCHMO (usar 11 años); el mapeo de la escala G de la NOAA, ahora verificado en la página de la NOAA (G5 = Kp 9, G4 = Kp 8).  ADVERTENCIAS DE UNIDADES Y CONSISTENCIA. (a) Los valores de RAD, LND e ISS son dosis equivalente (Sv); los de Marte de mayo de 2024, CRaTER y absorbed_dose_rate de RadLab son dosis absorbida (Gy); los límites por órgano de la NASA están en mGy-Eq; los valores de la NASA de 600 mSv, 250 mSv y 0.5, 0.9, 1.3 y 1.5 mSv/día son dosis efectiva. No sumarlos ni compararlos entre sí sin una advertencia visible. (b) RAD en superficie (2012-13, cerca del máximo solar) y LND (2019, mínimo solar) se midieron en fases opuestas del ciclo solar; evitar una afirmación tajante de 'Luna = 2x Marte'. (c) Las páginas de la NASA no coinciden en la equivalencia en radiografías de tórax (NSRL: 1 mSv = unas 10 radiografías; JPL: 8,100 uGy = 30 radiografías); citar cada una solo con su propia fuente. (d) Los números derivados (0.017 mSv/día, 324 mSv, '70%', '8 días en la ISS = 1 año en la Tierra', '25 horas') son aritmética del equipo y deben etiquetarse como calculados, no como cifras de la NASA.  EN VIVO FRENTE A ESTÁTICO. DONKI es un catálogo curado por pronosticadores (ver submissionTime) y RadLab es un archivo; ninguno puede etiquetarse como en vivo. Si se quiere un indicador realmente en vivo, las fuentes JSON de NOAA SWPC agregadas arriba devolvieron muestras actuales (de minutos de antigüedad) sin clave; acreditar a NOAA SWPC y mostrar la hora de la muestra.  ARCHIVOS TEMPORALES RELEVANTES (espacio temporal, no proyecto): C:\Users\gorzo\AppData\Local\Temp\claude\22c2971da2bfe9d6\af6d9fcb-1657-4dc7-b14b-5abc2bdf34c2\scratchpad\full\all.json (descarga completa de DONKI), C:\Users\gorzo\AppData\Local\Temp\claude\22c2971da2bfe9d6\af6d9fcb-1657-4dc7-b14b-5abc2bdf34c2\scratchpad\revc\revc.pdf (NASA-STD-3001 Vol 1 Rev C).

</details>

#### Energía y entorno de superficie

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Irradiancia solar en Marte frente a la Tierra | La irradiancia solar a la distancia media de Marte es de 586.2 W/m2 frente a 1361.0 W/m2 en la Tierra, alrededor del 43% de la de la Tierra (porcentaje derivado por división). | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 2 | Duración de un sol | Un día solar medio de Marte (sol) dura 24 h 39 min 35.244 s (88,775.244 segundos). | Verificado | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 3 | Duración del año marciano en soles | Un año trópico de Marte tiene 668.5921 soles (686.9725 días terrestres) según NASA GISS; la página pública Mars Facts de la NASA da 669.6 soles / 687 días terrestres. | Verificado | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 4 | Temperaturas del cráter Jezero (MEDA de Perseverance) | MEDA registró en Jezero una máxima de -22 C (-7.6 F) y una mínima de -83 C (-117.4 F) en los soles 43-44 (3-4 de abril de 2021); una página de NASA Science resume la temperatura del aire como de entre -83 C y -23 C, y la temperatura de la superficie (del suelo) como típicamente de -83 C antes del amanecer a 5 C al mediodía. | Verificado | <https://www.jpl.nasa.gov/news/nasas-first-weather-report-from-jezero-crater-on-mars/> |
| 5 | Presión en superficie y viento en Jezero (MEDA) | La primera lectura de presión de MEDA en Jezero fue de 718 Pa (dentro del rango previsto de 705-735 Pa), y las ráfagas de viento rondaron los 10 m/s (22 mph) en los soles 43-44. | Verificado | <https://www.jpl.nasa.gov/news/nasas-first-weather-report-from-jezero-crater-on-mars/> |
| 6 | Temperaturas del cráter Gale (REMS de Curiosity) | Las temperaturas del aire de REMS en Gale, de mediados de agosto de 2012 a finales de febrero de 2013, mostraron máximas diarias de unos 0 C (32 F) y mínimas de unos -70 C (-94 F); los 30 soles más recientes de la fuente JSON de REMS del JPL/Mars (4966-4995, del 2026-07-26 al 2026-08-25) muestran min_temp de -78 a -69 y max_temp de -11 a -3, con presión de 777-791. | Verificado | <https://science.nasa.gov/resource/steady-temperatures-at-mars-gale-crater> |
| 7 | Presión en la superficie de Marte | La presión media en la superficie de Marte es de 6.36 mb (636 Pa) en el radio medio, variable de 4.0 a 8.7 mb según la estación. | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 8 | Composición de la atmósfera de Marte | La atmósfera de Marte, por volumen, es 95.1% CO2, 2.59% N2, 1.94% Ar, 0.16% O2 y 0.06% CO. | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 9 | Gravedad en la superficie de Marte | La gravedad media en la superficie de Marte es de 3.73 m/s2 frente a 9.82 m/s2 en la Tierra, alrededor del 38% de la de la Tierra (derivado). | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 10 | Opacidad (tau) de la tormenta de polvo global de 2018 | El JPL informó que la tormenta de 2018 en el sitio de Opportunity tenía un tau estimado de 10.8 el 10 de junio de 2018 (último tau medido), frente a 'algo por encima de 5.5' en la tormenta de 2007 y un promedio habitual de 0.5; los ingenieros predijeron que el tau tenía que bajar de 2.0 para que se recargara. La tormenta creció de más de 18 millones de km2 (8 de junio) a 35 millones de km2 (12 de junio), una cuarta parte del planeta. Otra página gráfica de NASA Science da para el 10 de junio un tau de 10.5. | Verificado | <https://www.jpl.nasa.gov/news/opportunity-hunkers-down-during-dust-storm/> |
| 11 | Último contacto de Opportunity y fin de la misión | La comunicación final de Opportunity se recibió el 10 de junio de 2018 (sol 5,111); tras más de mil comandos para restablecer el contacto, el último intento se envió a última hora del 12 de febrero de 2019 y la NASA declaró concluida la misión el 13 de febrero de 2019. Diseñado para 90 días marcianos y 1,000 m (1,100 yardas), operó casi 15 años y recorrió más de 45 km (28 millas). | Verificado | <https://www.jpl.nasa.gov/news/nasas-opportunity-rover-mission-on-mars-comes-to-end/> |
| 12 | Energía solar de Opportunity antes y durante la tormenta de 2018 | La NASA indica que la energía de Opportunity el 10 de junio de 2018 (sol 5,111) fue de 21 watts-hora, la más baja medida en el rover hasta ese momento. The Planetary Society, citando al equipo de MER, da unos 645 Wh el 1 de junio de 2018 y 22 Wh el 10 de junio, casi 100 Wh por debajo de lo que se considera necesario para que sobreviva un rover de clase MER. | Corregido | <https://science.nasa.gov/resource/on-mars-light-is-energy/> |
| 13 | Polvo en los paneles solares de InSight (Wh por sol) | Los dos paneles solares de InSight (cada uno de unos 2.2 m de ancho) producían alrededor de 5,000 Wh por sol al aterrizar (26 de noviembre de 2018) y aproximadamente 500 Wh por sol para el 17 de mayo de 2022; después, una tormenta de polvo regional (vista por primera vez el 21 de septiembre de 2022) redujo la energía de 425 a 275 Wh por sol. | Verificado | <https://www.jpl.nasa.gov/news/nasas-insight-still-hunting-marsquakes-as-power-levels-diminish/> |
| 14 | Fin de la misión InSight | InSight se comunicó por última vez con la Tierra el 15 de diciembre de 2022; la NASA anunció el retiro de la misión el 21 de diciembre de 2022, después de que el módulo de aterrizaje no respondiera a dos intentos consecutivos de comunicación, tras haber detectado 1,319 sismos marcianos en más de cuatro años. | Verificado | <https://www.jpl.nasa.gov/news/nasa-retires-insight-mars-lander-mission-after-years-of-science/> |
| 15 | Eventos de limpieza de polvo (viento / remolinos de polvo) | En marzo de 2014, el viento limpió los paneles de Opportunity y aumentó la producción del arreglo en alrededor de 10%; sumado a la luz solar de la estación, la energía diaria subió más de 70% en dos meses, a más de 615 Wh. Para InSight, el JPL estimó que limpiar el 25% de los paneles daría unos 1,000 Wh por sol más. | Verificado | <https://www.jpl.nasa.gov/news/cleaner-nasa-rover-sees-its-shadow-in-martian-spring/> |
| 16 | Temporada y frecuencia de las tormentas de polvo en Marte | Las grandes tormentas de polvo regionales se repiten más o menos en las mismas fechas cada año marciano, durante la primavera y el verano del sur; las tormentas locales miden menos de unos 2,000 km de ancho y terminan en pocos días, las regionales afectan hasta un tercio del planeta y duran hasta tres semanas; las globales ocurren en promedio una vez cada tres años marcianos (unos 5.5 años terrestres). | Verificado | <https://www.jpl.nasa.gov/news/nasa-mars-orbiters-reveal-seasonal-dust-storm-pattern/> |
| 17 | Producción y degradación del MMRTG | Un MMRTG produce unos 110 W de electricidad al inicio de su vida a partir de unos 2,000 W de calor (4.8 kg de dióxido de plutonio, 8 módulos GPHS, ~45 kg) y unos 72 W estimados al final de su vida de diseño de 17 años (que incluye 3 años de almacenamiento con combustible). El kit de prensa de Mars 2020 del JPL dice que la producción baja 'unos cuantos por ciento cada año' y que el MMRTG carga dos baterías de iones de litio (de unos 43 Ah cada una, 26.5 kg en total) porque la demanda puede llegar a 900 W durante las actividades científicas; la vida operativa del MMRTG de Perseverance es de al menos 14 años. | Verificado | <https://science.nasa.gov/wp-content/uploads/2024/02/mmrtg-factsheet-updated-5-18-20-1.pdf> |
| 18 | Kilopower / KRUSTY | El sistema Kilopower de la NASA puede dar hasta 10 kW de potencia eléctrica de forma continua durante al menos 10 años; cuatro unidades darían energía suficiente para establecer un puesto avanzado. El experimento KRUSTY se realizó de noviembre de 2017 a marzo de 2018 en el Nevada National Security Site y terminó con una prueba de 28 horas a máxima potencia, con un núcleo sólido fundido de uranio-235 del tamaño aproximado de un rollo de toallas de papel. | Verificado | <https://www.nasa.gov/news-release/demonstration-proves-nuclear-fission-system-can-provide-space-exploration-power/> |
| 19 | Fission Surface Power (meta de 40 kWe) | El proyecto Fission Surface Power de la NASA busca un sistema de clase 40 kW ('al menos 40 kilowatts', suficiente para abastecer de forma continua a 30 hogares durante diez años según la página del proyecto; 33 hogares según NASA Glenn), de menos de seis toneladas métricas y capaz de operar una década sin intervención humana; en 2022 se otorgaron tres contratos de Fase 1 de $5 millones. | Verificado | <https://www.nasa.gov/exploration-systems-development-mission-directorate/fission-surface-power/> |
| 20 | Estado de Fission Surface Power en 2026 | Un comunicado de la NASA del 13 de enero de 2026 anunció un memorando de entendimiento entre la NASA y el DOE para apoyar el desarrollo de un reactor en la superficie lunar para 2030; un segundo memorando firmado el 8 de octubre de 2026 (vigente desde el 1 de noviembre de 2026) nombra 'Lunar Reactor-1 (LR-1)', el sistema de energía de fisión en superficie pensado para mantener la Moon Base durante la oscuridad, y cita una Orden Ejecutiva de diciembre de 2025 que ordena tener listo para lanzamiento un reactor de superficie lunar para 2030. Ninguno de los dos comunicados indica un nivel de potencia. | Verificado | <https://www.nasa.gov/news-release/nasa-energy-department-advance-new-era-of-nuclear-powered-exploration/> |
| 21 | Necesidad de energía de un hábitat lunar | Un 'Government Reference Example' de NASA Glenn indica para un hábitat lunar 20 kW durante la ocupación y ~2 kW en modo de mantenimiento (tripulación de 4 por 30+ días, 4 veces al año), para ISRU 60-70 kW de pico (~12 kW en modo de mantenimiento) y para rovers y experimentos científicos 500-1,000 W. | Verificado | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 22 | Necesidad de energía en superficie para una misión tripulada a Marte | El documento técnico Moon to Mars de la NASA dice que una misión muy modesta de dos tripulantes por no más de 30 días necesita al menos 10 kW de energía en superficie, mientras que arquitecturas más grandes con fabricación de propelente criogénico necesitan cientos de kW, acercándose a la clase de megawatts; el flujo solar en Marte es 'como máximo 45 por ciento' de los valores típicos de la Tierra. | Verificado | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 23 | Potencia de los paneles solares de la ISS | Los ocho arreglos solares de la Estación Espacial Internacional dan de 75 a 90 kW de potencia; la envergadura de los arreglos solares es de 109 m (356 ft). | Verificado | <https://www.nasa.gov/international-space-station/space-station-facts-and-figures/> |
| 24 | Ciclo de día y noche lunar | La litografía de LRO de la NASA dice que cada día lunar dura 14 días terrestres y una noche lunar dura 14 días terrestres; el periodo sinódico de la Luna es de 29.53 días (NSSDC); NASA Glenn describe las noches lunares como de 14 días terrestres y medio. | Verificado | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 25 | Temperaturas ecuatoriales lunares (Diviner de LRO) | Los datos de Diviner muestran que las temperaturas diurnas cerca del ecuador lunar llegan a unos 120 C (250 F, 400 K) y las nocturnas a unos -130 C (-208 F, 140 K). | Verificado | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 26 | Temperaturas lunares más frías (cráter Hermite, PSR) | Diviner detectó unos -250 C (25 K, -410 F) en el fondo del cráter Hermite, cerca del polo norte de la Luna, que la NASA describe como la temperatura más fría medida en cualquier lugar del sistema solar (otras páginas de la NASA dan -248 C / -415 F y -249 C); la NASA dice que LRO ha medido temperaturas inferiores a -246 C (-410 F) en cráteres polares en sombra permanente. | Verificado | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 27 | Iluminación del polo sur: borde de Shackleton | Con la topografía de LOLA, Mazarico et al. (Icarus 211, 2011) encontraron un lugar cerca del borde del cráter Shackleton que recibe luz solar continua durante 240 días al año, con un periodo continuo más largo de oscuridad total de unos 1.5 días; el área en sombra permanente suma 12,866 km2 (norte) y 16,055 km2 (sur). Shackleton mide 21 km de ancho y 4 km de profundidad, con un fondo en sombra perpetua. | Verificado | <https://ntrs.nasa.gov/citations/20120010094> |
| 28 | Porcentajes de iluminación del polo sur (cresta de conexión) | Las simulaciones para 2017-2037 (Glaser et al.) encontraron una iluminación promedio de los mejores sitios polares que va de 69.5% a 82.9% a nivel del suelo y de 77.1% a 88.0% para paneles solares a 2 m sobre el suelo, con el máximo en la cresta entre los cráteres Shackleton y de Gerlache; LROC señala que partes de esa cresta están iluminadas hasta el 90% del tiempo, pero ningún lugar está iluminado de forma permanente. | Verificado | <https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/20170007365.pdf> |
| 29 | Gravedad en la superficie de la Luna | La gravedad en la superficie de la Luna es de 1.62 m/s2, 0.165 de la de la Tierra (alrededor de un sexto). | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html> |
| 30 | Concepto Artemis Base Camp (2020) | El concepto Artemis Base Camp de la NASA de octubre de 2020 en el Polo Sur lunar incluye un vehículo de terreno lunar abierto, un rover presurizado tipo 'casa rodante' y un hábitat fijo para hasta cuatro astronautas en estancias de un mes, con la meta de estancias de hasta dos meses; la NASA desarrollaba entonces una unidad de energía de fisión en superficie capaz de dar 10 kW de forma continua, y los primeros sistemas deben almacenar energía hasta por ocho días porque ningún lugar se libra de periodos de oscuridad. | Verificado | <https://www.nasa.gov/blogs/missions/2020/10/28/lunar-living-nasas-artemis-base-camp-concept/> |
| 31 | Fases y energía del plan Moon Base (2026) | El plan Moon Base de la NASA tiene tres fases: Fase Uno (ahora-2029), 'Gain Reliable Access, Experiment, and Learn'; Fase Dos (2029-2032), 'Build and Expand', con infraestructura energética inicial que incluye arreglos solares y estaciones de energía con radioisótopos, y módulos presurizados iniciales para estancias cortas; Fase Tres (2032 en adelante), 'Live and Work on the Moon', con energía de fisión en superficie operativa y módulos de hábitat de clase 100 metros cúbicos. El rover presurizado de la JAXA permite misiones de hasta 28 días con hasta 14 días entre reabastecimientos de carga. | Verificado | <https://www.nasa.gov/moonbase-phases/> |
| 32 | Calendario de Artemis a finales de 2026 | Artemis II despegó el 1 de abril de 2026 y amerizó el 10 de abril de 2026 (9 días, 1 hora, 32 minutos; Wiseman, Glover, Koch, Hansen); Artemis III (2027) es una prueba con cuatro tripulantes en órbita terrestre baja de encuentro y acoplamiento entre Orion y módulos de aterrizaje comerciales; Artemis IV (principios de 2028) está planeada como el primer alunizaje tripulado de Artemis, con dos tripulantes que pasarán alrededor de una semana cerca del Polo Sur. | Verificado | <https://www.nasa.gov/humans-in-space/artemis/> |
| 33 | Almacenamiento de energía para la noche lunar (baterías, celdas de combustible, torres solares) | El ejemplo de referencia de NASA Glenn indica Vertical Solar Array Technology con 10 kW a 100 VDC (TRL más bajo, no puede dar energía todo el año), Fission Surface Power con 40 kW (TRL bajo, número limitado de unidades, debe ubicarse a 1 km o más de otros activos, da energía durante la oscuridad), baterías pesadas que no funcionan bien a temperaturas extremadamente bajas, y celdas de combustible regenerativas (electrólisis del agua que almacena energía como hidrógeno) con TRL bajo. | Verificado | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 34 | Mars Trek / Moon Trek como fuentes de datos | NASA Solar System Treks (trek.nasa.gov) aloja Moon Trek y Mars Trek, portales construidos con datos reales de naves espaciales, con herramientas para calcular distancias, perfiles de elevación (exportables a .csv), el ángulo del Sol en un rango de fecha y hora elegido, archivos para impresión 3D y sobrevuelos en realidad virtual; la mayoría de las capas se sirven mediante OGC RESTful WMTS en proyecciones equirrectangular, de polo norte y de polo sur. | Verificado | <https://trek.nasa.gov/> |
| 35 | Las fuentes de clima de Marte NO están en vivo (trampa de vigencia de datos) | El 2026-11-14, la API de clima de InSight en api.nasa.gov devolvió datos congelados de los soles 675-681 (19-26 de octubre de 2020; temperatura promedio del aire de unos -62, presión de unos 744-751); la entrada más reciente de la fuente JSON de MEDA de Mars 2020 era el sol 1133 (2024-04-27: mín. -79.3, máx. -24.7, presión 778.9); la entrada más reciente de la fuente REMS de Curiosity era el sol 4995 (2026-08-25: mín. -71, máx. -5, presión 777). | Verificado | <https://api.nasa.gov/insight_weather/?api_key=DEMO_KEY&feedtype=json&ver=1.0> |
| 36 | Frecuencia de las tormentas de polvo globales y fuerza del viento | La NASA dice que las tormentas de polvo crecen hasta cubrir todo el planeta en promedio una vez cada tres años marcianos (unos 5.5 años terrestres); los vientos de las tormentas marcianas más fuertes llegan como máximo a unas 60 mph, menos de la mitad de la velocidad de algunos vientos huracanados en la Tierra, y la atmósfera de Marte tiene alrededor del 1 por ciento de la densidad de la terrestre. | Verificado | <https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/> |
| 37 | El viento de Marte es débil: sin energía eólica y con poco empuje sobre las estructuras | El documento técnico de la NASA sobre energía en la superficie de Marte dice que la mayor velocidad de viento medida en la superficie marciana fue de unos 30 m/s en el sitio del módulo de aterrizaje Viking 2, que sobre un arreglo solar se siente como un viento de solo 4 m/s en la Tierra; la atmósfera es demasiado delgada para generar suficiente energía eólica para sistemas tripulados. | Verificado | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 38 | Qué tan rápido llegó la tormenta de 2018, y nuclear frente a solar | El documento técnico de la NASA dice que Opportunity pasó de cielos despejados a la mayor oscuridad que había registrado hasta entonces (tau 4.9) en tres soles marcianos, y luego a un apagón prácticamente total cuatro soles después; el sistema de energía con radioisótopos de Curiosity no se vio afectado por la misma tormenta. Las tormentas globales pueden durar varias semanas o meses. | Verificado | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 39 | Fracción de luz diurna en Marte y temperaturas extremas | El documento técnico de la NASA dice que las misiones típicas a Marte en latitudes medias tienen un ciclo de día y noche de unas 25 horas, con aproximadamente el 50 por ciento del tiempo iluminado, y que las temperaturas de la superficie de Marte van desde 30 C hasta -140 C según el lugar y la estación; las ventanas de salida de la Tierra hacia Marte se abren cada 26 meses. | Verificado | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 40 | Valores de referencia de la Tierra para las barras de comparación | Hoja informativa de la Tierra del NSSDC: presión en superficie 1014 mb, temperatura promedio 288 K (15 C), atmósfera 78.08% N2 y 20.95% O2, irradiancia solar 1361.0 W/m2; la temperatura promedio de Marte es de ~214 K (-59 C) y la Luna recibe los mismos 1361.0 W/m2 que la Tierra. | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html> |
| 41 | Regla de ubicación del reactor y escala de la red lunar | El ejemplo de referencia de NASA Glenn dice que las unidades de Fission Surface Power son limitadas en número y deben ubicarse a 1 km o más de otros activos; su red lunar conceptual tiene unos 10 km de longitud total de líneas y ~100 kW de potencia total, con la excavación ISRU en una región en sombra permanente a 3-5 km de la planta de producción, ubicada en el borde de un cráter. | Verificado | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 42 | Estado de VIPER (vigente a finales de 2026) | El rover VIPER de la NASA será entregado en Mons Mouton, cerca del Polo Sur lunar, por un módulo de aterrizaje Blue Moon MK-1 de Blue Origin, bajo la orden de trabajo CS-7 de CLPS (valor potencial total de $190 millones), con entrega prevista para finales de 2027, para una misión de 100 días en busca de hielo y otros volátiles. | Verificado | <https://science.nasa.gov/mission/viper/> |
| 43 | Opportunity el 10 de junio de 2018 en una página de la NASA (sol, energía, tau) | Un recurso de NASA Science indica que el 10 de junio de 2018, el sol 5,111 de operaciones de Opportunity, la medición de tau (10.5) fue mayor que cualquiera medida antes en Marte y el nivel de energía (21 watts-hora) fue el más bajo medido en Opportunity hasta ese momento; la atmósfera empezó a oscurecerse el 30 de mayo de 2018. | Verificado | <https://science.nasa.gov/resource/on-mars-light-is-energy/> |

<details><summary>Notas de verificación de esta sección</summary>

MÉTODO (2026-11-14): abrí personalmente cada fuente listada con la herramienta de descarga. Cuatro PDF de la NASA (hoja informativa del MMRTG, litografía de Diviner de LRO, diapositivas de energía lunar de Csank, documento técnico sobre energía en la superficie de Marte) llegaron como binarios; la herramienta de descarga guardó sus propias copias, les extraje el texto a la salida estándar con pdftotext y leí el texto directamente (no escribí archivos). Se revisaron los 35 datos del investigador: 34 verificados (varios con ajustes de redacción o atribución incorporados en la afirmación), 1 corregido (watts-hora de Opportunity), 0 descartados. Se agregaron 8 datos, todos abiertos.  CORRECCIONES CLAVE Y NUEVOS CONFLICTOS 1. Energía de Opportunity el 10 de junio de 2018: existe una página primaria de la NASA (science.nasa.gov/resource/on-mars-light-is-energy/) que dice 21 Wh y tau 10.5, frente a 22 Wh (The Planetary Society citando al equipo de MER) y tau 10.8 (dos artículos de noticias del JPL). La cifra de 645 Wh 'antes' sigue siendo solo secundaria (The Planetary Society). El sol 5,111 como último contacto ya está confirmado en esa página de la NASA. 2. Atribución del MMRTG: 'unos cuantos por ciento cada año', las 2 baterías de ~43 Ah y el pico de 900 W están en la página de energía del kit de prensa de Mars 2020 del JPL, no en la hoja informativa del MMRTG. La cifra de ~2.5%/año es derivada y debe etiquetarse así. La página de Pu-238 de la NASA da una vida media de 88 años. 3. Artemis: la mejor cita única es nasa.gov/humans-in-space/artemis/ (actualizada el 21 de octubre de 2026), que indica que Artemis IV (2028) es el primer alunizaje tripulado y Artemis III (2027) una prueba de acoplamiento en LEO. La página de la misión Artemis IV (actualizada el 16 de marzo de 2026) dice 'Early 2028', pero aún conserva texto heredado que se refiere a la ciencia de Artemis III, así que es una cita más débil. No pude localizar el blog de la NASA del 23 de octubre de 2026 que citó el investigador. 4. Presión de la Tierra: usar los 1014 mb del NSSDC (abierto) en lugar de los 101,325 Pa citados de memoria. 5. Que Hermite esté 'cerca del polo norte' se confirma en science.nasa.gov/image-detail/hermite (que da -249 C); por lo tanto, la NASA tiene tres redondeos (-248, -249, -250 C). Los 25 K de la litografía son el valor más limpio. 6. Iluminación: 82.9% (superficie) y 88.0% (2 m) son los extremos superiores de rangos entre los mejores sitios, y 2 m es la altura de un panel sobre la cubierta de un módulo de aterrizaje; no presentarlos como un antes y después medido para un solo mástil. Los 240 días / 1.5 días de Mazarico se calcularon a partir de la topografía de LOLA; el resumen no les asocia ninguna altura. 7. La frecuencia de tormentas de polvo 'una vez cada tres años marcianos (unos 5.5 años terrestres)' ya está confirmada en una página abierta de la NASA; no imprimir el conteo de 2016 de 'dos tormentas globales desde 1997'.  AÚN SIN VERIFICAR / NO IMPRIMIR - Meta de un reactor lunar de 100 kW: ninguna fuente primaria abierta por mí ni por el investigador. (Los '~100 kW' de la diapositiva de Csank son la potencia total de una red conceptual, no la capacidad de un reactor.) - La gravedad de Marte de 3.71 m/s2, los '45 días' de Artemis Base Camp, la frase 'habitable mobility platform' del blog de 2020 y la redacción del '38%' del kit de prensa del JPL no aparecieron en las fuentes que abrí. - No se abrió la climatología revisada por pares de MEDA (Rodriguez-Manfredi et al. 2023); los números de Jezero corresponden a soles específicos (43-44) más un resumen sin fecha de la NASA. - Tamaño publicado en kWh para el almacenamiento de energía de la noche lunar: NO ENCONTRADO. - Identificadores de capas de Trek y si el espejo WMTS de api.nasa.gov necesita clave: sin verificar.  ADVERTENCIAS DE UNIDADES Y VIGENCIA - Las fuentes de clima de mars.nasa.gov no indican las unidades de temperatura (°C por convención) y min_temp/max_temp no se definen como temperatura del aire en el JSON; el texto de presión se refiere a pascales. Entradas más recientes al momento de leerlas: MSL sol 4995 (2026-08-25, ~81 días de antigüedad), Mars 2020 sol 1133 (2024-04-27), InSight soles 675-681 (octubre de 2020; la misión terminó en diciembre de 2022). Ninguna puede mostrarse como en vivo. - Números derivados que la NASA no publica y que necesitan una etiqueta de 'derivado' en pantalla: 43.1% de luz solar, 38% de gravedad, 0.6-0.7% de presión, 2.5%/año de degradación del MMRTG, noche lunar de 354 horas, 3% de producción durante la tormenta, 90% de pérdida de InSight. - Las páginas que describen planes (Artemis IV a principios de 2028, LR-1 para 2030, fases de Moon Base, VIPER a finales de 2027, FSP 'a principios de la década de 2030' en una página actualizada por última vez en septiembre de 2025) deberían llevar un sello de 'a noviembre de 2026'; la página del proyecto FSP es anterior a los comunicados de 2026 sobre LR-1 'para 2030' y en parte los contradice. - Las cifras de fisión, Kilopower y FSP son metas de diseño o pruebas en tierra (KRUSTY 2018), no equipo que haya volado.

</details>

#### Comunicaciones y operaciones de misión

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Tiempo luz de la Tierra a Marte en un solo sentido (rango, página Mars Relay Network de la NASA) | La página Mars Relay Network de la NASA dice que la distancia entre la Tierra y Marte varía entre 33.9 millones de millas (54.6 millones de km, unos 3 minutos de tiempo luz) y 248.7 millones de millas (400.2 millones de km, unos 22.4 minutos), en un solo sentido. | Verificado | <https://science.nasa.gov/mars/mars-relay-network/> |
| 2 | Tiempo luz de la Tierra a Marte en un solo sentido (rango, redondeo de NASA Goddard) | NASA Goddard dice que el retraso es de unos cuatro minutos en el máximo acercamiento de Marte (unos 35 millones de millas) y de unos 24 minutos a la mayor distancia (unos 250 millones de millas); los astronautas esperarían de 4 a 24 minutos para que un mensaje llegue al control de misión y otros 4 a 24 minutos para recibir una respuesta. | Verificado | <https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/> |
| 3 | Tiempo luz entre la Tierra y Marte en una fecha real específica | El día del aterrizaje de Perseverance, el 18 de febrero de 2021, el tiempo luz en un solo sentido de Marte a la Tierra fue de unos 11 minutos 22 segundos, con Marte a 127 millones de millas (205 millones de km) de la Tierra. | Verificado | <https://www.jpl.nasa.gov/news/press_kits/mars_2020/landing/quick_facts/> |
| 4 | Perfil de retraso en una misión tripulada a Marte | Un análisis de NASA Langley para ASCEND 2022 encontró que los retrasos de comunicación varían de 0 a 22 minutos a lo largo de una misión tripulada a Marte, con el máximo mientras la tripulación está en Marte o acaba de salir de ahí; el retraso máximo en un solo sentido es de unos 22 minutos para cualquier misión y de 15 a 20 minutos mientras la tripulación está en Marte. | Verificado | <https://ntrs.nasa.gov/api/citations/20220013418/downloads/ASCEND-Communication%20Delays,%20Disruptions,%20and%20Blackouts%20for%20Crewed%20Mars%20Missions.pdf> |
| 5 | Conjunción solar de Marte: frecuencia y causa | La conjunción solar de Marte ocurre aproximadamente cada 26 meses, cuando Marte pasa casi directamente detrás del Sol visto desde la Tierra; las transmisiones de radio corren el riesgo de corromperse, así que las misiones de la NASA en Marte tienen una moratoria para el envío de comandos. El comunicado del JPL de 2023 redondea la frecuencia a 'cada dos años'. | Verificado | <https://science.nasa.gov/resource/geometry-of-mars-solar-conjunction/> |
| 6 | Conjunción solar de Marte de noviembre de 2023 (duración de la pausa de comandos) | En la conjunción de 2023, la NASA dejó de enviar comandos a su flota en Marte durante dos semanas, del 11 al 25 de noviembre de 2023, incluidos dos días en los que la agencia no iba a recibir noticias de la flota mientras Marte estaba completamente detrás del Sol; los rovers se quedaron estacionados y siguieron monitoreando las condiciones de la superficie, el clima y la radiación. | Verificado | <https://www.jpl.nasa.gov/news/nasas-mars-fleet-will-still-conduct-science-while-lying-low/> |
| 7 | Conjunción solar de Marte más reciente (dic. 2025 - ene. 2026) | El equipo de Curiosity indicó que la conjunción más reciente duraría del 27 de diciembre (2025) al 20 de enero (2026); la primera fecha de planeación de Curiosity desde la Tierra después de la conjunción fue el viernes 30 de enero de 2026. JPL Horizons muestra la elongación solar mínima de Marte (0.95 grados) el 9 de enero de 2026, con un tiempo luz en un solo sentido de unos 20.0 minutos. | Verificado | <https://science.nasa.gov/blog/curiosity-blog-sols-4750-4762-see-you-on-the-other-side-of-the-sun/> |
| 8 | Próxima conjunción solar de Marte | JPL Horizons (efemérides geocéntricas, paso diario) muestra la próxima elongación solar mínima de Marte, 0.81 grados, el 21 de marzo de 2028, con Marte a 2.388 AU de la Tierra y un tiempo luz en un solo sentido de 19.86 minutos. | Corregido | <https://ssd.jpl.nasa.gov/api/horizons.api?format=text&COMMAND='499'&OBJ_DATA='NO'&MAKE_EPHEM='YES'&EPHEM_TYPE='OBSERVER'&CENTER='500@399'&START_TIME='2028-03-14'&STOP_TIME='2028-03-28'&STEP_SIZE='1d'&QUANTITIES='20,21,23'> |
| 9 | Apagón por conjunción en una misión tripulada a Marte | El documento técnico de arquitectura Moon to Mars de la NASA de 2023 dice que, en una misión tripulada de ida y vuelta a Marte, los apagones de comunicación directa entre la nave y la Tierra son inevitables y pueden durar semanas: unos 13 días en una misión representativa de energía mínima (estancia larga) de ~1,000 días, en las cercanías de Marte, y unas tres semanas (21 días) en una misión representativa de estancia corta de 850 días, durante el tránsito de regreso; el retraso en un solo sentido puede superar los 21-23 minutos. | Verificado | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-communications-disruption-and-delay.pdf> |
| 10 | Declaración de la NASA: las tripulaciones en Marte no pueden depender del Control de Misión en tiempo real | El documento técnico de arquitectura de la NASA de 2025 dice que los astronautas en Marte experimentarían un retraso de comunicaciones en un solo sentido de entre 4 y 24 minutos, lo que hace poco práctica una conversación en tiempo real con la Tierra, y que la distancia y los retrasos reducirán mucho el apoyo de las operaciones de control de vuelo desde la Tierra, lo que exige capacidades autónomas e independientes de la Tierra. | Verificado | <https://www.nasa.gov/wp-content/uploads/2025/12/acr25-wp-why-moon-and-mars-v2.pdf> |
| 11 | Peligro 'Distance from Earth' del Human Research Program de la NASA | El HRP de la NASA indica que Marte está en promedio a 140 millones de millas de la Tierra, que un viaje a Marte duraría aproximadamente tres años (frente a un viaje lunar de tres días) y que las tripulaciones enfrentan un retraso de comunicación de hasta 20 minutos en un solo sentido, con un apoyo mínimo de los equipos en la Tierra. | Verificado | <https://www.nasa.gov/hrp/hazard-distance-from-earth/> |
| 12 | Retraso de comunicación entre la Tierra y la Luna | La Tabla 1 del NASA TM-20250003885 indica una latencia en un solo sentido de Apollo de 1.3 segundos y dice que las misiones lunares pueden tener latencias en un solo sentido de 3 a 14 segundos una vez que se incluyen los retrasos del sistema; la actividad Radio JOVE de la NASA calcula 1.33 s en un solo sentido para 400,000 km; la ESA indica 1.27 s en promedio. | Verificado | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 13 | Deep Space Network: tres sitios y por qué | La DSN tiene tres sitios, Goldstone (cerca de Barstow, California), cerca de Madrid (España) y cerca de Canberra (Australia), separados aproximadamente 120 grados en longitud; cada sitio tiene una antena de 230 pies (70 metros) y cada complejo tiene al menos cuatro estaciones de antena. | Verificado | <https://www.nasa.gov/directorates/somd/space-communications-navigation-program/what-is-the-deep-space-network/> |
| 14 | Orbitadores de la Mars Relay Network y volumen de datos (2026) | La página de la NASA (actualizada el 05 de junio de 2026) enumera Odyssey, MRO y el TGO de la ESA como orbitadores de retransmisión, con Mars Express de la ESA como respaldo. Volúmenes promedio de retransmisión de febrero a mayo de 2026: TGO 2,228.1 Mb/día, MRO 850.6 Mb/día, Odyssey 107.3 Mb/día, MAVEN 0. Cada orbitador tiene 2-4 pasos por día, pero los pasos que realmente se usan para retransmitir son Odyssey 0-1, MRO 1-3, TGO 2-4 (Mars Express 1-3 pasos, 0 usados). | Corregido | <https://science.nasa.gov/mars/mars-relay-network/> |
| 15 | Estado de MAVEN (orbitador de retransmisión perdido) | Se supo de MAVEN por última vez el 6 de diciembre (2025); una junta de revisión de la NASA concluyó que la nave no era recuperable y la NASA declaró concluida la misión el 3 de junio de 2026. Su volumen de retransmisión fue de 0 en febrero-mayo de 2026, frente a un promedio de 897.5 Mb/día hasta 2025. | Verificado | <https://science.nasa.gov/mars/mars-relay-network/> |
| 16 | Enlaces de radio de Perseverance (retransmisión frente a directo a la Tierra) | La antena UHF de Perseverance envía hasta 2 megabits por segundo en el enlace de retransmisión del rover al orbitador, y el 99.9% de sus datos científicos pasan por esa antena hacia los orbitadores que pasan por encima; su antena de alta ganancia de banda X se enlaza con la Tierra a 160/500 bits por segundo o más hacia/desde antenas de la DSN de 34 m, o a 800/3,000 bits por segundo o más hacia/desde antenas de 70 m. | Verificado | <https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/> |
| 17 | Línea de visión de los rovers y frecuencia de retransmisión | La NASA indica que los rovers no tienen línea de visión con la Tierra durante unas 12 horas al día debido a la rotación de Marte y que se comunican con los orbitadores cercanos a hasta 2 Mbps; los orbitadores de la Mars Relay Network devuelven los datos de los rovers a la Tierra alrededor de una docena de veces por semana. No se encontró un volumen de datos por sol específico para Perseverance. | Verificado | <https://science.nasa.gov/mars/mars-relay-network/> |
| 18 | Análogo CHAPEA: protocolo de retraso de comunicación | Las misiones CHAPEA de la NASA ponen a cuatro voluntarios de investigación en un hábitat de unos 1,700 pies cuadrados en el Johnson Space Center durante 378 días, con retrasos de comunicación de hasta 22 minutos en cada sentido; la Misión 1 fue del 25 de junio de 2023 al 6 de julio de 2024 y la Misión 2 del 19 de octubre de 2025 al 31 de octubre de 2026. | Verificado | <https://www.nasa.gov/centers-and-facilities/johnson/chapea-mission-2-crew-reflects-after-378-days-on-simulated-mars/> |
| 19 | Apagón de comunicaciones simulado en CHAPEA | La página de CHAPEA de la NASA dice que la tripulación habla de cómo afrontó un apagón de comunicaciones simulado de dos semanas. | Verificado | <https://www.nasa.gov/humans-in-space/chapea/> |
| 20 | Análogo HERA: protocolo de retraso de comunicación | HERA de la NASA es un hábitat de 650 pies cuadrados en el Johnson Space Center donde tripulaciones de cuatro voluntarios de investigación pasan hasta 45 días en misiones simuladas al espacio profundo, con retrasos de comunicación de hasta cinco minutos en cada sentido con el Control de Misión. | Verificado | <https://www.nasa.gov/humans-in-space/houston-do-you-copy-hera-crew-navigates-communication-delays/> |
| 21 | Guía de la NASA para comunicarse con retraso | El NASA TM-20250003885 (2025) informa que los estudios de NEEMO y HERA con retrasos de 50 segundos a 5 minutos mostraron problemas en los hilos de mensajes que los protocolos estructurados resuelven, dice que las responsabilidades deben pasar al equipo a bordo conforme aumentan los retrasos y recomienda que en los análogos los retrasos se aumenten de forma gradual y no en saltos grandes (CHAPEA lo hace; HERA todavía usa saltos). | Verificado | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 22 | Ventana de lanzamiento a Marte y tiempo de tránsito | La NASA dice que la Tierra y Marte se alinean para el viaje más eficiente en energía aproximadamente una vez cada 26 meses y que el crucero a Marte dura unos 200 días; Perseverance despegó el 30 de julio de 2020 en un viaje de siete meses y aterrizó el 18 de febrero de 2021. | Verificado | <https://science.nasa.gov/planetary-science/programs/mars-exploration/mission-timeline/> |
| 23 | Clases de misiones a Marte: estancia en superficie y duración total (DRA 5.0) | La Mars Design Reference Architecture 5.0 de la NASA (2009) da para las misiones de estancia corta (clase oposición) de 500 a 650 días en total, con 30 a 90 días en las cercanías de Marte, y para las de estancia larga (clase conjunción) de 890 a 950 días en total, con 475 a 540 días en Marte y tránsitos en gravedad cero de unos 180 días. | Verificado | <https://www.nasa.gov/wp-content/uploads/2015/09/373665main_nasa-sp-2009-566.pdf> |
| 24 | Tamaño de la tripulación a Marte en las arquitecturas de referencia de la NASA | La DRA 5.0 (2009) envía una tripulación de seis en cada misión a Marte; el documento Deep Space Exploration Plans de la NASA plantea, como supuestos iniciales representativos de estudio, cuatro tripulantes a la órbita de Marte, de los cuales dos descienden a vivir en la superficie durante una estancia de 30 soles. | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/10/deepspace-exploration-plans-071122.pdf> |
| 25 | Estancia en la superficie lunar y tripulación de Artemis (plan vigente, 2026) | Según las páginas de misión de la NASA, Artemis III (2027, cuatro tripulantes) es una demostración tripulada que cumple objetivos en órbita terrestre baja, y Artemis IV (principios de 2028) lanza a cuatro astronautas en Orion sobre el SLS, de los cuales dos descienden a la superficie para pasar aproximadamente una semana cerca del Polo Sur de la Luna. | Verificado | <https://www.nasa.gov/mission/artemis-iv/> |
| 26 | Misiones más largas en la superficie lunar (cifra de planeación) | El documento técnico de arquitectura de la NASA de 2025 prevé necesidades logísticas anuales de 5,000 a 6,000 kg para cuatro tripulantes que operen en la superficie lunar durante aproximadamente 30 días, y dice que las misiones a Marte podrían durar de dos a tres años. | Verificado | <https://www.nasa.gov/wp-content/uploads/2025/12/acr25-wp-why-moon-and-mars-v2.pdf> |
| 27 | Objetivo científico: recolección de muestras de Perseverance en Jezero | La página de muestras de la NASA (actualizada el 20 de junio de 2026) muestra 30 de 38 tubos de muestra usados (27 núcleos de roca, 2 de regolito, 1 atmosférico) más 3 de 5 tubos testigo, de un total de 43 tubos a bordo. El comunicado de la NASA del 12 de mayo de 2026 dice que Perseverance había desgastado 62 rocas, recolectado 27 núcleos de roca (25 sellados, 2 sin sellar) y recorrido casi 26 millas (42 km); el blog de la misión del 12 de octubre de 2026 todavía dice 29 muestras de roca y regolito. | Verificado | <https://science.nasa.gov/mission/mars-2020-perseverance/mars-rock-samples/> |
| 28 | Objetivo científico: prospección de hielo lunar, estado de VIPER en 2026 | La actualización de la NASA del 20 de octubre de 2026 dice que el rover VIPER está en el Johnson Space Center, completamente construido y en pruebas finales; tras ser entregado por un módulo de aterrizaje Blue Moon Mark 1, emprenderá en 2027 una misión a la región del Polo Sur lunar y recorrerá más de 18 millas (30 km). | Verificado | <https://www.nasa.gov/missions/moon-base/nasa-provides-progress-update-on-moon-base-rovers/> |
| 29 | Objetivo científico: experimento de minería de hielo PRIME-1 | PRIME-1 de la NASA (taladro TRIDENT de 1 metro más el espectrómetro de masas MSOLO) llegó a la Luna en el módulo de aterrizaje Athena de Intuitive Machines el 6 de marzo de 2025, a unos 400 metros de su objetivo en Mons Mouton; el módulo quedó de lado dentro de un cráter, no pudo recargarse y dio unas 10 horas de operación en lugar de 10 días, pero el 100% de los instrumentos funcionó. No se detectó hielo lunar. | Verificado | <https://www.nasa.gov/missions/artemis/nasas-lunar-drill-technology-passes-tests-on-the-moon/> |
| 30 | Definición para niños de un día marciano (sol) | Un día solar de Marte (sol) tiene un periodo medio de 24 horas 39 minutos 35.244 segundos (día sideral 24 h 37 m 22.663 s); el año trópico de Marte es de 686.9725 días o 668.5921 soles. El artículo de la NASA para Grades K-4 dice que un día en Marte dura 24.6 horas y un año, 687 días terrestres. | Verificado | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 31 | Recursos STEM de la NASA y redacción para edades de 7 a 12 años | La NASA publica explicaciones para estudiantes en pares, en los niveles Grades K-4 y Grades 5-8 (por ejemplo, 'What Is Microgravity?' y 'What Is Mars?'); la versión K-4 dice 'La microgravedad es cuando las cosas parecen no pesar nada.' 'Space Faring: The Radiation Challenge' de la NASA tiene una Middle School Edition, pero no se confirmó su nivel escolar exacto. | Corregido | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-microgravity-grades-k-4/> |
| 32 | Recursos Junior Astronauts de la CSA | Las actividades de trabajo en equipo y comunicación de Junior Astronauts de la Agencia Espacial Canadiense están diseñadas para grupos de niños de 6.º a 9.º grado e incluyen 'Survivor: Moon' (90 minutos), en la que los jugadores priorizan los objetos que la tripulación necesita para volver a salvo a una base lunar. | Verificado | <https://asc-csa.gc.ca/eng/youth-educators/junior-astronauts/activities/teamwork-and-communication/default.asp> |
| 33 | fuente en vivo del tiempo de señal actual entre la Tierra y Marte y entre la Tierra y la Luna (DSN Now) | DSN Now de la NASA ('el estado en tiempo real de las comunicaciones con nuestros exploradores del espacio profundo') tiene una fuente XML pública que enumera, por antena, la nave objetivo con su distancia y su tiempo luz de ida y vuelta. Al abrirla el 14 de noviembre de 2026 mostraba a Mars 2020, Odyssey, MRO y TGO a una distancia de 197,000,000 con un tiempo luz de ida y vuelta de 1,320 (unos 11 minutos en un solo sentido), y a LRO a 403,000 con un tiempo luz de ida y vuelta de 2.69. | Verificado | <https://eyes.nasa.gov/dsn/data/dsn.xml> |
| 34 | tiempo luz calculado para cualquier fecha (JPL Horizons) | La API de JPL Horizons devuelve la distancia de Marte y el tiempo luz en un solo sentido para cualquier fecha; por ejemplo, en la conjunción del 9 de enero de 2026, Marte estaba a 2.404 AU de la Tierra, con un tiempo luz en un solo sentido de 19.99 minutos y una elongación solar de 0.95 grados. | Verificado | <https://ssd.jpl.nasa.gov/api/horizons.api?format=text&COMMAND='499'&OBJ_DATA='NO'&MAKE_EPHEM='YES'&EPHEM_TYPE='OBSERVER'&CENTER='500@399'&START_TIME='2026-01-03'&STOP_TIME='2026-01-15'&STEP_SIZE='1d'&QUANTITIES='20,21,23'> |
| 35 | Distancia promedio a la Luna | La NASA dice que la Luna está en promedio a 238,855 millas (384,400 kilómetros); la ESA dice que una señal de radio tarda en promedio 1.27 segundos en viajar de la Luna a la Tierra. | Verificado | <https://science.nasa.gov/moon/facts/> |
| 36 | Latencia lunar en la era Artemis por tipo de dato | La Tabla 1 del NASA TM-20250003885 estima latencias lunares en un solo sentido para Artemis II-IV entre Orion y el Control de Misión en Houston a través de la DSN: comandos 2.7 s nominal y 3.9 s en el peor caso; telemetría 5.9 s y 8.6 s; voz y video 5.6 s y 6.5 s; en Apollo era de 1.3 s. A 2024, las latencias esperadas de Artemis son el doble de las de Apollo, con peores casos de hasta cinco veces. | Verificado | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 37 | Artemis II ya voló | Artemis II despegó el 1 de abril de 2026 y amerizó el 10 de abril de 2026 tras 9 días, 1 hora y 32 minutos, con cuatro astronautas: Reid Wiseman, Victor Glover y Christina Koch, de la NASA, y Jeremy Hansen, de la Agencia Espacial Canadiense. | Verificado | <https://www.nasa.gov/mission/artemis-ii/> |
| 38 | Récord de distancia recorrida fuera de la Tierra de Perseverance | El 11 de octubre de 2026 (sol 2,006), el odómetro de Perseverance llegó a 28.10 millas (45.22 km) y superó las 28.06 millas (45.16 km) de Opportunity; ha recorrido más del 90% de su distancia con AutoNav y hasta 1,351 pies (412 metros) en un solo sol. | Verificado | <https://science.nasa.gov/blogs/perseverance-mars-rover/2026/10/12/nasas-perseverance-sets-off-world-record-for-total-distance-driven/> |
| 39 | comunicaciones láser como mejora futura (DSOC) | La demostración Deep Space Optical Communications de la NASA en Psyche alcanzó su tasa máxima de 267 megabits por segundo (por primera vez el 11 de diciembre de 2023, desde 19 millones de millas) y todavía podía lograrla a unos 33 millones de millas; el 24 de junio de 2024, desde unos 240 millones de millas, sostuvo 6.25 Mbps con un máximo de 8.3 Mbps. El JPL dice que los láseres pueden transmitir datos a tasas hasta 100 veces mayores que la radio. | Verificado | <https://www.jpl.nasa.gov/news/nasas-laser-comms-demo-makes-deep-space-record-completes-first-phase/> |
| 40 | cómo devuelve realmente los datos la retransmisión | La NASA dice que los orbitadores de la Mars Relay Network primero recogen los datos de los rovers y luego giran sus antenas hacia la Tierra, devolviendo datos alrededor de una docena de veces por semana; la duración de cada paso varía de un día a otro, y actualmente la red retransmite para los rovers Curiosity y Perseverance. | Verificado | <https://science.nasa.gov/mars/mars-relay-network/> |

<details><summary>Notas de verificación de esta sección</summary>

Se volvieron a abrir los 32 datos del investigador: 29 verificados, 3 corregidos, ninguno descartado ni sin verificar. Agregué 8 datos, cada uno abierto por mí.  MÉTODO: las páginas web se abrieron con la herramienta de descarga. La herramienta de descarga no pudo procesar los seis PDF de la NASA (artículo de ASCEND, documento técnico de comunicaciones con Marte, Why Moon and Mars, TM-20250003885, Deep Space Exploration Plans, DRA 5.0) ni la actividad Radio JOVE; ejecuté pdftotext hacia la salida estándar sobre las copias que guardó la herramienta y encontré las oraciones citadas. No se escribieron archivos en el proyecto.  CORRECCIONES: - Pasos de retransmisión: '2-4 pasos por día' es el total de sobrevuelos por orbitador. Los pasos que realmente se usan para retransmitir son Odyssey 0-1, MRO 1-3, TGO 2-4. - Próxima conjunción: el 21 de marzo de 2028 ya está confirmado con JPL Horizons (elongación mínima de 0.81 grados), así que puede atribuirse a la NASA/JPL. La hora no está verificada. - Unidad de radiación de Space Faring: la etiqueta 'grados 6-8' no está confirmada. Las páginas STEM de la NASA solo devolvieron una página de búsqueda, y los fragmentos sugieren Grades 5-8.  MATICES QUE IMPORTAN PARA LOS JUECES: - El apagón de 21 días del documento técnico de comunicaciones con Marte ocurre durante el tránsito de regreso de una misión de estancia corta, no en la superficie. Solo la cifra de 13 días es un apagón en las cercanías de Marte. Ambas suponen un umbral de 2 grados entre el Sol, la Tierra y la nave. - En la conjunción, el retraso en un solo sentido es de unos 20.0 minutos (Horizons, 9 de enero de 2026), no el máximo de 22.4 minutos. - 14 días terrestres son unos 13.6 soles; no imprimir '14 soles' como cifra de la NASA. - Los pares de banda X de Perseverance (160/500 y 800/3,000 bps) no están etiquetados en la página como enlace ascendente o descendente. - 'Alrededor de 3% más largo' para un sol no es una cita de la NASA; la aritmética da 2.75%. - La cifra del 99.9% de UHF viene del kit de prensa del aterrizaje de 2021, que todavía enumera a MAVEN como retransmisor; MAVEN terminó el 3 de junio de 2026. - La página de CHAPEA no vincula por sí misma el apagón de dos semanas con la conjunción solar. - El conteo de muestras no ha cambiado según el blog de la NASA del 12 de octubre de 2026 ('29 muestras de roca y regolito', más 1 atmosférica = 30), así que la etiqueta puede decir 'a octubre de 2026'. La nota del investigador de 'nada más reciente que junio de 2026' queda superada.  CONFLICTOS CONFIRMADOS ENTRE FUENTES DE LA NASA: el rango de retraso a Marte es de 3-22.4 min (Mars Relay Network), 4-24 min (Goddard, documento técnico de 2025), hasta 20 min (HRP) y hasta 22 min (TM, CHAPEA, ASCEND). Se recomienda 3-22.4 min con km para la simulación. La frecuencia de las conjunciones es 'aproximadamente cada 26 meses' (página de recursos) frente a 'cada dos años' (JPL 2023). La distancia de DSOC el 24 de junio de 2024 es de 249 millones de millas en la página de la misión de la NASA frente a unos 240 millones en el comunicado del JPL.  EN VIVO FRENTE A ESTÁTICO: la única fuente en vivo verificada es la fuente XML de DSN Now (eyes.nasa.gov/dsn/data/dsn.xml). Sus unidades no se indican en la fuente; se infieren km y segundos. Todo lo demás es estático o una instantánea fechada y debe llevar una fecha de vigencia. Los valores de JPL Horizons son efemérides calculadas, no mediciones en vivo.  NO SE PUDO ABRIR NI CONFIRMAR: science.nasa.gov/mission/msl-curiosity/rover-components/ y /communications/ devolvieron 404, así que no hay ninguna cifra verificada de megabits por paso o por sol para ningún rover (las cifras de '100 a 250 megabits por paso de ocho minutos' y '500 megabits por sol' son solo de fragmentos; no usar). La antigua URL HTML de Radio JOVE que probé devolvió 404 (la actividad en PDF sí funcionó). '2.6 s ida y vuelta' a la Luna no aparece textualmente en ninguna página de la NASA abierta. No se revisaron el fragmento de '45 minutos en cada sentido' ni la dependencia del contrato de Blue Moon MK1 para VIPER. Los límites de Roblox y los endpoints de DONKI no formaban parte de esta lista de datos y no se revisaron.

</details>

#### Tarjetas coleccionables (mito frente a ciencia)

Estos datos provienen de la primera pasada de comprobación de datos del 14 de noviembre de 2026, hecha sobre el documento de diseño original del equipo.

| # | Tarjeta | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Mini Tierra | A la altitud de la Estación Espacial, la gravedad sigue siendo de alrededor del 90% de la de la Tierra; los astronautas flotan porque están en caída libre continua | Verificado (página abierta) | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-microgravity-grades-5-8/> |
| 2 | Laika | Laika, lanzada en el Sputnik 2 el 3 de noviembre de 1957, fue el primer animal en orbitar la Tierra (no el primer ser vivo en el espacio: unas moscas de la fruta volaron en 1947) | Verificado (fragmento de búsqueda de una página de la NASA) | <https://www.nasa.gov/history/60-years-ago-the-first-animal-in-orbit/> |
| 3 | Queso lunar | El suelo lunar es aproximadamente 40–45% oxígeno en masa (el juego dice alrededor de 43%); las tierras altas son anortosita y los mares son basalto | Verificado (fragmento de búsqueda de una página de la ESA) | <https://www.esa.int/Enabling_Support/Space_Engineering_Technology/Team_chosen_to_make_first_oxygen_on_the_Moon> |
| 4 | Papa marciana | La "Cara en Marte" fue fotografiada por el orbitador Viking 1 el 25 de julio de 1976 en Cydonia; imágenes posteriores (1998, 2001) mostraron una meseta erosionada | Verificado (fragmento de búsqueda de una página de la NASA) | <https://science.nasa.gov/resource/mars-orbiter-camera-views-the-face-on-mars-comparison-with-viking/> |
| 5 | Papa marciana | Phoenix encontró percloratos en el suelo marciano en 2008, alrededor de 0.4–0.6% en masa; el perclorato es tóxico para las personas | Verificado (fragmento de búsqueda de un artículo) | <https://ui.adsabs.harvard.edu/abs/2013IJAsB..12..321D> |

#### Construcción de la base, rovers y mascotas (Etapa 6)

Datos detrás de los cambios de la Etapa 6: C.A.R.L. avanza sobre orugas y salta con soplos de gas, el doble salto con la mochila, la antena láser, los taladros de hielo, la construcción con polvo lunar, los arreglos solares altos y las cuatro mascotas. Cada fuente de abajo se abrió el 14 de noviembre de 2026 (fecha de consulta).

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | La Luna casi no tiene aire | La página 'The Moon's Atmosphere' de la NASA dice que la Luna tiene atmósfera, 'pero apenas'; es sobre todo una exosfera, 'que a su vez es en su mayor parte espacio vacío', con alrededor de mil billones (10^15) de veces menos moléculas por centímetro cúbico que la atmósfera de la Tierra, así que un visitante 'podría pensar que no tiene atmósfera en absoluto'. La página de datos de la Luna de la NASA agrega que esta exosfera no da protección contra la radiación del Sol ni contra los impactos de meteoroides. | Verificado | <https://science.nasa.gov/moon/lunar-atmosphere/> |
| 2 | Las hélices necesitan aire (por qué C.A.R.L. avanza sobre orugas) | La página 'Propeller Thrust' de NASA Glenn explica que el motor hace girar la hélice, que 'realiza trabajo sobre el flujo de aire': el aire que la rodea pasa a través de la hélice giratoria y sale más rápido de lo que entró, y esa aceleración del aire es lo que produce el empuje. Casi sin aire (fila 1), una hélice no tiene nada que empujar, así que C.A.R.L. avanza sobre orugas. La oración 'no se puede volar con hélices en la Luna' es un razonamiento del equipo a partir de las filas 1 y 2, no una cita de la NASA. | Verificado | <https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/propeller-thrust/> |
| 3 | Los cohetes y los propulsores de gas funcionan sin aire | La página para niños de la NASA 'What Is a Rocket? (Grades K-4)' dice 'Un motor de cohete no necesita aire' y 'lleva consigo todo lo que necesita'; 'El cohete empuja sus gases de escape. Los gases de escape también empujan al cohete', y los cohetes funcionan gracias a la tercera ley del movimiento de Newton. Por eso el salto de C.A.R.L. y el doble salto con la mochila usan soplos de gas. | Verificado | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-a-rocket-grades-k-4/> |
| 4 | Tercera ley de Newton (redacción) | NASA Glenn: 'Siempre que un objeto ejerce una fuerza sobre un segundo objeto, el segundo objeto ejerce una fuerza igual y opuesta sobre el primero.' | Verificado | <https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/newtons-laws-of-motion/> |
| 5 | La comunicación láser transporta más datos que la radio | NASA Goddard (12 de mayo de 2021, 'Laser Communications: Empowering More Data Than Ever Before'): 'Las comunicaciones láser permitirán transmitir de vuelta a la Tierra de 10 a 100 veces más datos que los sistemas actuales de radiofrecuencia.' El artículo de la NASA sobre LCRD (28 de junio de 2023, 'NASA's Laser Communications Relay: A Year of Experimentation') dice que los láseres infrarrojos permiten a las misiones enviar de 10 a 100 veces más datos en una sola transmisión; la página Laser Communications de la NASA subraya que las señales láser y de radio viajan ambas a la velocidad de la luz, así que la ganancia es más datos por enlace, no un viaje más rápido. | Verificado | <https://www.nasa.gov/feature/goddard/2021/laser-communications-empowering-more-data-than-ever-before> |
| 6 | Las manchas oscuras de la Luna (mares) y de qué está hecha la Luna | Página de datos de la Luna de la NASA: 'Las zonas oscuras, llamadas maria (en latín, mares), son cuencas de impacto que se llenaron de lava' hace entre 4.2 y 1.2 mil millones de años; 'Casi toda la Luna está cubierta por un montón de escombros de polvo fino gris carbón y restos rocosos' llamado regolito lunar, con roca madre fracturada (megarregolito) debajo. Coincide con la tarjeta Queso lunar (fila 3 de Tarjetas coleccionables): la Luna es roca y polvo, no queso. | Verificado | <https://science.nasa.gov/moon/facts/> |
| 7 | El conejo en la Luna (muchas culturas) | El artículo de enciclopedia 'Moon rabbit' dice que los mares oscuros de la cara visible de la Luna se interpretan como un conejo o una liebre: en China, el Conejo de Jade (Yutu), compañero de Chang'e, machaca el elixir de la vida (la fuente más antigua es el Chu Ci); en Japón machaca arroz para hacer mochi, y en Corea para hacer tteok; Vietnam y los cree también tienen relatos del conejo de la Luna; en la tradición azteca (mexica), los dioses lanzan un conejo a la cara de Tecciztécatl después de que se convierte en la Luna, lo que atenúa su luz (citado de Michael E. Smith, The Aztecs, 3rd ed., 2012, p. 200). Una versión azteca distinta, en la que Quetzalcóatl sube a un conejo bondadoso a la Luna, está marcada ahí como 'citation needed', así que el juego no la cuenta. | Verificado (enciclopedia, secundaria) | <https://en.wikipedia.org/wiki/Moon_rabbit> |
| 8 | Ham, el chimpancé | Pie de foto de la NASA: 'Lanzamiento del vehículo Mercury-Redstone 2 (MR-2) el 31 de enero de 1961. El vuelo suborbital de 16 minutos llevó a bordo al chimpancé (Ham) como sujeto de prueba biomédica.' 'A Brief History of Animals in Space' de la NASA dice que Ham tuvo un buen desempeño, que después del vuelo solo se le encontró 'ligeramente fatigado y deshidratado' y que más tarde vivió en el Zoológico de Washington. Ham era un chimpancé (un simio), no un mono. | Verificado | <https://www.nasa.gov/image-detail/amf-s61-01942> |
| 9 | Los monos llegaron al espacio antes que las personas | 'A Brief History of Animals in Space' de la NASA: 'El 14 de junio de 1949, un segundo vuelo de un V-2 que llevaba un mono vivo del Air Force Aeromedical Laboratory, Albert II, alcanzó una altitud de 83 millas.' The Planetary Society: 'Yuri Gagarin se convirtió en el primer ser humano en volar al espacio el 12 de abril de 1961.' | Verificado | <https://www.nasa.gov/history/a-brief-history-of-animals-in-space/> |
| 10 | Laika, primer animal en órbita (página ya abierta) | '60 years ago: The First Animal in Orbit' de la NASA (John Uri, 6 de noviembre de 2017) dice que el Sputnik 2 despegó el 3 de noviembre de 1957 con la perrita Laika, 'el primer animal en orbitar la Tierra'. Esto mejora la fila 2 de Tarjetas coleccionables de fragmento de búsqueda a página abierta. | Verificado | <https://www.nasa.gov/history/60-years-ago-the-first-animal-in-orbit/> |
| 11 | Prueba de un taladro de hielo en el polo sur de la Luna (PRIME-1 / TRIDENT) | NASA (29 de abril de 2025, 'NASA's Lunar Drill Technology Passes Tests on the Moon'): PRIME-1 llevó TRIDENT, un taladro de 1 metro de largo de Honeybee Robotics, en el módulo de aterrizaje IM-2 Athena de Intuitive Machines, que se posó el 6 de marzo de 2025 a unos 400 m de Mons Mouton, cerca del Polo Sur, y terminó de lado dentro de un cráter. Al recibir la orden, la barrena giró, el taladro se extendió por completo y el sistema de percusión golpeó; el espectrómetro de masas MSOLO hizo barridos de gases; 'el 100% de los instrumentos funcionó', pero las operaciones duraron 'más bien 10 horas' en lugar de los 10 días planeados. Los gases detectados fueron en su mayoría de origen humano (propelente liberado, trazas de agua de la Tierra). El juego dice que el taladro se 'probó', nunca que encontró hielo (coincide con la fila 29 de Comunicaciones). | Verificado | <https://www.nasa.gov/missions/artemis/nasas-lunar-drill-technology-passes-tests-on-the-moon/> |
| 12 | Construir con polvo lunar (MMPACT) | El proyecto MMPACT de la NASA (Marshall) busca 'crear infraestructura en la superficie lunar mediante la construcción de plataformas de aterrizaje, hábitats, refugios, caminos, bermas y muros contra explosiones con materiales a base de regolito lunar', aprovechando el 3D Printed Mars Habitat Challenge de la NASA (resumen de IAC 2022, NTRS 20220013524). Las diapositivas del proyecto para ASCEND (NTRS 20210022078) enumeran procesos con regolito 'Cementitious, Geopolymers, Thermosetting materials, including melting, Laser sintered, Microwave sintered', con la meta de 'Demonstrate microwave sintering construction of subscale structures' usando simulante de regolito lunar, y una misión de demostración inicial DM-1 planeada para 2026 (un plan en diapositivas antiguas, no un resultado de vuelo). | Verificado | <https://ntrs.nasa.gov/citations/20220013524> |
| 13 | Arreglos solares verticales altos para el Sol bajo de los polos | NASA (23 de agosto de 2022, 'Three Companies to Help NASA Advance Solar Array Technology for Moon'): la orientación vertical y la altura de los nuevos diseños ayudan a evitar la pérdida de energía en los polos lunares, 'donde el Sol no se eleva mucho sobre el horizonte'; los arreglos pueden desplegarse de forma autónoma hasta 32 pies de altura (unos 9.8 m, derivado) y retraerse para reubicarse; $19.4 millones en total para Astrobotic, Honeybee Robotics y Lockheed Martin, con la meta de desplegar uno cerca del Polo Sur hacia el final de la década. NASA Johnson (19 de noviembre de 2024) probó prototipos en su cámara de vacío térmico Chamber A. Coincide con las filas 28 y 33 de Energía (mejores sitios en la cresta, paneles a 2 m de altura, Vertical Solar Array Technology con 10 kW). | Verificado | <https://www.nasa.gov/news-release/three-companies-to-help-nasa-advance-solar-array-technology-for-moon> |
| 14 | Altitud de Albert II en km | 83 millas son unos 134 km (derivado: 83 x 1.609). El juego no muestra este número. | Verificado (derivado) | <https://www.nasa.gov/history/a-brief-history-of-animals-in-space/> |

<details><summary>Notas de verificación de esta sección</summary>

MÉTODO (2026-11-14, fecha de consulta de cada fuente): las páginas de la NASA se abrieron con una herramienta de descarga que devuelve fragmentos citados breves. Al PDF de MMPACT para ASCEND se le extrajo el texto con pdftotext hacia la salida estándar (la copia queda en la carpeta de resultados de herramientas de la sesión; no se escribió nada adicional en el proyecto). Solo se usó una fuente de enciclopedia donde la NASA no tiene página (leyendas del conejo).

SEGUNDAS FUENTES ABIERTAS: artículo de la NASA sobre LCRD <https://www.nasa.gov/missions/tech-demonstration/nasas-laser-communications-relay-a-year-of-experimentation/>; página Laser Communications de la NASA <https://www.nasa.gov/directorates/spacetech/lasercomms> (sin multiplicador; subraya más datos por enlace); datos de la Luna de la NASA <https://science.nasa.gov/moon/facts/> (exosfera); diapositivas de MMPACT <https://ntrs.nasa.gov/api/citations/20210022078/downloads/MMPACT_ASCEND.pdf>; prueba en cámara de NASA Johnson <https://www.nasa.gov/centers-and-facilities/johnson/from-houston-to-the-moon-johnsons-thermal-vacuum-chamber-tests-lunar-solar-technology/>; Vostok 1 en The Planetary Society <https://planetary.org/space-missions/vostok-1>.

PRECAUCIONES: - La página de imagen de la NASA sobre Ham tiene 'Jan. 21, 1961' en su título pero 'Jan. 31, 1961' en su pie de foto; usar el 31 de enero (coincide con la página de historia de los animales de la NASA). - Según la página de historia de la NASA, Albert II murió al aterrizar, y Laika no regresó. El juego se mantiene amable: dice que 'llegaron al espacio' u 'orbitaron la Tierra' y nunca describe sus muertes. Ham regresó a salvo. - En el juego, la mascota 'mono' debe llamarse chimpancé espacial: Ham era un chimpancé. - La ganancia del láser es 'más datos'; el dato curioso existente 'hasta 100 veces más rápido' se basa en la redacción del JPL 'tasas hasta 100 veces mayores' (fila 39 de Comunicaciones). - Las fechas de MMPACT (DM-1 2026) vienen de diapositivas de 2021-2022; no se abrió ninguna actualización de estado de la NASA de 2026, así que el juego dice que la NASA 'estudia' o 'prueba' construir con polvo lunar, nunca que ya haya construido algo en la Luna. - Desplegar un arreglo vertical cerca del Polo Sur es una meta; ninguna fuente abierta dice que ya haya ocurrido.

DESCARTADOS (sin verificar, no mostrar): - Las cifras del Artemis II Optical Communications System (O2O), como 260 Mbps, video 4K y 'más de 484 gigabytes', solo aparecieron en artículos de noticias y fragmentos de búsqueda; no se abrió ninguna página de la NASA posterior al vuelo. - El intercambio de la 'chica del conejo' del Apollo 11 (Houston contándole a la tripulación sobre Chang'e y su conejo, el 20 de julio de 1969) solo apareció en Spacelog y Science Friday, no en una página de transcripción de la NASA abierta. - La versión azteca con Quetzalcóatl y el conejo no tiene fuente en el artículo de enciclopedia abierto. - No se encontró ninguna declaración de la NASA de que los robots 'no pueden volar' en la Luna; la explicación de las orugas es un razonamiento del equipo a partir de las filas 1 y 2.

</details>

#### Sitios de exploración, meteoritos, plataformas de aterrizaje y carritos lunares (Etapa 7)

Datos detrás de los cambios de la Etapa 7: los cinco sitios de exploración que se escanean con la tableta, el evento aleatorio de impacto de meteorito, la plataforma de aterrizaje y la nave, el carrito lunar y el camión de hielo que se pueden manejar, y sus ruedas con buen agarre. Cada fuente de abajo se abrió el 15 de noviembre de 2026 (fecha de consulta). Los sitios del juego son representaciones inspiradas en estos lugares reales; el juego nunca dice que un módulo de aterrizaje real o un sitio de choque real esté junto a la base del jugador.

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Módulo de aterrizaje robótico cerca del polo sur: IM-1 Odysseus (sitio old_lander) | NASA (comunicado de imágenes de LRO): el 22 de febrero de 2024, el módulo de aterrizaje Nova-C Odysseus de Intuitive Machines 'se posó suavemente cerca del cráter Malapert A, en la región del Polo Sur de la Luna'; LRO lo fotografió el 24 de febrero desde unos 90 km de altura; quedó en reposo a 80.13 grados sur, 1.44 grados este, a 2,579 m de elevación, dentro de un cráter degradado de alrededor de 1 km de ancho, sobre un terreno con una pendiente de unos 12 grados. El artículo de CLPS de la NASA dice que Odysseus 'está suavemente inclinado sobre la superficie lunar', que era la primera vez en más de 50 años que una organización estadounidense posaba instrumentos en la Luna, que se bajaron más de 500 megabytes de datos y que las operaciones terminaron siete días después del aterrizaje. Los reportes de prensa que citan a la empresa dicen que se volcó de lado; el juego solo dice que terminó inclinado. Ver también la fila 11 de la Etapa 6: IM-2 Athena (6 de marzo de 2025) también terminó de lado. | Verificado | <https://www.nasa.gov/missions/lro/nasas-lro-images-intuitive-machines-odysseus-lander/> |
| 2 | Chandrayaan-3 cerca del polo sur | NASA ('NASA's LRO Observes Chandrayaan-3 Landing Site', 5 de septiembre de 2023): Chandrayaan-3 de la ISRO se posó el 23 de agosto de 2023; el sitio está a unos 600 km del Polo Sur de la Luna; la cámara de LRO tomó una vista oblicua cuatro días después, y 'el halo brillante alrededor del vehículo se formó por la interacción del penacho del cohete con el regolito de grano fino'. La página del APXS de la ISRO da para el sitio 69.37 grados S, 32.32 grados E, medidos por el instrumento del rover Pragyan. | Verificado | <https://www.nasa.gov/image-article/nasas-lro-observes-chandrayaan-3-landing-site/> |
| 3 | Impacto de LCROSS (sitio impact_crater) | Página de la misión LCROSS de la NASA: LCROSS despegó el 18 de junio de 2009; su etapa de cohete Centaur agotada 'se estrelló contra la superficie de la Luna a las 11:31 UT en el cráter Cabeus, en el polo sur lunar' el 9 de octubre de 2009, formando un cráter de unos 20 m (66 ft) de ancho; la meta era confirmar la presencia de hielo de agua en un cráter en sombra permanente, y la NASA dice que los datos 'indican que la misión logró descubrir agua'; un seguimiento de 2010 encontró que en algunos lugares el agua es cristales de hielo puro. Coincide con la fila 20 de Soporte vital. | Verificado | <https://science.nasa.gov/mission/lcross/> |
| 4 | Huellas de rocas rodantes (sitio boulder_tracks) | LROC (el equipo de la cámara de LRO, Arizona State University), 'Rolling Rolling Rolling': las huellas de rocas se ven a menudo en las paredes de los cráteres y en sus picos centrales; 'cuando un impacto o un sismo lunar suelta una roca, esta sigue moviéndose'; las huellas se ven continuas y lisas, como una canica rodada sobre arena, así que las rocas rodaron en lugar de rebotar; las cuatro rocas que se muestran miden de unos 7 a 9 m de ancho, en la pared del cráter Pikel'ner S. NASA Photojournal (LROC NAC M139802338L, cráter Menelaus): las huellas de rocas se forman 'a medida que los materiales se erosionan desde las zonas más altas y ruedan hacia el fondo del cráter'. | Verificado | <https://lroc.im-ldi.com/images/509> |
| 5 | Choque de Lunar Prospector (sitio prospector_crash) | NASA NSSDCA: Lunar Prospector despegó el 7 de enero de 1998; la misión terminó el 31 de julio de 1999 a las 9:52 UT, cuando la nave se estrelló a propósito en una zona en sombra permanente de un cráter cerca del polo sur lunar, con la esperanza de liberar vapor de agua del hielo que se sospechaba que había; 'no se observó ningún penacho'. El comunicado de la NASA del 13 de octubre de 1999, 'No Water Ice Detected From Lunar Prospector Impact', dice que el impacto 'no produjo ninguna señal observable de agua', lo que no descarta el hielo; el choque se planeó porque Lunar Prospector había medido grandes cantidades de hidrógeno en los polos. El comunicado del 2 de junio de 1999 estimaba la probabilidad de éxito en alrededor del 10 por ciento. Más tarde, LCROSS encontró agua (fila 3). | Verificado | <https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1998-001A> |
| 6 | Picos soleados (sitio sun_peak) | NASA Science ('Shackleton Crater's Illuminated Rim & Shadowed Interior'): 'Mientras que los picos a lo largo del borde del cráter están expuestos a una luz solar casi continua, el interior está en sombra perpetua'; 'tres puntos del borde del cráter permanecen, en conjunto, iluminados por el Sol más del 90% del año'; esto se debe a que el eje de la Luna está inclinado solo 1.5 grados (el de la Tierra, 23.5), así que en el Polo Sur el Sol roza el horizonte todo el año. Coincide con las filas 27 y 28 de Energía (240 días al año en un punto; ningún lugar iluminado de forma permanente). | Verificado | <https://science.nasa.gov/resource/shackleton-craters-illuminated-rim-shadowed-interior/> |
| 7 | Por qué los meteoroides golpean la Luna con un destello y no con una estela | Meteoroid Environment Office de la NASA ('About Lunar Impact Monitoring'): 'La Luna, sin embargo, tiene poca o ninguna atmósfera, así que nada impide que los meteoroides choquen contra la superficie'; un impacto produce un breve 'destello brillante en el punto de impacto', por lo general de menos de medio segundo; las más lentas de estas rocas viajan a 20 km/s y las más rápidas a más de 72 km/s; un meteoroide de 5 kg puede abrir un cráter de más de 9 m de ancho; la tasa de impactos lunares todavía es muy incierta. La oración 'en la Luna no hay estela ardiente' es un razonamiento del equipo a partir de esta fila y de la fila 8. | Verificado | <https://www.nasa.gov/meteoroid-environment-office/about-lunar-impact-monitoring> |
| 8 | Meteoroide, meteoro, meteorito | NASA Science ('Meteors and Meteorites: Facts'): 'Los meteoroides son rocas espaciales cuyo tamaño va desde granos de polvo hasta pequeños asteroides'; 'Cuando los meteoroides entran a gran velocidad en la atmósfera de la Tierra, o en la de otro planeta, y se queman, se llaman meteoros'; uno que sobrevive y llega al suelo es un meteorito; cada día caen sobre la Tierra unos 44,000 kg (48.5 toneladas) de material meteorítico. | Verificado | <https://science.nasa.gov/solar-system/meteors-meteorites/facts/> |
| 9 | Destellos de impactos en la Luna vistos desde la Tierra | Blog Watch the Skies de la NASA (12 de marzo de 2026, 'NASA Marshall Lunar, Meteor Observatory Marks 20 Years of Discovery'): los astrónomos de Marshall han observado más de 400 impactos en la superficie lunar; el observatorio registró su primer destello de impacto lunar el 2 de mayo de 2006; el 17 de marzo de 2013, 'un meteoroide del tamaño de una bola de boliche' produjo un destello brillante y un cráter de unos 60 ft de ancho, confirmado después por LRO. | Verificado | <https://www.nasa.gov/blogs/watch-the-skies/2026/03/12/nasa-marshall-lunar-meteor-observatory-marks-20-years-of-discovery/> |
| 10 | El impacto del 17 de marzo de 2013 en números | NASA Scientific Visualization Studio: un meteoroide de 'aproximadamente un pie (30 a 40 cm) de ancho', con una masa de unos 40 kg, golpeó la Luna a unos 25 km/s (60,000 mph); el destello fue uno de los más brillantes jamás registrados; las imágenes de LRO de antes (12 de febrero de 2012) y de después (28 de julio de 2013) muestran 'un cráter nuevo de 18 metros (60 pies) de ancho, con rayos de material expulsado que se extienden varios kilómetros'. | Verificado | <https://svs.gsfc.nasa.gov/4242> |
| 11 | Siguen apareciendo cráteres nuevos | NASA (octubre de 2016, 'Earth's Moon Hit by Surprising Number of Meteoroids'): las imágenes de LRO mostraron más de 200 cráteres que se formaron durante la misión, de unos 3 a 43 m de ancho, alrededor de 30 por ciento más de lo que esperaban los modelos, además de más de 47,000 pequeños cambios en la superficie ('manchas'). NASA Science (16 de septiembre de 2026, 'NASA's Moon Orbiter Spots New, Once-in-Century Moon Crater'): el equipo de LRO 'ha identificado al menos 1,000 cráteres de impacto nuevos a lo largo de la misión'; un cráter de 728 ft (unos 222 m, derivado) de ancho y 141 ft de profundidad se formó entre el 11 de abril y el 22 de mayo de 2024, con estelas brillantes de material lanzado en todas direcciones; un impacto así ocurre alrededor de una vez por siglo o con menos frecuencia. | Verificado | <https://science.nasa.gov/solar-system/moon/nasas-moon-orbiter-spots-new-once-in-century-moon-crater/> |
| 12 | Los gases de escape de los cohetes levantan polvo lunar | NASA ('Rocket Exhaust on the Moon: NASA Supercomputers Reveal Surface Effects'): durante el aterrizaje y el despegue, los penachos de los motores golpean la superficie y 'las intensas fuerzas levantan polvo y expulsan rocas u otros escombros a gran velocidad', formando nubes de polvo que pueden interferir con la navegación y con los instrumentos científicos; las simulaciones de Marshall del Apollo 12 coincidieron con la erosión real; no se sabe cuánto erosionarán la superficie los módulos de aterrizaje de Artemis, que son más grandes. | Verificado | <https://www.nasa.gov/general/rocket-exhaust-on-the-moon-nasa-supercomputers-reveal-surface-effects/> |
| 13 | El Apollo 12 arenó al Surveyor 3 | 'Recommendations to Space-Faring Entities' de la NASA (publicado el 20 de julio de 2011; copia subida en diciembre de 2023): las partículas del penacho pueden salir a entre 300 y 2,000 m/s y seguir avanzando porque el aire es despreciable; grava y rocas de 1 a 10 cm salieron disparadas a 5 a 50 m/s hasta a 1.5 km de distancia; 'El LM del Apollo 12 aterrizó a 155 m de la nave Surveyor 3', y aunque el Surveyor estaba dentro de un cráter, por debajo de la capa principal de polvo, 'recibió un arenado y picaduras considerables'. | Verificado | <https://www.nasa.gov/wp-content/uploads/2023/12/nasa-usg-lunar-historic-sites-reva.pdf> |
| 14 | Las plataformas de aterrizaje detienen la lluvia de material | NASA Kennedy Swamp Works (NTRS 20210020967, 'In-situ Lunar Launch and Landing Pad Construction with Regolith-Thermoset Polymer Composite Materials'): las plataformas son 'necesarias para mitigar los riesgos para los vehículos de aterrizaje y ascenso y para los activos de superficie cercanos debidos al regolito expulsado por el penacho del cohete', con riesgos mayores para Artemis por su mayor empuje; en pruebas de encendido en la Tierra, 'todos los artículos de prueba mitigaron con éxito el material de regolito expulsado por los efectos del penacho', aunque algunos se erosionaron. Coincide con la fila 12 de la Etapa 6 (MMPACT estudia plataformas de aterrizaje hechas de polvo lunar). Ninguna fuente abierta dice que se haya construido una plataforma de aterrizaje en la Luna; la plataforma y la nave del juego son decoración y una meta. | Verificado | <https://ntrs.nasa.gov/citations/20210020967> |
| 15 | Vehículo Lunar Itinerante de Apollo | NASA NSSDCA ('The Apollo Lunar Roving Vehicle'): se condujeron tres LRV en la Luna, uno en cada misión Apollo 15, 16 y 17; masa de 210 kg, diseñado para llevar 490 kg más; chasis de 3.1 m de largo; dos asientos plegables lado a lado; energía de dos baterías no recargables de 36 volts; 'Una gran antena de plato de malla iba montada en un mástil al frente y al centro del rover'; llantas de hilos de acero tejido recubiertos de zinc con chevrones de titanio que cubrían el 50% del área de contacto para dar tracción; se condujo 27.8 km en el Apollo 15, 26.7 km en el Apollo 16 y 35.9 km en el Apollo 17. | Verificado | <https://nssdc.gsfc.nasa.gov/planetary/lunar/apollo_lrv.html> |
| 16 | Por qué las ruedas lunares necesitan agarre, y no llantas de aire | NASA Glenn (NASA/TM-2009-215798, 'The Development of Wheels for the Lunar Roving Vehicle', diciembre de 2009): las ruedas lunares deben funcionar en 'un campo de gravedad baja (1/6 de la gravedad de la Tierra)'; las ruedas de alambre 'podían diseñarse para deformarse de manera significativa y así dar una gran capacidad de tracción, incluso con el peso relativamente bajo de los vehículos lunares en 1/6 de gravedad'; 'las ruedas lunares ejercen una presión relativamente baja sobre el suelo en 1/6 de gravedad'; se descartaron las llantas llenas de aire (neumáticas) por el riesgo de que se desinflaran en la Luna sin aire y por el daño de la luz solar al hule, y una llanta ponchada 'no es aceptable para un vehículo tripulado'; la Figura 1(a) indica una velocidad máxima del LRV de 16 km/hr; la rueda se desarrolló en 17 meses, de octubre de 1969 a marzo de 1971. La frase 'las ruedas necesitan agarre extra' es redacción del equipo a partir de estas citas. | Verificado | <https://ntrs.nasa.gov/api/citations/20100000019/downloads/20100000019.pdf> |
| 17 | Reparación de la salpicadera del Apollo 17 | Artículo con imagen de la NASA 'Duct Tape Saves the Day!': la salpicadera de repuesto del rover del Apollo 17 está en la parte trasera derecha, sujeta con dos pinzas, y 'la cruz gris es cinta adhesiva plateada usada para mantener unidos los cuatro mapas con los que se hizo la salpicadera'. NASA APOD (14 de diciembre de 2022, 'Lunar Dust and Duct Tape'): Schmitt y Cernan necesitaban reparar una salpicadera para 'mantener las colas de gallo de polvo lejos de ellos y de su equipo', usando mapas de repuesto, pinzas y cinta adhesiva plateada. | Verificado | <https://www.nasa.gov/image-article/duct-tape-saves-day/> |

<details><summary>Notas de verificación de esta sección</summary>

MÉTODO (2026-11-15, fecha de consulta de cada fuente): las páginas de la NASA se abrieron con una herramienta de descarga que devuelve fragmentos citados breves. Dos PDF de la NASA (el memorando técnico sobre las ruedas del LRV y las recomendaciones sobre sitios históricos lunares) llegaron como binarios; la herramienta de descarga guardó sus propias copias y les extraje el texto hacia la salida estándar con pdftotext (no se escribieron archivos en el proyecto). Se abrió la fuente de cada fila; las segundas fuentes se enumeran abajo.

SEGUNDAS FUENTES ABIERTAS: artículo de CLPS de la NASA 'NASA Collects First Surface Science in Decades via Commercial Moon Mission' <https://www.nasa.gov/missions/artemis/clps/nasa-collects-first-surface-science-in-decades-via-commercial-moon-mission/> (fila 1); página del APXS de la ISRO <https://www.isro.gov.in/Ch3_Alpha_Particle_X-ray_Spectrometer.html> (fila 2); huellas de rocas de Menelaus en NASA Photojournal <https://science.nasa.gov/photojournal/boulder-trails-in-menelaus-crater/> (fila 4); comunicado de la NASA del 13 de octubre de 1999 <https://nssdc.gsfc.nasa.gov/planetary/text/lp_pr_19991013.txt> y comunicado del 2 de junio de 1999 <https://nssdc.gsfc.nasa.gov/planetary/news/lp_pr_19990602.html> (fila 5); comunicado de la NASA de 2016 sobre cráteres de LRO <https://nasa.gov/press-release/goddard/2016/lro-lunar-cratering> (fila 11); NASA APOD del 14 de diciembre de 2022 <https://science.nasa.gov/image-article/apod-2022-december-14-lunar-dust-and-duct-tape/> (fila 17).

PRECAUCIONES: - Odysseus: las propias páginas de la NASA dicen 'inclinado'; 'volcado de lado' y la pata de aterrizaje rota vienen de reportes de prensa que citan a Intuitive Machines (unos 30 grados respecto a la horizontal en reportes posteriores). El juego dice que terminó inclinado. Que Malapert A esté a unos 300 km del polo solo aparece en reportes secundarios; no se usa. - Chandrayaan-3: la latitud de 69.37 grados S viene de la ISRO, no de la NASA; la NASA da 'unos 600 km del Polo Sur'. Ninguna fuente abierta dice que fuera el aterrizaje más cercano al polo, así que el juego no afirma ningún récord. - Tamaño del cráter de LCROSS: la NASA dice unos 20 m; un artículo posterior da unos 27 m. Usar 'unos 20 m' o ningún número. - Lunar Prospector: el catálogo del NSSDC no nombra el cráter (fuentes secundarias dicen Shoemaker); el juego dice 'un cráter oscuro'. - Destellos de meteoros: el brillo del destello de 2013 difiere entre páginas de la NASA (cuarta magnitud en material más antiguo, tercera magnitud en el blog de 2026); no se usa. El impactor es 'del tamaño de una bola de boliche' (blog) o 'de 30 a 40 cm' (SVS); ambas cosas coinciden. - Cráteres nuevos: 'más de 200' (2016) y 'al menos 1,000' (2026) son conteos de fechas distintas; usar el valor de 2026. - Velocidad del LRV: la página del NSSDC de la NASA no da velocidad máxima; el valor de 16 km/hr viene de la figura del TM de NASA Glenn. - El carrito lunar y el camión de hielo del juego están inspirados en el LRV; el camión de hielo con cabina presurizada es un vehículo del juego (no se abrió ninguna fuente de la NASA sobre un rover presurizado específico), y los valores de maxSpeed del juego en VEHICLES son parámetros GAME. - Plataformas de aterrizaje: las pruebas fueron en la Tierra; ninguna fuente abierta dice que se haya construido una plataforma en la Luna. - El evento de meteorito del juego es inventado ('¿y si una roca espacial cayera cerca de tu base?'); los impactos reales de este tamaño cerca de un punto específico son raros.

DESCARTADOS (sin verificar, no mostrar): - El récord de velocidad del LRV del Apollo 17 (unos 18 km/h) y los '17 km/h' del Apollo 16 (solo noticias y enciclopedia). - 'Odysseus es el aterrizaje más al sur de la historia' (solo noticias). - Los '350 toneladas métricas de material excavado' de LCROSS (fragmento de búsqueda de una página de la NASA; no se abrió). - Los detalles exactos de la falla del tren de aterrizaje de Odysseus (solo noticias).

</details>

#### Chorros de gas, mochilas propulsoras y saltos lunares (Etapa 8)

Datos detrás del equipo de la Etapa 8: las botas de aire (doble salto con soplos de gas desde las suelas) y la mochila propulsora (chorros de gas frío mientras se mantiene presionado Saltar), además de cómo se movían realmente los astronautas en la Luna. Cada fuente de abajo se abrió el 15 de noviembre de 2026 (fecha de consulta). Las botas de aire y la mochila propulsora del juego son inventos del juego inspirados en estos dispositivos reales; ninguna fuente abierta describe botas con chorros de gas ni una mochila propulsora que se haya usado en la Luna, y el juego nunca dice que hayan existido.

| # | Tema | Dato | Estado | Fuente |
| :--- | :--- | :--- | :--- | :--- |
| 1 | La Manned Maneuvering Unit (MMU) volaba con gas nitrógeno | NASA History SP-4219, capítulo 13 ('More Favored than the Birds: The Manned Maneuvering Unit in Space'): el propelente de la MMU era 'nitrógeno gaseoso, GN2, almacenado en dos tanques'; la propulsión se dividía en dos conjuntos paralelos, cada uno 'operando doce propulsores', así que normalmente estaban disponibles los 24 propulsores; dos baterías de plata-zinc daban la energía eléctrica; la MMU estaba pensada para funcionar hasta a 450 pies (unos 137 m, derivado) del transbordador espacial y pesaba unas 340 libras. El artículo con imagen de la NASA la llama un 'dispositivo de mochila propulsado por nitrógeno y controlado a mano'. | Verificado | <https://www.nasa.gov/history/SP-4219/Chapter13.html> |
| 2 | Primera caminata espacial sin cable de sujeción: Bruce McCandless, 7 de febrero de 1984 | Artículo con imagen de la NASA ('Astronaut Bruce McCandless Performs the First Untethered Spacewalk'): foto del 7 de febrero de 1984, STS-41B, con McCandless probando por primera vez la unidad de maniobra tripulada cerca del transbordador espacial Challenger. El segundo artículo con imagen de la NASA ('Astronaut Bruce McCandless on First-ever Untethered Spacewalk') da la misma fecha y la llama una 'unidad de maniobra tripulada (MMU) propulsada por nitrógeno y controlada a mano'. Página de la misión STS-41B de la NASA: despegó el 3 de febrero de 1984; McCandless 'completó la primera caminata espacial sin cable de sujeción usando la Manned Maneuvering Unit', y Robert Stewart también la voló en esa misión. El capítulo 13 de SP-4219 también da el 7 de febrero de 1984. | Verificado | <https://www.nasa.gov/image-article/astronaut-bruce-mccandless-performs-the-first-untethered-spacewalk/> |
| 3 | SAFER, la pequeña mochila de chorros de nitrógeno para emergencias | NASA History ('30 Years Ago: STS-64 Astronauts Test a Spacewalk Rescue Aid'): SAFER (Simplified Aid for EVA Rescue), diseñado en el Johnson Space Center, 'se sujeta a la mochila del Sistema Portátil de Soporte Vital del traje espacial' y 'contiene chorros de nitrógeno que un astronauta puede usar, si se suelta su cable de sujeción, para volar de regreso al vehículo'; 'Los astronautas que hacen caminatas espaciales desde la estación espacial usan el SAFER como dispositivo de seguridad estándar'; lo probaron por primera vez Mark C. Lee y Carl J. Meade en la STS-64, en septiembre de 1994, en la primera caminata espacial sin cable de sujeción desde 1984. Página para niños de la NASA 'What Is a Spacewalk? (Grades K-4)': 'El SAFER se usa como una mochila', con pequeños propulsores que se dirigen con una palanca de mando. | Verificado | <https://www.nasa.gov/history/30-years-ago-sts-64-astronauts-test-a-spacewalk-rescue-aid/> |
| 4 | Cómo se movían los astronautas del Apollo: saltos de canguro y trote a saltos | Apollo Lunar Surface Journal, 'Lunar Gaits' (comentario de Eric M. Jones, alojado por la NASA): Aldrin, en el Apollo 11: 'poner un pie delante del otro es una forma de moverse mucho mejor que el salto de canguro, más rígido. Se puede hacer, pero no parece ofrecer ninguna ventaja en particular'; Armstrong: 'La mejor forma en que puedo describir un trote a saltos es tener los dos pies en el aire al mismo tiempo' y 'estás aprovechando la baja gravedad'; la mayoría de los astronautas de las misiones posteriores prefirieron el trote a saltos; nadie usó el salto de canguro con los dos pies en terreno plano, salvo jugando, pero Cernan y Schmitt lo usaron al bajar una colina empinada en el Apollo 17. Coincide con la fila 29 de Energía (alrededor de un sexto del peso en la Tierra). | Verificado | <https://www.nasa.gov/wp-content/uploads/static/history/alsj/a11/a11.gaits.html> |
| 5 | Los saltos lunares de John Young (Apollo 16) | NASA History ('50 Years Ago: Apollo 16 on the Moon at Descartes'): durante la primera caminata lunar, Young plantó la bandera y él y Duke se turnaron para fotografiarse, 'con Young saltando en el aire mientras saludaba'; 'De manera más informal, Young dio cinco saltos altos, alcanzando una altura de 2.3 pies' (unos 70 cm, derivado: 2.3 x 30.48 cm = 70.1 cm). Artículo con imagen de la NASA 'All-American Salute' (AS16-113-18339): Young 'salta desde la superficie lunar' durante la primera actividad extravehicular del Apollo 16. | Verificado | <https://www.nasa.gov/history/50-years-ago-apollo-16-on-the-moon-at-descartes/> |

<details><summary>Notas de verificación de esta sección</summary>

MÉTODO (2026-11-15, fecha de consulta de cada fuente): las páginas de la NASA se abrieron con una herramienta de descarga que devuelve fragmentos citados breves. La página 'Lunar Gaits' en hq.nasa.gov ahora redirige a la página de inicio del ALSJ de la NASA, así que se abrieron la copia estática alojada por la NASA (enlace de la fila 4) y la copia de apollojournals.org <https://apollojournals.org/alsj/a11/a11.gaits.html>; ambas dan las mismas citas.

SEGUNDAS FUENTES ABIERTAS: artículo con imagen de la NASA <https://www.nasa.gov/image-article/astronaut-bruce-mccandless-first-ever-untethered-spacewalk/> (filas 1, 2); página de la misión STS-41B de la NASA <https://www.nasa.gov/mission/sts-41b/> (fila 2); página para niños de la NASA <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-a-spacewalk-grades-k-4/> (fila 3); artículo con imagen de la NASA <https://www.nasa.gov/image-article/all-american-salute/> (fila 5).

CORRESPONDENCIA CON EL JUEGO Y PRECAUCIONES: - Los chorros de gas funcionan sin aire: filas 3 y 4 de la Etapa 6 (un cohete empuja sus gases de escape; tercera ley de Newton). El tanque de gas del juego, su recarga dentro de la base y su consumo de gas por salto o por segundo son parámetros de juego, no valores reales. - La MMU y el SAFER volaron en órbita, donde todo cae junto; en la Luna, una mochila propulsora tiene que empujar contra la gravedad, así que levantar a una persona gastaría gas mucho más rápido. Esa oración es un razonamiento del equipo, no una cita de la NASA, y es la razón por la que la mochila propulsora del juego gasta gas cada segundo que está encendida. - Las botas de los trajes espaciales reales no tienen chorros de gas; las botas de aire son un invento del juego. - Las fuentes dicen 'salto de canguro', no 'salto de conejo'; el juego debe decir salto de canguro (o 'salto'). - Fila 5: la página no da en su texto una fecha de calendario para los saltos (los nombres de archivo de las fotos sugieren el 21 de abril de 1972); el juego no muestra una fecha. - Fila 3: 'dispositivo de seguridad estándar' es la redacción de la NASA en un artículo de historia de 2024; el juego dice que quienes hacen caminatas espaciales 'llevan puesto' el SAFER, no que se haya usado en todas las caminatas.

DESCARTADOS (sin verificar, no mostrar): - Las cifras del SAFER de '24 propulsores', '0.8 lbs' de empuje cada uno, 'suministro de tres libras de nitrógeno' y unos 13 minutos de uso solo aparecieron en fragmentos de búsqueda de PDF de la NASA (kit de prensa de la STS-64, informes de NTRS) que no se abrieron. - Que McCandless volara hasta '320 pies' del orbitador (solo fragmento de búsqueda; los pies de foto abiertos solo dicen 'a unos cuantos metros'). - Una línea de una cronología de la NASA que dice que la tripulación del Apollo 11 'tendía a moverse con saltos de canguro con los dos pies' (solo fragmento de búsqueda; además contradice la fila 4).

</details>

### 6.2 Avisos de terceros

El texto siguiente es `THIRD_PARTY_NOTICES.md` tal como está en el repositorio. Solo se ajustaron los niveles de encabezado para adaptarlo a este documento.


#### Tabler Icons

Los íconos del juego son Tabler Icons (https://tabler.io/icons, versión 3.52.0), convertidos en archivos PNG blancos, subidos a Roblox y coloreados dentro del juego. Los ID de los recursos se encuentran en `src/shared/Icons.luau`.

```
MIT License

Copyright (c) 2020-2026 Paweł Kuna

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### Herramientas (no redistribuidas)

- Roblox Studio (Roblox Corporation)
- Rojo (MPL-2.0), https://rojo.space
- Lune (MPL-2.0), https://github.com/lune-org/lune

#### Imagen de la Tierra

La Tierra que aparece en el juego usa la imagen de la NASA "Blue Marble: Land Surface, Ocean Color and Sea Ice" (NASA Visible Earth, NASA Goddard Space Flight Center), de dominio público, escalada a 1024x512. Crédito: NASA. El uso de material de la NASA no implica su respaldo. El archivo se tomó de la copia de dominio público en Wikimedia Commons ("Whole world - land and oceans.jpg"), porque el servidor de imágenes de la NASA no respondió.

#### Grabaciones de sonido (CC0)

La música y la mayoría de los efectos de sonido son audio original, sintetizado con código por el equipo. Cinco efectos mezclan partes editadas de estas grabaciones CC0 1.0 (dominio público) de Freesound, encontradas con Openverse. CC0 no exige atribución; se listan como cortesía. Ningún sonido del juego es CC BY. Los IDs de los assets de Roblox están en `src/shared/AudioIds.luau`.

- "Ratchet Wrench Fast Multiple" de Rudmer_Rotteveel, https://freesound.org/people/Rudmer_Rotteveel/sounds/591529 (en `build_step`)
- "Wrench Clanking" de magnuswaker, https://freesound.org/people/magnuswaker/sounds/530074 (en `build_step`)
- "Heavy Metal Thud on Ground" de 7of9Designs, https://freesound.org/people/7of9Designs/sounds/640204 (en `crate_drop`, `shelter_enter` y `meteor_impact`)
- "Footsteps Metallic Muffled.wav" de RutgerMuller, https://freesound.org/people/RutgerMuller/sounds/50723 (en `footstep_inside`)

### 6.3 Licencia

Space Base Odyssey se publica bajo la **Apache License, Version 2.0** (enero de 2004). El texto completo está en el archivo `LICENSE`, en la raíz del repositorio. En resumen:

| Tema | Lo que dice la licencia |
| :--- | :--- |
| Licencia de derechos de autor | Cada colaborador otorga una licencia perpetua, mundial, no exclusiva, gratuita, libre de regalías e irrevocable para reproducir, modificar, exhibir públicamente, ejecutar públicamente, sublicenciar y distribuir la obra y las obras basadas en ella, en forma de código fuente o de código objeto. |
| Licencia de patentes | Cada colaborador otorga además una licencia de patentes sobre sus contribuciones. Esta termina para quien inicie un litigio de patentes alegando que la obra infringe una patente. |
| Redistribución | Quien comparta la obra o una versión modificada debe entregar a los destinatarios una copia de la licencia, marcar los archivos que modificó, conservar los avisos existentes de derechos de autor, patentes, marcas y atribución, e incluir los avisos de atribución de cualquier archivo NOTICE. |
| Contribuciones | Todo lo que se envíe para incluirse en la obra queda bajo la misma licencia, salvo que el colaborador indique expresamente lo contrario. |
| Marcas | La licencia no otorga derecho a usar los nombres, marcas ni nombres de producto del licenciante, más allá de describir el origen de la obra. |
| Garantía | La obra se proporciona "TAL CUAL" ("AS IS"), sin garantías ni condiciones de ningún tipo. |
| Responsabilidad | Los colaboradores no son responsables de los daños derivados del uso de la obra, salvo que la ley lo exija o que lo hayan acordado por escrito. |
| Soporte adicional | Un redistribuidor puede ofrecer soporte, garantía o responsabilidad a cambio de una tarifa, pero solo en su propio nombre. |

La licencia Apache 2.0 cubre el código y los textos propios del equipo. El material de terceros conserva sus propios términos: los Tabler Icons están bajo la MIT License, la imagen de la Tierra es de dominio público, y las cuatro grabaciones de Freesound que se mezclan en cinco efectos de sonido son CC0 1.0 (dominio público) (ver 6.2). La pantalla de Créditos lo dice como texto: "Sonidos: del equipo y clips CC0 de Freesound". Roblox Studio, Rojo y Lune son herramientas que se usaron para construir y probar el juego. No se redistribuyen con él.

### 6.4 Uso de Superinteligencia

Las reglas de Space Apps llaman a la IA "Superinteligencia (SI)" ("Super Intelligence (SI)") y exigen que los equipos declaren cómo la usaron.

#### Qué IA se usó

Usamos **Claude, de Anthropic**, dentro de **Claude Code**, como asistente de IA durante el hackathon.

#### Qué hizo la IA

- **Recopilación de investigación.** Claude reunió datos candidatos y sus fuentes (soporte vital y alimentos, radiación y clima espacial, energía y entorno de la superficie, comunicaciones, tarjetas coleccionables, construcción de la base, sitios de exploración, propulsores de gas y saltos en la Luna) en `DATA_SOURCES.md`.
- **Verificación de datos.** Una revisión de verificación independiente, realizada por separado con Claude, volvió a abrir cada fuente citada y marcó cada dato como verificado, corregido o no verificado. De 199 datos, 189 se verificaron, 9 se corrigieron y 1 no pudo confirmarse. Los datos no verificados nunca aparecen en el juego.
- **Revisión del diseño.** Una auditoría de los primeros documentos de diseño del equipo, de los borradores del plan y críticas independientes de esos planes.
- **Generación de código.** Claude escribió la mayor parte del código Luau y de las pruebas automatizadas a partir del diseño del equipo, usando agentes en paralelo seguidos de revisiones de integración.
- **Pruebas.** Pruebas automatizadas que se ejecutan en Lune, y sesiones de prueba de juego en Roblox Studio dirigidas por el asistente.
- **Borradores de texto.** Claude redactó los textos del juego en inglés y en español, el README, la bitácora de desarrollo, esta documentación, el paquete para docentes y los textos de la entrega.
- **Scripts de audio.** Claude ayudó a escribir los scripts de Python del equipo que sintetizan la música y la mayoría de los efectos de sonido. No se usó ningún modelo generativo de audio.

#### Qué hizo el equipo

- El concepto del juego, el escenario y las mecánicas principales, así como todas las decisiones de diseño. Cuando Claude propuso opciones, el equipo eligió.
- La aprobación de cada número antes de incorporarlo al juego.
- La revisión de los textos del juego y de los borradores de la documentación.
- Las pruebas de juego, la publicación, el video y la presentación.

#### Declaración dentro del proyecto

- Cada archivo de código hecho con ayuda de IA empieza con una línea de declaración: "SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team." ("Declaración de SI: generado con ayuda de IA (Claude, Anthropic) y revisado por el equipo."). El archivo de datos archivados de clima espacial (`src/shared/SpaceWeatherArchive.luau`) dice "compiled" ("recopilado") en lugar de "generated" ("generado"), porque contiene datos recopilados y no lógica escrita.
- En el juego no se usan imágenes ni video generados por IA. La música y los efectos de sonido se sintetizan con código propio del equipo (scripts escritos con ayuda de IA; ningún modelo generativo de audio), y cinco efectos mezclan grabaciones CC0 editadas (6.2). El mundo del juego se construye con piezas simples mediante código. Las únicas imágenes son los Tabler Icons y el mapa de la Tierra de la NASA, de dominio público, indicados en 6.2, más una cara del cielo casi negra hecha por el equipo.
