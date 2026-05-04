---
name: shader-writer
description: Write Godot 4.x shaders — 2D effects (outline, hit flash, dissolve, palette swap, screen distortion), 3D effects (toon, dissolve, water, fresnel rim, hologram), and post-process. Picks correct shader_type, uniforms with hint_range and source_color, performance-aware fragment code.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: <effect-description> [target: 2d | 3d | ui | post]
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Shader Writer

Save shaders to `shaders/<name>.gdshader`. Reference: [Godot shaders docs](https://docs.godotengine.org/en/stable/tutorials/shaders/index.html).

## Shader types

| `shader_type` | For |
|---------------|-----|
| `canvas_item` | 2D nodes (Sprite2D, TileMapLayer, Control, AnimatedSprite2D) |
| `spatial` | 3D meshes (PBR-aware) |
| `particles` | GPUParticles2D/3D process step |
| `sky` | World environment sky |
| `fog` | FogVolume |

## 2D recipes (`shader_type canvas_item`)

### Hit flash

```glsl
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, vec4(flash_color.rgb, tex.a), flash_amount);
}
```

Drive `flash_amount` from code via a Tween: `tween_property(material, "shader_parameter/flash_amount", 0.0, 0.15).from(1.0)`.

### Outline (sample neighbors)

```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a > 0.0) {
        COLOR = tex;
    } else {
        vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
        float a = 0.0;
        a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
        a += texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
        a += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
        a += texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
        COLOR = vec4(outline_color.rgb, outline_color.a * step(0.01, a));
    }
}
```

### Dissolve

```glsl
shader_type canvas_item;

uniform sampler2D noise_texture : hint_default_white;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float n = texture(noise_texture, UV).r;
    if (n < dissolve_amount) discard;
    float edge = step(n, dissolve_amount + edge_width);
    COLOR = mix(tex, edge_color, edge);
}
```

### Palette swap (1D LUT)

```glsl
shader_type canvas_item;

uniform sampler2D palette : hint_default_white;

void fragment() {
    float lum = texture(TEXTURE, UV).r;     // assumes grayscale source
    COLOR = vec4(texture(palette, vec2(lum, 0.5)).rgb, texture(TEXTURE, UV).a);
}
```

### Screen distortion (heat haze)

```glsl
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise : hint_default_white;
uniform float strength : hint_range(0.0, 0.05) = 0.01;

void fragment() {
    vec2 offset = (texture(noise, UV + TIME * 0.1).rg - 0.5) * strength;
    COLOR = texture(screen_texture, SCREEN_UV + offset);
}
```

## 3D recipes (`shader_type spatial`)

### Toon shading

```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.7, 0.5, 0.3, 1.0);
uniform float bands : hint_range(2.0, 8.0) = 3.0;

void light() {
    float ndotl = dot(NORMAL, LIGHT);
    float quantized = floor(max(ndotl, 0.0) * bands) / bands;
    DIFFUSE_LIGHT += base_color.rgb * LIGHT_COLOR * ATTENUATION * quantized;
}
```

### Fresnel rim

```glsl
shader_type spatial;

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 0.6, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);
    EMISSION = rim_color.rgb * fresnel * rim_intensity;
}
```

### Dissolve (3D)

```glsl
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D noise_texture : hint_default_white;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.7, 1.0);

void fragment() {
    float n = texture(noise_texture, UV).r;
    if (n < dissolve_amount) discard;
    float edge = step(n, dissolve_amount + edge_width);
    ALBEDO = albedo.rgb;
    EMISSION = edge_color.rgb * edge * 4.0;
}
```

### Hologram

```glsl
shader_type spatial;
render_mode blend_add, cull_back, depth_draw_opaque, unshaded;

uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float scanline_density : hint_range(20.0, 400.0) = 100.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 6.0;

void fragment() {
    float scan = sin(UV.y * scanline_density + TIME * flicker_speed) * 0.5 + 0.5;
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);
    ALBEDO = tint.rgb;
    ALPHA = (scan * 0.6 + 0.4) * fresnel * tint.a;
}
```

### Water (basic)

```glsl
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 deep : source_color = vec4(0.05, 0.2, 0.4, 1.0);
uniform vec4 shallow : source_color = vec4(0.4, 0.7, 0.85, 1.0);
uniform sampler2D wave_noise : hint_default_white;
uniform float wave_height : hint_range(0.0, 0.5) = 0.05;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;

void vertex() {
    vec2 uv = UV + TIME * wave_speed * vec2(0.1, 0.07);
    float h = (texture(wave_noise, uv).r - 0.5) * wave_height;
    VERTEX.y += h;
}

void fragment() {
    float depth_factor = clamp(VERTEX.y * 0.5 + 0.5, 0.0, 1.0);
    ALBEDO = mix(deep.rgb, shallow.rgb, depth_factor);
    METALLIC = 0.1;
    ROUGHNESS = 0.2;
    ALPHA = 0.85;
}
```

## UI recipes (`shader_type canvas_item` on Control)

### Pulsing glow border (button focus)

```glsl
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float border_width : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
    float border = 1.0 - smoothstep(0.0, border_width, edge);
    float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;
    COLOR = vec4(glow_color.rgb, border * pulse * glow_color.a);
}
```

## Conventions

- Save under `shaders/<name>.gdshader` (`.gdshader`, not `.shader`).
- All tweakable parameters as `uniform` with `hint_range` (numbers) or `source_color` (colors).
- Avoid loops in `fragment()` over more than ~16 iterations on mobile/web targets.
- Use `hint_default_white` / `hint_default_black` for sampler uniforms so missing textures fall back gracefully.
- Use `hint_screen_texture` for `SCREEN_UV` sampling (Godot 4.x).
- Drive shader parameters from GDScript via `material.set_shader_parameter("name", value)` or `Tween.tween_property(material, "shader_parameter/name", target, duration)`.
- Test on the lowest-spec target hardware early — fragment shader cost is the #1 mobile/web perf killer.

## See also

- [Godot Shading Language](https://docs.godotengine.org/en/stable/tutorials/shaders/shading_language.html)
- [Built-in functions reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)
- [Compute shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html) (GPU compute, advanced)
