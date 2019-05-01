#version 420
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;
layout(location = 2) in vec4 color;
layout(location = 3) in vec3 previous;
layout(location = 4) in vec3 next;
layout(location = 5) in float side;
layout(location = 6) in float width;

uniform mat4  modelmat;
uniform float canvas_width;
uniform float canvas_height;
uniform float lineWidth;
uniform float near;
uniform float far;
uniform float sizeAttenuation;

varying vec4 vColor;
varying float vCounters;

vec2 fix(vec4 i, float aspect) {
	vec2 res = i.xy / i.w;
	res.x *= aspect;
	return res;
}

void main() {
	float aspect = canvas_width / canvas_height;
	float pixelWidthRatio = 1. / (canvas_width * projectionMatrix[0][0]);
	vColor = color;
	vec4 finalPosition = modelmat * vec4(vertices, 1.0);
	vec4 prevPos = modelmat * vec4(previous, 1.0);
	vec4 nextPos = modelmat * vec4(next, 1.0);
	vec2 currentP = fix(finalPosition, aspect);
	vec2 prevP = fix(prevPos, aspect);
	vec2 nextP = fix(nextPos, aspect);
	float pixelWidth = finalPosition.w * pixelWidthRatio;
	float w = 1.8 * pixelWidth * lineWidth * width;

	if( sizeAttenuation == 1. ) {
		w = 1.8 * lineWidth * width;
	}

	vec2 dir;
	if( nextP == currentP ) dir = normalize( currentP - prevP );

	else if( prevP == currentP ) dir = normalize( nextP - currentP );

	else {
		vec2 dir1 = normalize(currentP - prevP);
		vec2 dir2 = normalize(nextP - currentP);
		dir = normalize(dir1 + dir2);
		vec2 perp = vec2(-dir1.y, dir1.x);
		vec2 miter = vec2(-dir.y, dir.x);
		//w = clamp( w / dot( miter, perp ), 0., 4. * lineWidth * width );
	}
	//vec2 normal = ( cross( vec3( dir, 0. ), vec3( 0., 0., 1. ) ) ).xy;
	vec2 normal = vec2(-dir.y, dir.x);
	normal.x /= aspect;
	normal *= .5 * w;
	vec4 offset = vec4(normal * side, 0.0, 1.0);
	finalPosition.xy += offset.xy;
	gl_Position = finalPosition;
}

