class_name Textos
extends RefCounted

## Textos del Runner — puerto del bloque correspondiente de
## juegos-cumple/src/textos.js. Solo lo que este juego usa.
##
## REGLA DE TITULOS: <Nombre> + verbo, o sustantivo de lugar/objeto + de
## <Nombre>. Nunca un adjetivo ni un rol de persona, o se rompe al cambiar
## de cumpleanero.

const COMUN := {
	"bienvenida": "¡Bienvenid[o|a|e], {nombre}!",
	"subtitulo": "Hoy cumples {edad} años",
	"jugar": "JUGAR",
	"reintentar": "Otra vez",
	"listo": "¿Estás list[o|a|e]?",
	"ganaste": "¡Lo lograste, {nombre}!",
	"perdiste": "¡Casi! Inténtalo de nuevo.",
	"nuevoRecord": "¡Nuevo récord! Eres [un|una|une] crack.",
	"cargando": "Preparando la sorpresa...",
	"creditos": "Hecho con cariño para {nombre}",
	"despedida": "¡Feliz cumpleaños, {nombre}! Te quieren mucho, {deQuien}.",
}

const RUNNER := {
	"titulo": "¡Corre, {nombre}!",
	"instruccion": "Toca la pantalla para saltar y junta tod[os|os|es] l[os|os|es] {coleccionable}",
	"intro": "{nombre} va corriendo por {lugar} y encontró un montón de {coleccionable}. ¡A juntarl[os|os|es]!",
	"obstaculo": "¡Cuidado! No te tropieces.",
	"meta": "¡Llegaste a la meta! Juntaste {puntos} {coleccionable}.",
	"animo": "¡Sigue así, {nombre}! Nadie corre como tú.",
}
