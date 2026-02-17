# Godot 4 – Dark Fantasy UI Theme (Procedural)  
Generates a “premium ARPG” UI look using **Theme + StyleBoxes + one shader**.  
Goal: no painted frames, minimal textures, scalable + consistent.

---

## 0) Files to create

```
res://ui/theme/DarkFantasyTheme.gd
res://ui/theme/shaders/ui_bevel_inner_shadow.gdshader
```

**Optional:**

```
res://ui/theme/fonts/Cinzel-.ttf
res://ui/theme/fonts/CormorantGaramond-.ttf
res://ui/theme/fonts/Montserrat-*.ttf
```

---

## 1) Font Recommendations

Download (Google Fonts):
- Headings / Boss names: **Cinzel** (SemiBold)
- UI body: **Cormorant Garamond** (Regular / Medium)
- Numbers / damage: **Montserrat** (Bold / ExtraBold)

Godot import:
- Put `.ttf` in `res://ui/theme/fonts/`
- In Import tab, set Font -> **Use Filter = true** (looks better at small sizes)

---

## 2) Color System (Constants)

Use these as your single source of truth:

- Dark Fill: `#1E1E22`
- Dark Fill 2: `#151519`
- Bronze: `#B58A3C`
- Bronze Dark: `#7E5F25`
- Text: `#E8DFC8`
- Muted Text: `#B9B09A`

Bars:
- HP: `#3BB54A`
- Mana: `#2D7FF9`
- Energy: `#F2C94C`
- Ultimate: `#9B51E0`
- Boss Red: `#C0392B`

---

## 3) Spacing System (8pt grid)

### Base Units
- `U = 8`

### Padding
- XS: `U` (8)
- SM: `U*2` (16)
- MD: `U*3` (24)
- LG: `U*4` (32)

### Gaps
- Tight: `U` (8)
- Normal: `U*2` (16)
- Wide: `U*3` (24)

### Corner Radius
- Small: 8
- Medium: 12
- Large: 16

### Border Width
- Panels: 3
- Buttons/Slots: 2

### Drop Shadow (for key panels)
- Offset: (0, 2)
- Size: 6
- Alpha: 0.35

---

## 4) Shader: Bevel + Inner Shadow

Create `res://ui/theme/shaders/ui_bevel_inner_shadow.gdshader`

```glsl
shader_type canvas_item;

uniform float radius_px = 12.0;
uniform float border_px = 3.0;
uniform vec4 fill_color : source_color = vec4(0.118, 0.118, 0.133, 1.0);
uniform vec4 fill_color_2 : source_color = vec4(0.082, 0.082, 0.098, 1.0);

uniform vec4 border_color : source_color = vec4(0.710, 0.541, 0.235, 1.0);
uniform vec4 border_color_dark : source_color = vec4(0.494, 0.373, 0.145, 1.0);

uniform float bevel_strength = 0.25;     // highlight/dark edge amount
uniform float inner_shadow_strength = 0.40;
uniform float inner_shadow_size = 10.0;  // px

// signed distance to rounded rect
float sd_round_rect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec2 uv = UV;
    vec2 px = (uv - vec2(0.5)) * vec2(TEXTURE_PIXEL_SIZE.x > 0.0 ? 1.0/TEXTURE_PIXEL_SIZE.x : 256.0,
                                      TEXTURE_PIXEL_SIZE.y > 0.0 ? 1.0/TEXTURE_PIXEL_SIZE.y : 256.0);

    // Estimate size in px from UV derivatives (works for Controls)
    vec2 ddx_uv = dFdx(uv);
    vec2 ddy_uv = dFdy(uv);
    vec2 size_px = vec2(1.0/length(ddx_uv), 1.0/length(ddy_uv));
    vec2 half_size = size_px * 0.5;

    vec2 p = (uv - vec2(0.5)) * size_px;
    float d = sd_round_rect(p, half_size - vec2(1.0), radius_px);

    // alpha mask for rounded rect
    float aa = fwidth(d);
    float shape_alpha = 1.0 - smoothstep(0.0, aa, d);

    // border mask
    float d_inner = d + border_px;
    float border_alpha = clamp((1.0 - smoothstep(0.0, aa, d)) - (1.0 - smoothstep(0.0, aa, d_inner)), 0.0, 1.0);

    // subtle vertical gradient fill
    float grad = smoothstep(0.0, 1.0, uv.y);
    vec4 fill = mix(fill_color, fill_color_2, grad);

    // bevel highlight top + dark bottom
    float top = smoothstep(0.0, 0.12, uv.y);
    float bottom = 1.0 - smoothstep(0.88, 1.0, uv.y);
    float bevel = (top - bottom) * bevel_strength;

    vec4 border = mix(border_color_dark, border_color, 0.65 + bevel);

    // inner shadow: darken near edges inside
    float edge_dist = clamp((-d_inner) / inner_shadow_size, 0.0, 1.0);
    float inner_shadow = edge_dist * inner_shadow_strength;

    vec4 col = fill;
    col.rgb *= (1.0 - inner_shadow);

    // compose
    col = mix(col, border, border_alpha);
    COLOR = vec4(col.rgb, shape_alpha);
}

---

## 5) DarkFantasyTheme script

Create `res://ui/theme/DarkFantasyTheme.gd`. Call `DarkFantasyTheme.apply_to_tree(get_tree().root)` from an autoload or main scene.

