shader_type canvas_item;

// Recoloreo de sprites por cliente.
//
// Los sprites son de color plano: unas pocas zonas cubren casi toda la imagen.
// Eso permite cambiar piel, pelo y ropa sin tocar los archivos, asi que se
// envia UN solo set de sprites y cada pedido lo tiñe al vuelo.
//
// ---------------------------------------------------------------------------
// EL BUG QUE COSTO ENCONTRAR
//
// La version original terminaba con:
//     COLOR = vec4(c, tex.a) * COLOR;
//
// En Godot, COLOR ya ENTRA a fragment() valiendo textura x modulate. Ese "*
// COLOR" volvia a aplicar el color original encima del nuevo, asi que lo que
// se veia era el producto de los dos:
//
//     rosado pedido #E85DA1 x celeste original #7ba8d9 / 255 = (112, 61, 137)
//
// y la falda salia violeta. La piel salia naranja y el pelo casi negro por lo
// mismo. El sintoma enga�aba porque el emparejamiento SI funcionaba —se teñian
// exactamente las zonas correctas— asi que parecia un problema de espacio de
// color o de transporte del uniform, y no lo era.
//
// Se comprobo pintando de rojo puro lo que emparejara: las zonas correctas se
// pusieron rojas, lo que descarto el emparejamiento y dejo solo la salida.
//
// La paleta viaja como TEXTURA y no como `uniform vec3[]` porque los arreglos
// de uniforms tampoco son de fiar en el renderizador GL Compatibility. Tres
// filas de MAX_RANURAS pixeles:
//   fila 0: color ORIGEN de cada tono (lo que se busca en el sprite)
//   fila 1: color DESTINO (lo que pidio el cliente)
//   fila 2: color BASE de la ranura (para conservar el sombreado)
// ---------------------------------------------------------------------------

uniform sampler2D paleta : filter_nearest, repeat_disable;
uniform int cantidad = 0;

// 0.11 ~= 28/255. Alcanza para los bordes suavizados del sprite pero no llega
// al contorno negro, que es lo que hace legible el dibujo plano. Cada pack
// puede bajarla si sus colores estan mas juntos (ver TOLERANCIAS en paleta.gd).
uniform float tolerancia : hint_range(0.0, 0.5) = 0.11;

const vec3 PESO_LUZ = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Si no hay nada que recolorear se deja COLOR intacto: reasignarlo
	// aplicaria la textura por segunda vez.
	if (tex.a >= 0.03 && cantidad > 0) {
		vec3 c = tex.rgb;
		int mejor = -1;
		float mejor_dist = 1000.0;

		for (int i = 0; i < cantidad; i++) {
			vec3 origen = texelFetch(paleta, ivec2(i, 0), 0).rgb;
			float d = distance(c, origen);
			if (d < tolerancia && d < mejor_dist) {
				mejor_dist = d;
				mejor = i;
			}
		}

		if (mejor >= 0) {
			vec3 destino = texelFetch(paleta, ivec2(mejor, 1), 0).rgb;
			vec3 base = texelFetch(paleta, ivec2(mejor, 2), 0).rgb;
			// La luminancia del pixel respecto al color base de su ranura se
			// conserva: asi las sombras siguen siendo sombras tras el cambio.
			float ratio = dot(c, PESO_LUZ) / max(dot(base, PESO_LUZ), 0.001);
			// Solo el rgb. El alfa que trae COLOR ya incluye el modulate.
			COLOR.rgb = clamp(destino * ratio, vec3(0.0), vec3(1.0));
		}
	}
}
