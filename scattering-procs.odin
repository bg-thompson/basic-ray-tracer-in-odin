package weekend

import m  "core:math"
import rm "core:math/rand"

random_unit_vector2 :: proc() -> (ret : [2] f32) {
    // Choose a random point in the unit square until it lies within the unit circle.
    for {
        randx := rm.float32()
        randy := rm.float32()
        randx = 2 * randx - 1
        randy = 2 * randy - 1
        normsq := randx * randx + randy * randy
        if normsq <= 1 {
            ret.x = randx / m.sqrt(normsq)
            ret.y = randy / m.sqrt(normsq)
            break
        }
    }
    return ret
}

random_unit_vector3 :: proc() -> Vec30 {
    // Choose a random point in the unit cube until it lies within the unit sphere.
    vec := Vec30{0,0,0,0}
    for {
        randx := rm.float32()
        randy := rm.float32()
        randz := rm.float32()
        vec = Vec30{randx, randy, randz, 0}
        vec *= 2
        vec -= {1,1,1,0}
        vec_squarednorm := selfdot(&vec)
        if vec_squarednorm <= 1 {
            vec *= 1/vec_squarednorm
            break
        }
    }
    return vec
}
