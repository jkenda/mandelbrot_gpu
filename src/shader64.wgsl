struct VertexInput {
    @builtin(vertex_index) index: u32,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) tex_coords: vec2<f32>,
}


struct Properties {
    center: vec2<f64>,
    zoom: f64,
    width: f32, height: f32,
    i_width: f32, i_height: f32,
    math64: u32,
}

@group(0) @binding(0)
var<uniform> properties: Properties;

fn index_to_pos(index: u32) -> vec2<f32> {
    switch index {
        case 0u: { return vec2<f32>(-1.0, -1.0); }
        case 1u: { return vec2<f32>(-1.0,  1.0); }
        case 2u: { return vec2<f32>( 1.0, -1.0); }
        case 3u: { return vec2<f32>(-1.0,  1.0); }
        case 4u: { return vec2<f32>( 1.0, -1.0); }
        default: { return vec2<f32>( 1.0,  1.0); }
    }
}

fn index_to_tex(index: u32) -> vec2<f32> {
    let aspect = properties.width / properties.height;

    var x_diff = 0.0;
    var y_diff = 0.0;
    if aspect > 1.0 {
        x_diff = (aspect - 1.0) / 2.0;
    }
    else if aspect < 1.0 {
        y_diff = (1.0 / aspect - 1.0) / 2.0;
    }

    // add padding depending on properties.aspect ratio
    let x0 = 0.0 - x_diff;
    let x1 = 1.0 + x_diff;
    let y0 = 0.0 - y_diff;
    let y1 = 1.0 + y_diff;

    switch index {
        case 0u: { return vec2<f32>(x0, y0); }
        case 1u: { return vec2<f32>(x0, y1); }
        case 2u: { return vec2<f32>(x1, y0); }
        case 3u: { return vec2<f32>(x0, y1); }
        case 4u: { return vec2<f32>(x1, y0); }
        default: { return vec2<f32>(x1, y1); }
    }
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.clip_position = vec4<f32>(index_to_pos(in.index), 0.0, 1.0);
    out.tex_coords    = index_to_tex(in.index);
    return out;
}

type Complex32 = vec2<f32>;
type Complex64 = vec2<f64>;

fn square32(a: ptr<function, Complex32>) {
    let x = (*a).x; let y = (*a).y;
    (*a).x = x*x - y*y;
    (*a).y = 2.0 * x * y;
}

fn square64(a: ptr<function, Complex64>) {
    let x = (*a).x; let y = (*a).y;
    (*a).x = x*x - y*y;
    (*a).y = f64(2) * x * y;
}

fn hsv2rgb(c: vec3<f32>) -> vec3<f32> {
    let K = vec4<f32>(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    let p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    let clamped = p - K.xxx;
    return c.z * mix(K.xxx, clamped, c.y);
}

const LIM = 255u;

fn colour1(abs: f32, iter: u32) -> vec3<f32> {
    let iter = f32(iter) / f32(LIM);
    let r = abs / 13.12 + iter;
    let g = iter - sin(abs / 1.7) / 24.3;
    let b = hsv2rgb(vec3<f32>(0.0, 1.0, iter)).r;
    return vec3<f32>(r, g, b);
}

fn julia32(c: Complex32, z: Complex32) -> vec3<f32> {
    var z = z;
    var n = 0u;
    var abs = 0.0;

    while (abs < 4.0 && n < LIM) {
        square32(&z);
        z += c;
        abs = z.x * z.x + z.y * z.y;
        n++;
    }

    abs = sqrt(abs);

    if (n == LIM) {
        return vec3<f32>(0.0);
    }
    else {
        return colour1(abs, n);
    }
}

fn julia64(c: Complex64, z: Complex64) -> vec3<f32> {
    var z = z;
    var n = 0u;
    var abs = f64(0);

    while (abs < f64(4) && n < LIM) {
        square64(&z);
        z += c;
        abs = z.x * z.x + z.y * z.y;
        n++;
    }

    abs = sqrt(abs);

    if (n == LIM) {
        return vec3<f32>(0.0);
    }
    else {
        return colour1(f32(abs), n);
    }
}

fn mandelbrot32(c: Complex32) -> vec3<f32> {
    return julia32(c, Complex32(0.0, 0.0));
}

fn mandelbrot64(c: Complex64) -> vec3<f32> {
    return julia64(c, Complex64(f64(0), f64(0)));
}

@fragment
fn fs_main(vertex: VertexOutput) -> @location(0) vec4<f32> {

    if properties.math64 != 0u {
        let c = vec2<f64>(vertex.tex_coords.xy * 2.0 - vec2<f32>(1.0, 1.0)) * properties.zoom + properties.center;
        return vec4<f32>((mandelbrot64(c)), 1.0);
    }
    else {
        let offset1 = vec2<f32>(0.0, 1.0 / properties.height * 0.5);
        let offset2 = vec2<f32>(1.0 / properties.height * 0.5, 0.0);
        let tex_coord1 = vertex.tex_coords.xy;
        let tex_coord2 = vertex.tex_coords.xy + offset1;
        let tex_coord3 = vertex.tex_coords.xy + offset2;
        let tex_coord4 = vertex.tex_coords.xy + offset1 + offset2;
        let c1 = (tex_coord1 * 2.0 - vec2<f32>(1.0, 1.0)) * f32(properties.zoom) + vec2<f32>(properties.center);
        let c2 = (tex_coord2 * 2.0 - vec2<f32>(1.0, 1.0)) * f32(properties.zoom) + vec2<f32>(properties.center);
        let c3 = (tex_coord3 * 2.0 - vec2<f32>(1.0, 1.0)) * f32(properties.zoom) + vec2<f32>(properties.center);
        let c4 = (tex_coord4 * 2.0 - vec2<f32>(1.0, 1.0)) * f32(properties.zoom) + vec2<f32>(properties.center);
        let colour = (mandelbrot32(c1) + mandelbrot32(c2) + mandelbrot32(c3) + mandelbrot32(c4)) / 4.0;
        return vec4<f32>(colour, 1.0);
    }
    // return vec4<f32>(julia(Complex(-0.25, 0.0), c), 1.0);
}
