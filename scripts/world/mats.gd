class_name Mats
extends RefCounted
## Art-directed palette and cached materials. Colours were picked against the
## "The Office" concept: honey wood, cream walls, navy fabric, leafy greens,
## sky-blue glass and warm accent oranges.

const WOOD := Color("c98d55")
const WOOD_LIGHT := Color("e2b27a")
const WOOD_DARK := Color("8a5a36")
const CREAM := Color("f6eedf")
const WALL := Color("efe6d6")
const WHITE := Color("fbfaf6")
const NAVY := Color("2b3a55")
const NAVY_LIGHT := Color("3d5378")
const CHARCOAL := Color("2e3138")
const STEEL := Color("b9c0c9")
const LEAF := Color("4f9d4a")
const LEAF_DARK := Color("2f7a3c")
const LEAF_LIGHT := Color("7cc35a")
const TERRACOTTA := Color("d9774b")
const MUSTARD := Color("f2b134")
const TEAL := Color("2bb3a3")
const CORAL := Color("e85d5d")
const SKY := Color("8fc7f2")
const SCREEN_BLUE := Color("4aa8ff")

static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}


static func solid(color: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var key := "s|%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


## Soft "toon-ish" skin/fabric look: rim light gives the premium cartoon sheen.
static func soft(color: Color, roughness := 0.75, rim := 0.25) -> StandardMaterial3D:
	var key := "soft|%s|%.2f|%.2f" % [color.to_html(), roughness, rim]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.6
	_cache[key] = m
	return m


static func glossy(color: Color, roughness := 0.2) -> StandardMaterial3D:
	var key := "gl|%s|%.2f" % [color.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.2
	_cache[key] = m
	return m


static func emissive(color: Color, energy := 1.5) -> StandardMaterial3D:
	var key := "em|%s|%.2f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func unshaded(color: Color, transparent := false) -> StandardMaterial3D:
	var key := "un|%s|%s" % [color.to_html(), str(transparent)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.93, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.1
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = m
	return m


static func textured(tex: Texture2D, emissive_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.35
	if emissive_energy > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = Color.WHITE
		m.emission_energy_multiplier = emissive_energy
	return m


static func shader_material(shader_name: String, code: String) -> ShaderMaterial:
	if not _shaders.has(shader_name):
		var sh := Shader.new()
		sh.code = code
		_shaders[shader_name] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[shader_name]
	return m


# --------------------------------------------------------------- shaders

const WOOD_FLOOR_SHADER := """
shader_type spatial;
uniform vec3 wood_a : source_color = vec3(0.79, 0.55, 0.33);
uniform vec3 wood_b : source_color = vec3(0.88, 0.67, 0.43);
uniform float plank_width = 0.24;
uniform float plank_length = 1.9;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float row = floor(p.y / plank_width);
	float along = p.x + hash(vec2(row, 3.1)) * 3.0;
	float pid = floor(along / plank_length);
	float h = hash(vec2(row, pid));
	vec3 base = mix(wood_a, wood_b, h);
	float grain = sin(p.y * 90.0 + sin(along * 2.3 + h * 12.0) * 1.4 + h * 30.0) * 0.5 + 0.5;
	base *= 0.92 + grain * 0.08;
	float fx = fract(along / plank_length) * plank_length;
	float fz = fract(p.y / plank_width) * plank_width;
	float seam = smoothstep(0.0, 0.012, fx) * smoothstep(0.0, 0.012, plank_length - fx)
		* smoothstep(0.0, 0.007, fz) * smoothstep(0.0, 0.007, plank_width - fz);
	base *= mix(0.72, 1.0, seam);
	ALBEDO = base;
	ROUGHNESS = 0.42 + h * 0.15;
	SPECULAR = 0.45;
}
"""

const CARPET_SHADER := """
shader_type spatial;
uniform vec3 color_a : source_color = vec3(0.28, 0.36, 0.52);
uniform vec3 color_b : source_color = vec3(0.32, 0.41, 0.58);
uniform float tile_size = 0.5;
uniform float rough = 0.95;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 tile = floor(wpos.xz / tile_size);
	float checker = mod(tile.x + tile.y, 2.0);
	float fuzz = hash(floor(wpos.xz * 120.0)) * 0.06;
	ALBEDO = mix(color_a, color_b, checker) * (0.97 + fuzz);
	ROUGHNESS = rough;
}
"""

## The city skyline seen through the windows: bright day, glassy towers.
const SKYLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 sky_top : source_color = vec3(0.36, 0.62, 0.93);
uniform vec3 sky_bottom : source_color = vec3(0.86, 0.93, 0.98);
uniform vec3 far_col : source_color = vec3(0.56, 0.71, 0.86);
uniform vec3 mid_col : source_color = vec3(0.33, 0.5, 0.72);
uniform vec3 near_col : source_color = vec3(0.2, 0.33, 0.52);
uniform vec3 window_col : source_color = vec3(0.75, 0.88, 1.0);

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

vec3 layer(vec3 col, vec2 uv, float density, float base_h, float var_h, float seed, vec3 bcol, float win) {
	float x = uv.x * density + seed;
	float id = floor(x);
	float fx = fract(x);
	float h = base_h + hash(id + seed) * var_h;
	// some towers get a spire
	float spire = step(0.82, hash(id * 3.7 + seed)) * step(abs(fx - 0.5), 0.04) * 0.08;
	float inset = step(0.06, fx) * step(fx, 0.94);
	if (uv.y < h * inset || uv.y < (h + spire) * step(abs(fx - 0.5), 0.04)) {
		vec3 c = bcol * (0.9 + 0.2 * hash(id * 1.3 + seed));
		// vertical glass sheen
		c += vec3(0.08) * smoothstep(0.2, 0.0, abs(fx - 0.3));
		if (win > 0.0) {
			vec2 w = fract(vec2(fx * 7.0, uv.y * 70.0));
			float lit = step(0.35, hash(id * 17.0 + floor(fx * 7.0) * 5.0 + floor(uv.y * 70.0) * 3.0));
			if (w.x > 0.2 && w.x < 0.8 && w.y > 0.3 && w.y < 0.8) {
				c = mix(c, window_col, win * (0.35 + 0.35 * lit));
			}
		}
		return c;
	}
	return col;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 col = mix(sky_bottom, sky_top, smoothstep(0.25, 1.0, uv.y));
	// soft clouds
	float cl = sin(uv.x * 9.0 + 1.3) * sin(uv.x * 23.0) * 0.5 + 0.5;
	col = mix(col, vec3(1.0), smoothstep(0.75, 0.95, cl) * smoothstep(0.62, 0.72, uv.y) * smoothstep(0.86, 0.74, uv.y) * 0.5);
	col = layer(col, uv, 46.0, 0.42, 0.36, 1.7, far_col, 0.0);
	col = layer(col, uv, 24.0, 0.28, 0.46, 7.3, mid_col, 0.5);
	col = layer(col, uv, 11.0, 0.10, 0.42, 3.1, near_col, 1.0);
	ALBEDO = col;
}
"""

## Blinking server LEDs.
const LED_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 base_col : source_color = vec3(0.2, 1.0, 0.4);
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
void fragment() {
	vec2 cell = floor(UV * vec2(6.0, 14.0));
	float id = cell.x * 31.0 + cell.y * 7.0 + seed;
	float blink = step(0.5, fract(TIME * (0.4 + hash(id) * 2.5) + hash(id + 3.0)));
	vec2 f = fract(UV * vec2(6.0, 14.0));
	float dotm = step(length(f - vec2(0.5)), 0.22);
	vec3 c = mix(base_col, vec3(1.0, 0.75, 0.2), step(0.85, hash(id + 9.0)));
	ALBEDO = mix(vec3(0.08, 0.09, 0.11), c * (0.4 + 0.6 * blink), dotm);
}
"""
