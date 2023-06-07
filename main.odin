// A simple ray-tracer based on "Ray Tracing in One Weekend" by Shirley et. al.
//
// By Benjamin Thompson (github: bg-thompson)
// Date written: 2023.06.06
//
// "Ray Tracing in One Weekend" can be found for free online at:
// https://raytracing.github.io/books/RayTracingInOneWeekend.html
//
// See README.md for information about building, the similarity to Shirley et. al,
// and optimizations, but in summary:
//
// 1. The command
//
//        odin run . -o:speed
//
//    renders the image (it compiles and then runs the program, which outputs image.ppm).
// 2. The raytracer is simple, and does NOT utilize multithreading or bounded volume hierarchies.
// 3. The code contains hand-rolled assembly SIMD procedures to speed up DEBUG builds, but
//    these are off by default, (controlled by ASSEMBLY_OPTIMIZATIONS below), and
//    in practice they make -o:speed builds slightly slower.
//
// Coordinate convention: Y is 'up', X is 'right', Z is 'backwards.

package weekend

import f  "core:fmt"
import m  "core:math"
import rm "core:math/rand"
import la "core:math/linalg"
import    "core:os"
import s  "core:strings"
import    "core:unicode/utf8"
import    "core:time"

// To make debug builds faster. See README.md before turning on.
ASSEMBLY_OPTIMIZATIONS :: false

// How many rays are cast to estimate the value of a pixel.
MULTISAMPLE_NUMBER :: 10

// Core camera / rendering properties.
HIDTH    :: 1 * 270           // Height.
WIDTH    :: 1 * 480
NPIXELS  :: WIDTH * HIDTH
ORIGIN   :: Point30{13,2,3,0}
LOOKAT   :: Point30{0,0,0,0}
VUP      :: Vec30{0,1,0,0}    // Used to orient image.
ZOOM     :: cast(f32) 5.5
APERTURE :: 0.03              // When 0, no defocus blur.
SPHERE_GRID_DIM :: 21

ASPECT_RATIO :: f32(WIDTH) / f32(HIDTH)

// The filename the render is written to.
OUTPUT_FILENAME :: `image.ppm`

DB       :: `DEBUG`

// Core data types. The names Point30 / Vec30 reflect that the fourth
// float is always zeroed. SIMD instructions work better with arrays of
// four 32-bit floats than arrays of three 32-bit floats.
Vec30   :: distinct [4] f32
Point30 :: distinct [4] f32
Color3  :: distinct [3] f32 // RGB, not RGBA
Pixel   :: distinct [3] int

Ray    :: struct{ p : Point30, v : Vec30 }
Sphere :: struct{ c : Point30,  r : f32, mat : Material  }

Material :: struct{
    type        : MaterialType,
    color       : Color3,
    param       : f32,
}

MaterialType :: enum u8 {
    Diffuse,
    Metal,
    Glass,
}

cross3 :: la.vector_cross3
lerp   :: m.lerp // Takes three args, a,b,t.

gb_sphere_array : [] Sphere

// Large spheres
SPHERE0 :: Sphere{Point30{0,-1000,0,0}, 1000, MATERIAL_UNSHINY_GRAY}    // Base sphere
SPHERE1 :: Sphere{Point30{-4,1,0,0}, 1, MATERIAL_UNSHINY_BROWN}         // Big sphere 1
SPHERE2 :: Sphere{Point30{ 0,1,0,0}, 1, MATERIAL_GLASS}                 // Big sphere 2
SPHERE3 :: Sphere{Point30{ 4,1,0,0}, 1, MATERIAL_MIRROR}                // Big sphere 3

when ASSEMBLY_OPTIMIZATIONS {
    xmm_proc_tests :: proc() {
        f.println(DB, "Running xmm assembly proc tests...")
        e1 : [4] f32 = {1,0,-1,0}
        e2 : [4] f32 = {3,3,5,0}
        e3 : [4] f32 = {2,2,4,0}
        assert( xmmselfdot(&e1[0]) == 2)
        assert( xmmselfdot(&e2[0]) == 43)
        assert( xmmselfdotdiff(&e1[0], &e1[0]) == 0)
        assert( xmmselfdotdiff(&e1[0],&e2[0]) == 49)
        assert( xmmdotdifftilde(&e1[0],&e2[0],&e3[0]) == 0)
        assert( xmmdotdifftilde(&e1[0],&e3[0],&e3[0]) == 0)
        assert( xmmdotdifftilde(&e2[0],&e3[0],&e1[0]) == 34)
        assert( xmmdiscriminant(&e1[0],&e2[0],&e3[0],2) == 8)
        f.println(DB, "Tests passed!")
    }
}

