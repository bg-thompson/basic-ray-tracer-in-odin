package weekend

import f  "core:fmt"
import m  "core:math"
import rm "core:math/rand"
import    "core:builtin"

RECURSION_STACK_GUARD :: 30

// Convention: Y is 'up', X is 'right', Z is 'backwards.
// Convention: Whenever a vector is created, it should be converted into a unit vector
// if not already a unit vector.

render_image :: proc(pixels : [] Pixel) {
    // Rays are sent from a disk with center ORIGIN and radius APERTURE which is parallel to
    // a rectangle with center LOOKAT in a plane orthogonal to the vector LOOKAT - ORIGIN.
    // The vertical direction of the plane, vplane, is determined by projecting VUP
    // into the plane.

    // Camera setup.
    // Odin's compile-time evaluation doesn't (as of June 2023) extend to vector operations,
    // so this has to be done an runtime :(
    
    vup         := VUP
    lookvector  := Vec30(LOOKAT - ORIGIN)
    dlookat     := norm(&lookvector)
    ulookvector := lookvector / norm(&lookvector)
    vplane      := vup - dot(&vup, &ulookvector) * ulookvector
    uvplane     := vplane / norm(&vplane)
    rplanexyz   := cross3(ulookvector.xyz, uvplane.xyz)
    rplane      := Vec30{rplanexyz.x, rplanexyz.y, rplanexyz.z, 0}
    
    // The rectangle where rays are projected has height [-d,d] where d is the viewing
    // distance to LOOKAT, dlookat.
    // Determine the bottom left corner vector of this rectangle, as well as the
    // horizontal and vertical vectors describing its width and height.
    bl_canvas := LOOKAT - Point30(ASPECT_RATIO * rplane + 1 * uvplane) * dlookat / ZOOM
    bl_vec    := Vec30(bl_canvas - ORIGIN)
    hc_vec    := 2 * ASPECT_RATIO * rplane * dlookat / ZOOM
    vc_vec    := 2 * uvplane * dlookat / ZOOM

    for j in 0..<HIDTH {
        for i in 0..<WIDTH {
            pcolor := COLOR_DEBUG
            
            mcolor : Color3 = 0
            
            // Create multiple rays going to the same pixel to create a more realistic render.
            for mn in 0..<MULTISAMPLE_NUMBER {
                xe := rm.float32()
                ye := rm.float32()
                xp := (f32(i) + xe) / f32(WIDTH)
                yp := 1 - (f32(j) + ye) / f32(HIDTH) // Invert so the image is the correct 'way up'.
                // Create a ray to a disc of radius APERTURE to simulate defocus blur.
                random_uvec2 := random_unit_vector2()
                nudge := random_uvec2.x * rplane + random_uvec2.y * uvplane
                nudge *= APERTURE
                sray := Ray{ORIGIN + Point30(nudge), bl_vec + xp * hc_vec + yp * vc_vec - nudge}
                sray.v *= 1 / norm(&sray.v)
                scolor := compute_ray_color(&sray.p, &sray.v, 0)
                mcolor += scolor
            }
            
            // Set pixel color.
            pcolor = mcolor / f32(MULTISAMPLE_NUMBER)
            pixel := color_to_pixel(pcolor)
            pixels[WIDTH * j + i] = pixel
            
            // Update progress bar (if appropriate).
            UPDATE_PBAR_INTERVAL :: NPIXELS / 100
            if (WIDTH * j + i) % UPDATE_PBAR_INTERVAL == 0 || (WIDTH * j + i) == NPIXELS - 1 {
                pbar := make_progress_bar(f64(WIDTH * j + i) / f64(NPIXELS - 1))
                f.printf(pbar)
            }
        }
    }
    f.println("")
    return
}

