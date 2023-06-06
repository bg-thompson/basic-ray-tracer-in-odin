default rel
bits 64

segment .text
global xmmnorm
global xmmdot        
global xmmselfdot
global xmmselfdotdiff
global xmmdotdifftilde
global xmmdiscriminant

xmmnorm:
	movups xmm0, [rcx]
	mulps  xmm0, xmm0
	haddps xmm0, xmm0
	haddps xmm0, xmm0
        sqrtss xmm0, xmm0       
	ret
        
xmmdot:
        movups xmm0, [rcx]
        movups xmm1, [rdx]
        mulps  xmm0, xmm1
        haddps xmm0, xmm0
        haddps xmm0, xmm0
        ret
        
xmmselfdot:
        movups xmm0, [rcx]
        mulps  xmm0, xmm0
        haddps xmm0, xmm0
        haddps xmm0, xmm0
        ret

xmmselfdotdiff:
        movups xmm0, [rcx]
        movups xmm1, [rdx]
        subps  xmm0, xmm1
        mulps  xmm0, xmm0
        haddps xmm0, xmm0
        haddps xmm0, xmm0
        ret
        
xmmdotdifftilde:
        movups xmm1, [rdx]
        movups xmm2, [r8]
        movups xmm0, [rcx]
        subps  xmm1, xmm2
        mulps  xmm0, xmm1
        haddps xmm0, xmm0
        haddps xmm0, xmm0
        ret
        
xmmdiscriminant:
        movups xmm0, [rcx]      ; x0 = v
        movups xmm1, [rdx]      ; x1 = rp
        movups xmm2, [r8]       ; x2 = sc
        mulss  xmm3, xmm3       ; x3 = r^2
        movups xmm4, xmm3
        subps  xmm1, xmm2       ; x1 = pc
        movups xmm2, xmm0
        mulps  xmm2, xmm1       ; x2 = v . pc
        mulps  xmm0, xmm0       ; x0 = v.v
        mulps  xmm1, xmm1       ; x1 = pc.pc
        haddps xmm0, xmm0
        haddps xmm1, xmm1
        haddps xmm2, xmm2
        haddps xmm0, xmm0       ; v.v
        haddps xmm1, xmm1       ; pc.pc
        haddps xmm2, xmm2       ; v.pc
        addss  xmm0, xmm0       ; [2a]
        addss  xmm2, xmm2       ; [b]
        subss  xmm1, xmm4       ; [c]
        mulss  xmm2, xmm2       ; [b^2]
        addss  xmm1, xmm1       ; [2c]
        mulss  xmm1, xmm0       ; [4ac]
        subss  xmm2, xmm1 ; [b^2 - 4ac]
        movups xmm0, xmm2
        ret
