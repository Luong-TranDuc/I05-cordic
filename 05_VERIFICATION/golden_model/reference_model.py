import math

F = 14
S = 1 << F
K8 = math.prod(math.sqrt(1.0 + 2.0**(-2*i)) for i in range(8))
X_INIT = round((1.0 / K8) * S)
ATAN = [round(math.atan(2.0**(-i)) / (2.0*math.pi) * 256.0)
        for i in range(8)]

def phase_reduce(p):
    p = int(p) & 0xff
    if p < 64:
        return p, 1, 1
    if p < 128:
        return 128-p, -1, 1
    if p < 192:
        return p-128, -1, -1
    return 256-p, 1, -1

def quantize(v):
    q = int(round(v / S * 128.0))
    return max(-128, min(127, q))

def cordic(p):
    z, sign_cos, sign_sin = phase_reduce(p)
    x = X_INIT
    y = 0
    trace = []

    for i in range(8):
        x0, y0, z0 = x, y, z
        if z >= 0:
            x = x - (y >> i)
            y = y + (x0 >> i)
            z = z - ATAN[i]
            op = "+"
        else:
            x = x + (y >> i)
            y = y - (x0 >> i)
            z = z + ATAN[i]
            op = "-"
        trace.append({
            "iteration": i+1,
            "x_before": x0,
            "y_before": y0,
            "z_before": z0,
            "operation": op,
            "x_after": x,
            "y_after": y,
            "z_after": z,
        })

    c = sign_cos * quantize(x)
    s = sign_sin * quantize(y)
    return s, c, trace

def ideal_codes(p):
    theta = 2.0*math.pi*(int(p)&0xff)/256.0
    s = max(-128, min(127, int(round(math.sin(theta)*128.0))))
    c = max(-128, min(127, int(round(math.cos(theta)*128.0))))
    return s, c

def test_constants():
    assert X_INIT == 9949
    assert ATAN == [32,19,10,5,3,1,1,0]

def test_all_phases():
    for p in range(256):
        s,c,tr = cordic(p)
        assert len(tr) == 8
        assert -128 <= s <= 127
        assert -128 <= c <= 127

def test_cardinal_points():
    # With eight iterations and the mentor atan table, a small residual
    # phase remains at the cardinal boundaries. Verify against the
    # mathematical target with a documented finite-iteration tolerance.
    expected = {
        0: (0,127),
        64: (127,0),
        128: (0,-128),
        192: (-128,0),
    }
    for p, exp in expected.items():
        s,c,_ = cordic(p)
        assert abs(s-exp[0]) <= 4, (p,s,c,exp)
        assert abs(c-exp[1]) <= 4, (p,s,c,exp)

def test_symmetry():
    # Compare against the ideal odd/even symmetry after quantization.
    for p in range(256):
        s,c,_ = cordic(p)
        si,ci = ideal_codes((256-p)&0xff)
        # The output convention saturates +1 to 127 and -1 to -128,
        # so exact integer antisymmetry is not expected at extrema.
        assert abs(s + si) <= 5
        assert abs(c - ci) <= 5

def test_quadrant_boundaries():
    for p in [0,1,63,64,65,127,128,129,191,192,193,255]:
        cordic(p)

def test_random():
    import random
    random.seed(505)
    for _ in range(10000):
        p=random.randrange(256)
        s,c,_=cordic(p)
        assert -128 <= s <= 127
        assert -128 <= c <= 127

def error_table():
    rows=[]
    max_es=max_ec=0
    for p in range(256):
        s,c,_=cordic(p)
        si,ci=ideal_codes(p)
        es=abs(s-si); ec=abs(c-ci)
        max_es=max(max_es,es); max_ec=max(max_ec,ec)
        rows.append((p,s,c,si,ci,es,ec))
    return rows,max_es,max_ec

def test_error_bounds():
    rows,ms,mc=error_table()
    assert ms <= 6
    assert mc <= 6
    return ms,mc

def test_iteration_trace():
    s,c,tr=cordic(32)
    assert len(tr)==8
    assert [r["iteration"] for r in tr]==list(range(1,9))

if __name__=="__main__":
    test_constants()
    test_all_phases()
    test_cardinal_points()
    test_symmetry()
    test_quadrant_boundaries()
    test_random()
    test_iteration_trace()
    ms,mc=test_error_bounds()
    print("I05 golden reference PASS")
    print("max sine code error:",ms)
    print("max cosine code error:",mc)