compute_ray_color :: proc( rayp : ^Point30, rayv : ^Vec30, stack_depth : int) -> (color : Color3) {
    using MaterialType
    // Guard the stack from large recursion.
    if stack_depth >= RECURSION_STACK_GUARD {
        return COLOR_BLACK
    }
    // Calculate the first point of intersection (if any) with the spheres.
    sphere_array := gb_sphere_array
    intersected := false
    t  := builtin.max(f32)
    si := -1
    for sphere, tsi in sphere_array {
        if sphere.r == 0 { continue }
        temp_t, temp_intersected := ray_sphere_intersection(rayv, rayp, &sphere_array[tsi].c, sphere.r)
        if temp_intersected && temp_t < t {
            intersected = true
            t = temp_t
            si = tsi
        }
    }
    if ! intersected {
        // Base the background color the y component of rays.
        color := background_color(rayv)
        return color
    }
    // Calculate the normal vector at the closest sphere intersection.
    intersection_point := rayp^ + Point30(t * rayv^)
    normal := Vec30(intersection_point - sphere_array[si].c)
    assert(normal != 0)
    normal *= 1 / norm(&normal)


    // Construct a new ray.
    next_ray : Ray
    next_ray.p = intersection_point

    // Create random ray that won't add to the normal to give the zero-vector.
    // Needed when the material type is .Diffuse or .Metal.
    random_uvec := random_unit_vector3()
    if random_uvec == -normal {
        f.println("\nWARNING: Heisenbug occurred! (random_uvec = -normal)") // @warning
        f.println("Attempting to correct...") // @warning
        random_uvec = normal
    }

    // Scatter rays according to the material at the point of intersection.
    sphere_material := sphere_array[si].mat
    
    switch sphere_material.type {
    case .Diffuse:
        // Determine whether or not to scatter randomly.
        scatterf := rm.float32()
        if scatterf > sphere_material.param {
            return sphere_material.color
        } else {
            next_ray.v = normal + random_uvec
            next_ray.v *= 1 / norm(&next_ray.v)
        }
    case .Metal:
        // Assume that all light is reflected (minus the usual absorption)
        reflected_ray  := reflect_vector(rayv,&normal)
        fuzz_vector    := random_uvec * sphere_material.param
        next_ray.v      = reflected_ray + fuzz_vector
        next_ray.v     *= 1 / norm(&next_ray.v)
    case .Glass:
        // Assume that most outside light undergoes refraction, with the amount of
        // reflected light controlled by Schlick's approximation.
        glass_refractive_index := sphere_material.param
        // Determine possible angle of refraction depending on material.
        cos_alpha := dot(rayv, &normal)
        outside_glass  := cos_alpha <= 0
        if outside_glass { cos_alpha *= -1 }
        if cos_alpha > 1 {
            // f.println("\nWARNING: Heisenbug! (cos_alpha > 1)") // @warning
            // f.println("val:", cos_alpha,"Attempting to correct...")     // @warning
            cos_alpha  = 1
        }
        sin_alpha := m.sqrt(1 - cos_alpha * cos_alpha)
        sin_beta  := sin_alpha
        // Apply Snell's law, assuming the refractive index outside of the glass is 1.0.
        if outside_glass {
            sin_beta *= 1.0 / glass_refractive_index
        } else {
            sin_beta *= 1.0 * glass_refractive_index
        }
        // Apply Schlick's approximation
        schlick_reflecting := false
        if sin_beta <= 1 && outside_glass {
            ratio := glass_refractive_index
            reflect_chance := rm.float32()
            reflection_approx := schlick_approximation(cos_alpha, ratio)
            schlick_reflecting = reflection_approx > reflect_chance
        }
        
        // Determine whether or not the ray reflects or refracts.
        if sin_beta > 1 || schlick_reflecting {
            // Reflect ray.
            reflected_ray := reflect_vector(rayv, &normal)
            next_ray.v = reflected_ray
        } else {
            // Refract ray.
            // Calculate component of ray orthogonal to normal.
            // Since we're using unit vectors,
            // the length of the orthogonal component is sin_alpha / sin_alpha'
            refracted_orthogonal : Vec30
            if outside_glass {
                refracted_orthogonal = (rayv^ + cos_alpha * normal) / glass_refractive_index
            } else {
                refracted_orthogonal = (rayv^ - cos_alpha * normal) * glass_refractive_index
            }
            ro_norm_squared := selfdot(&refracted_orthogonal)
            if ro_norm_squared > 1 {
                //              f.println("\nWARNING: Heisenbug! (ro_norm_squared > 1)") // @warning
                //              f.println("val:", ro_norm_squared,"Attempting to correct...")     // @warning
                ro_norm_squared = 1
            }
            refracted_normal_scale := m.sqrt(1 - ro_norm_squared)
            refracted_normal : Vec30
            if outside_glass {
                refracted_normal = -refracted_normal_scale * normal
            } else {
                refracted_normal =  refracted_normal_scale * normal
            }
            next_ray.v = refracted_orthogonal + refracted_normal
        }
        // Don't have the glass absorb as much light as other materials.
        color = 0.85 * compute_ray_color(&next_ray.p, &next_ray.v, stack_depth + 1)
        return color
    }
    color = 0.6 * compute_ray_color(&next_ray.p, &next_ray.v, stack_depth + 1)
    return color
}

