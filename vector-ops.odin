package weekend

import   "core:c"
import m "core:math"

when ASSEMBLY_OPTIMIZATIONS {
    //Same as compiling then doing foreign import xxm "xmm-procs.lib".
    foreign import xxm "xmm-procs.s"

    foreign xxm {
        xmmnorm             :: proc( p1 :         [^] c.float) -> c.float ---
        xmmdot              :: proc( p1, p2 :     [^] c.float) -> c.float ---
        xmmselfdot          :: proc( p1 :         [^] c.float) -> c.float ---
        xmmselfdotdiff      :: proc( p1, p2 :     [^] c.float) -> c.float ---
        xmmdotdifftilde     :: proc( p1, p2, p3 : [^] c.float) -> c.float ---
        xmmdiscriminant     :: proc( p1, p2, p3 : [^] c.float, r : c.float) -> c.float ---
    }
}

// TODO: Could the duplication of procs below be reduced with union types?
normp30 :: proc(ptr : ^Point30) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmnorm(cast([^] f32) ptr)
    } else {
        return m.sqrt(ptr.x * ptr.x + ptr.y * ptr.y + ptr.z * ptr.z)
    }
}

normv30 :: proc(ptr : ^Vec30) -> f32 {
    return normp30(cast(^Point30) ptr)
}

norm :: proc{normp30, normv30}

dotp30 :: proc(p1, p2 : ^Point30) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmdot(cast([^] f32) p1, cast([^] f32) p2)
    } else {
        return p1.x *p2.x + p1.y * p2.y + p1.z * p2.z
    }
}

dotv30 :: proc(p1, p2 : ^Vec30) -> f32 {
    return dotp30(cast(^Point30) p1, cast(^Point30) p2)
}

dot :: proc{ dotp30, dotv30 }

selfdotp30 :: proc(ptr : ^Point30) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmselfdot(cast([^] f32) ptr)
    } else {
        return dotp30(ptr,ptr)
    }
}

selfdotv30 :: proc(ptr : ^Vec30) -> f32 {
    return selfdotp30(cast(^Point30) ptr)
}

selfdot :: proc{selfdotp30, selfdotv30}

dotdiffp30p30 :: proc(p1, p2 : ^Point30) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmselfdotdiff(cast([^] f32) p1, cast([^] f32) p2)
    } else {
        return (p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y) + (p1.z - p2.z) * (p1.z - p2.z) 
    }
}

dotdiffv30v30 :: proc(v1, v2 : ^Vec30) -> f32 {
    return dotdiffp30p30(cast(^Point30) v1, cast(^Point30) v2)
}

dotdiff :: proc{dotdiffp30p30, dotdiffv30v30}

dotdifftilde :: proc(v1 : ^Vec30, p2, p3 : ^Point30) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmdotdifftilde(cast([^] f32) v1, cast([^] f32) p2, cast([^] f32) p3)
    } else {
        return v1.x * (p2.x - p3.x) + v1.y * (p2.y - p3.y) + v1.z * (p2.z - p3.z)
    }
}

discriminant :: proc( rayv : ^Vec30, rayp, sphc : ^Point30, rad : f32) -> f32 {
    when ASSEMBLY_OPTIMIZATIONS {
        return xmmdiscriminant(cast([^] f32) rayv, cast([^] f32) rayp, cast([^] f32) sphc, rad)
    } else {
        a := selfdot(rayv)
        b := 2 * dotdifftilde(rayv, rayp, sphc)
        c := dotdiff(rayp, sphc) - rad * rad
        return b*b - 4*a*c
    }
}
