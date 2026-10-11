shader_type canvas_item;
// Dark screen edges, faint film grain, and a pulsing red wash when the player is badly hurt.
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.8));
	float edge = smoothstep(0.22, 0.78, d);
	float pulse = 0.5 + 0.5 * sin(time * 7.0);
	vec3 col = mix(vec3(0.0), vec3(0.45, 0.0, 0.02), hurt * (0.35 + 0.65 * pulse) * edge);
	float grain = (rand(UV * 900.0 + vec2(time * 37.0, time * 91.0)) - 0.5) * 0.07;
	float a = clamp(edge * (0.82 + 0.15 * hurt) + hurt * 0.12 * pulse * edge, 0.0, 0.97);
	COLOR = vec4(col + vec3(grain), max(a, abs(grain) * 1.2));
}