ray_sphere_intersection :: proc( rayv : ^Vec30, rayp, sphc: ^Point30, sr : f32) -> (f32, bool) {
    if rayv^ == 0 { assert(false) }
    
    // Returns smallest t-value of intersection with a sphere IF:
    // - An intersection exists
    // - The value of t is positive.

    a   :=     selfdot(rayv)
    b   := 2 * dotdifftilde(rayv, rayp, sphc)
    c   :=     dotdiff(rayp, sphc) - sr * sr
    dis := b*b - 4*a*c

    // Exit if there are no intersections.
    if dis < 0 {
        return 0, false
    } else {
        sqrtd := m.sqrt(dis)
        // Calculate the t-values of the intersections per quadratic formula.
        t1, t2 := (-b + sqrtd)/(2*a), (-b - sqrtd)/(2*a)
        EPSILON :: 0.0001 // Attempt to stop shadow acne.
        switch {
        case t1 <= EPSILON && t2 <= EPSILON:
            return EPSILON, false
        case t1 <= EPSILON && t2 > EPSILON:
            return t2, true
        case t1 > EPSILON && t2 <= EPSILON:
            return t1, true
        case t1 > EPSILON && t2 > EPSILON:
            return min(t1,t2), true
            case:
            assert(false) // This case should never be reached.
        }
    }
    assert(false) // Execution should never reach here.
    return 0, false
}

geometry_tests :: proc() {
    f.println(DB, "Running geometry tests...")
    ray0        := Ray{Point30{0,0,0,0},  Vec30{0,0,-1,0}}
    ray1        := Ray{Point30{0,1,0,0},  Vec30{0,0,-1,0}}
    rayn2       := Ray{Point30{0,-2,0,0}, Vec30{0,0,-1,0}}
    sphere1     := Sphere{Point30{0,0,-5,0},1,MATERIAL_UNSHINY_RED}

    t1, _, e1 := ray_sphere_intersection(&ray0.v, &ray0.p, &sphere1.c, sphere1.r), f32(4)
    //    f.println(DB, "Ray0-Sphere1 act./exp.", t1, e1) // @debug
    assert(t1 == e1)
    t2, _, e2 := ray_sphere_intersection(&ray1.v, &ray1.p, &sphere1.c, sphere1.r), f32(5)
    //    f.println(DB, "Ray1-Sphere1 /act./exp", t2,e2) // @debug
    assert(t2 == e2)
    _, t3, e3 := ray_sphere_intersection(&rayn2.v, &rayn2.p, &sphere1.c, sphere1.r), false
    //    f.println(DB, "Rayn2-Sphere1 /act./exp", t3, e3) // @debug
    assert(t3 == e3)
    f.println(DB, "Tests passed!")
}

// Determine the background color by where a normalized ray would go.
background_color :: proc( rayv : ^Vec30) -> (color : Color3) {
    comp := rayv.y
    color = lerp(COLOR_WHITE, COLOR_BG, 0.5 * (comp + 1))
    return color
}

color_to_pixel :: proc( c : Color3) -> (p : Pixel) {
    ok := 0 <= c.x && c.x <= 1 && 0 <= c.y && c.y <= 1 && 0 <= c.z && c.z <= 1
    if ! ok {
        f.println("ERROR: Trying to convert an invalid color --- ", c)
        assert(ok)
    }
    // Gamma correct with gamma 2.
    xgamma := m.sqrt(c.x)
    ygamma := m.sqrt(c.y)
    zgamma := m.sqrt(c.z)
    return Pixel{int(255 * xgamma), int(255 * ygamma), int(255 * zgamma)}
}

reflect_vector :: proc(rayv, normal : ^Vec30) -> Vec30 {
    return rayv^ - 2 * dot(rayv, normal) * normal^
}

// Glass has reflectivity which varies with angle. Approximate this
// with Schlick's approximation.
schlick_approximation :: proc( cos_value, ratio : f32) -> f32 {
    r0 := (1 - ratio) / (1 + ratio)
    r0 *= r0
    approx := r0 + (1 - r0) * m.pow(1 - cos_value,5)
    return approx
}
