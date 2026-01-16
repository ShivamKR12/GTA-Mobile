shader_type spatial;

uniform vec4 originalColor : source_color;
uniform vec4 newColor : source_color;
uniform float tolerance = 0.2;
uniform sampler2D originalTexture;
global uniform float Time;

void vertex() {

}

void fragment() {
	ALBEDO = texture(originalTexture, UV).rgb;
	if ((Time < 5.0 || Time > 17.0) && length(ALBEDO - originalColor.rgb) < tolerance) ALBEDO = newColor.rgb;
}