main :: proc() {
    // Run tests to make check basic geometry calculations.
    when ASSEMBLY_OPTIMIZATIONS {
        xmm_proc_tests()
    }
    geometry_tests()

    // Draw various specific large spheres.
    gb_sphere_array = make([] Sphere, SPHERE_GRID_DIM * SPHERE_GRID_DIM + 4)
    gb_sphere_array[0] = SPHERE0
    gb_sphere_array[1] = SPHERE1
    gb_sphere_array[2] = SPHERE2
    gb_sphere_array[3] = SPHERE3

    // Randomly generate many smaller spheres of varying position and material.
    SMALL_RADIUS :: f32(0.2)
    for a in 0..<SPHERE_GRID_DIM {
        for b in 0..<SPHERE_GRID_DIM {
            xpos := f32(a) + 0.2 + 0.6 * rm.float32()
            zpos := f32(b) + 0.2 + 0.6 * rm.float32()
            possible_center := Point30{xpos - SPHERE_GRID_DIM / 2, SMALL_RADIUS, zpos - SPHERE_GRID_DIM / 2,0}
            // Make sure smaller spheres do not collide with large spheres.
            no_collisions := true
            for i in 1..<4 {
                sqdist := dotdiff(&possible_center, &gb_sphere_array[i].c)
                if sqdist < (1 + SMALL_RADIUS) * (1 + SMALL_RADIUS) {
                    no_collisions = false
                    break
                }
            }
            if no_collisions {
                material   : Material
                randf := rm.float32()
                switch {
                case randf < 0.8:
                    material = MATERIAL_UNSHINY_RED
                case 0.8 <= randf && randf < 0.9:
                    material = MATERIAL_MIRROR
                    case:
                    material = MATERIAL_GLASS
                }
                if material.type == MaterialType.Diffuse {
                    r1 := rm.float32()
                    r2 := rm.float32()
                    r3 := rm.float32()
                    r4 := rm.float32()
                    r5 := rm.float32()
                    r6 := rm.float32()
                    material.color = Color3{r1 * r2, r3 * r4, r5 * r6}
                }
                new_sphere := Sphere{possible_center, SMALL_RADIUS, material}
                
                gb_sphere_array[4 + SPHERE_GRID_DIM * a + b] = new_sphere
            }
        }
    }
    
    // Render image, and keep track of how long it takes.
    t1 := time.now()
    pixels := make([] Pixel, NPIXELS)

    // Main render procedure! Contained in render.odin
    render_image(pixels)
    
    t2 := time.now()
    f.println("Time diff:", time.diff(t1,t2))

    // Create header of .ppm file.
    line1 := "P3\n"
    line2 := f.tprintf("%d %d\n", WIDTH, HIDTH)
    line3 := "255\n"
    header := s.concatenate([]string{line1, line2, line3})
    header_len := len(header)
    
    image      := make([]rune, header_len + 12*NPIXELS)

    // Write header.
    for r, i in header {
        image[i] = r
    }

    // Convert pixels into .ppm format.
    for p, i in pixels {
        prunes := pixel_to_runes(p)
        for r, j in prunes {
            image[header_len + 12*i + j] = r
        }
    }
    
    // Write .ppm file.
    image_str := utf8.runes_to_string(image)
    ok := os.write_entire_file(OUTPUT_FILENAME, transmute([]byte) image_str)
    if ok {
        f.println("File written!")
    } else {
        f.println("Writing file failed :(")
    }
}

// Convert a pixel into a .ppm array of runes (a string) describing the pixel.
pixel_to_runes :: proc(p : Pixel) -> (output : [12] rune) {
    ok := 0 <= p.x && p.x <= 255 && 0 <= p.y && p.y <= 255 && 0 <= p.z && p.z <= 255
    if ! ok {
        f.println("ERROR: Trying to write an invalid pixel --- ", p)
        assert(0 <= p.x && p.x <= 255 && 0 <= p.y && p.y <= 255 && 0 <= p.z && p.z <= 255)
    }
    output = ' '
    rs := f.tprintf("%d",p.x)
    gs := f.tprintf("%d",p.y)
    bs := f.tprintf("%d",p.z)
    for r, i in rs {
        output[i] = r
    }
    for r, i in gs {
        output[4 + i] = r
    }
    for r, i in bs {
        output[8 + i] = r
    }
    return
}