```gdscript
extends Node

# Call DarkFantasyTheme.apply_to_tree(get_tree().root) from an autoload or main scene.
class_name DarkFantasyTheme

const U := 8

# Colors
const C_DARK      := Color("#1E1E22")
const C_DARK_2    := Color("#151519")
const C_BRONZE    := Color("#B58A3C")
const C_BRONZE_D  := Color("#7E5F25")
const C_TEXT      := Color("#E8DFC8")
const C_TEXT_M    := Color("#B9B09A")

const SHADER_PATH := "res://ui/theme/shaders/ui_bevel_inner_shadow.gdshader"

static func apply_to_tree(root: Node) -> void:
	var theme := Theme.new()

	# --- Base fonts (assign after you add font files) ---
	# If you don't have fonts yet, Godot will fallback.
	# Uncomment + point to your font resources once imported.
	# var font_ui := load("res://ui/theme/fonts/CormorantGaramond-Regular.ttf")
	# var font_heading := load("res://ui/theme/fonts/Cinzel-SemiBold.ttf")
	# var font_numbers := load("res://ui/theme/fonts/Montserrat-Bold.ttf")

	# theme.set_default_font(font_ui)
	# theme.set_default_font_size(18)

	# Common constants
	theme.set_constant("h_separation", "BoxContainer", U*2)
	theme.set_constant("v_separation", "BoxContainer", U*2)

	# Labels
	theme.set_color("font_color", "Label", C_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0,0,0,0.6))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)

	theme.set_color("font_color", "RichTextLabel", C_TEXT)
	theme.set_color("default_color", "RichTextLabel", C_TEXT)

	# Buttons
	theme.set_stylebox("normal", "Button", _sb_button(false))
	theme.set_stylebox("hover", "Button", _sb_button(true))
	theme.set_stylebox("pressed", "Button", _sb_button(true, true))
	theme.set_stylebox("disabled", "Button", _sb_button(false, false, true))

	theme.set_color("font_color", "Button", C_TEXT)
	theme.set_color("font_hover_color", "Button", C_TEXT)
	theme.set_color("font_pressed_color", "Button", C_TEXT)
	theme.set_color("font_disabled_color", "Button", C_TEXT_M)

	theme.set_constant("outline_size", "Button", 0)
	theme.set_constant("h_separation", "Button", U)
	theme.set_constant("v_separation", "Button", U)

	# Panel containers
	theme.set_stylebox("panel", "PanelContainer", _sb_panel(12, 3))
	theme.set_stylebox("panel", "Panel", _sb_panel(12, 3))

	# LineEdit
	theme.set_stylebox("normal", "LineEdit", _sb_panel(10, 2))
	theme.set_stylebox("focus", "LineEdit", _sb_panel(10, 2, true))
	theme.set_color("font_color", "LineEdit", C_TEXT)
	theme.set_color("caret_color", "LineEdit", C_TEXT)
	theme.set_color("selection_color", "LineEdit", Color(C_BRONZE, 0.35))
	theme.set_constant("minimum_character_width", "LineEdit", 14)

	# ProgressBar (generic)
	theme.set_stylebox("background", "ProgressBar", _sb_progress_bg())
	theme.set_stylebox("fill", "ProgressBar", _sb_progress_fill(Color("#3BB54A")))
	theme.set_color("font_color", "ProgressBar", C_TEXT)
	theme.set_constant("outline_size", "ProgressBar", 0)

	# Sliders (optional baseline)
	theme.set_stylebox("grabber", "HSlider", _sb_knob())
	theme.set_stylebox("grabber_highlight", "HSlider", _sb_knob(true))
	theme.set_stylebox("slider", "HSlider", _sb_progress_bg())

	# Assign theme to root
	root.theme = theme


# --- StyleBox builders ---

static func _sb_panel(radius: int, border: int, focused := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_DARK
	sb.set_border_width_all(border)
	sb.border_color = focused ? C_BRONZE : C_BRONZE_D
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = U*2
	sb.content_margin_right = U*2
	sb.content_margin_top = U*2
	sb.content_margin_bottom = U*2

	sb.shadow_color = Color(0,0,0,0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func _sb_button(hover := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = disabled ? C_DARK_2 : (pressed ? C_DARK_2 : C_DARK)
	sb.set_border_width_all(2)
	sb.border_color = disabled ? Color(C_BRONZE_D, 0.5) : (hover ? C_BRONZE : C_BRONZE_D)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10

	sb.content_margin_left = U*2
	sb.content_margin_right = U*2
	sb.content_margin_top = U
	sb.content_margin_bottom = U

	sb.shadow_color = Color(0,0,0,0.35)
	sb.shadow_size = hover ? 8 : 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func _sb_progress_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_DARK_2
	sb.set_border_width_all(2)
	sb.border_color = C_BRONZE_D
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func _sb_progress_fill(fill_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	return sb

static func _sb_knob(highlight := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = highlight ? C_BRONZE : C_BRONZE_D
	sb.set_border_width_all(1)
	sb.border_color = Color(0,0,0,0.6)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
```

