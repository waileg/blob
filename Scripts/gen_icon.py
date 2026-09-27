import struct, zlib, math

def fnv1a(s):
    h = 0x811c9dc5
    for b in s.strip().lower().encode():
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h

def stream(h):
    out = []
    x = h if h else 0x9e3779b9
    for _ in range(8):
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        out.append(x)
    return out

def unit(v): return (v % 10000) / 10000.0

def traits(name):
    s = stream(fnv1a(name))
    silhouette = s[0] % 10
    hue = unit(s[1])
    eye = s[3] % 4
    mouth = unit(s[4]) * 2 - 1
    return silhouette, hue, eye, mouth

def hsl(h, s, l):
    c = (1 - abs(2*l - 1)) * s
    x = c * (1 - abs((h*6) % 2 - 1))
    m = l - c/2
    hh = (h*6) % 6
    r,g,b = [(c,x,0),(x,c,0),(0,c,x),(0,x,c),(x,0,c),(c,0,x)][int(hh)]
    return (r+m, g+m, b+m)

def blob_mask(size, cx=0.5, cy=0.5, squash=0.0, seeds=(0.4,0.5,0.4,0.5)):
    # rasterize the unit blob (4-anchor smooth curve) as a binary mask
    pts = []
    base = [(-math.pi/2, 0.40+seeds[0]*0.10), (0, 0.36+seeds[1]*0.10),
            (math.pi/2, 0.40+seeds[2]*0.10), (math.pi, 0.36+seeds[3]*0.10)]
    for ang, r in base:
        pts.append((cx+math.cos(ang)*r, cy+math.sin(ang)*r*(1.0-squash*0.25)))
    # build dense outline via cardinal spline through pts
    outline = []
    n = 40
    for i in range(4):
        p0 = pts[i]; p1 = pts[(i+1)%4]
        prev = pts[(i-1)%4]; nxt = pts[(i+2)%4]
        for k in range(n):
            t = k/n
            c1x = p0[0] + (p1[0]-prev[0])/6
            c1y = p0[1] + (p1[1]-prev[1])/6
            c2x = p1[0] - (nxt[0]-p0[0])/6
            c2y = p1[1] - (nxt[1]-p0[1])/6
            mt = 1-t
            x = mt**3*p0[0] + 3*mt**2*t*c1x + 3*mt*t**2*c2x + t**3*p1[0]
            y = mt**3*p0[1] + 3*mt**2*t*c1y + 3*mt*t**2*c2y + t**3*p1[1]
            outline.append((x, y))
    # even-odd fill via winding check on grid
    def inside(x, y):
        cnt = 0
        for i in range(len(outline)):
            x1, y1 = outline[i]
            x2, y2 = outline[(i+1) % len(outline)]
            if (y1 > y) != (y2 > y):
                xin = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
                if x < xin: cnt += 1
        return cnt % 2 == 1
    rows = []
    for py in range(size):
        row = bytearray(size)
        for px in range(size):
            if inside((px+0.5)/size, (py+0.5)/size):
                row[px] = 255
        rows.append(row)
    return rows

def png_write(path, size, pixel_fn):
    raw = b''
    for y in range(size):
        raw += b'\x00'
        for x in range(size):
            r, g, b, a = pixel_fn(x, y)
            raw += bytes((int(r*255), int(g*255), int(b*255), int(a*255)))
    def chunk(typ, data):
        c = struct.pack('>I', len(data)) + typ + data
        return c + struct.pack('>I', zlib.crc32(typ + data) & 0xFFFFFFFF)
    ihdr = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def make_icon(path, name="Blob"):
    size = 512
    sil, hue, eye, mouth = traits(name)
    top = hsl(hue, 0.72, 0.60)
    bot = hsl((hue + 0.5 + 0.07) % 1.0, 0.78, 0.55)
    mask = blob_mask(size, squash=0.1)
    # eyes/mouth params (unit coords)
    eyeY = 0.40 - eye*0.01
    eyeDX = 0.11 + eye*0.01
    def pixel(x, y):
        u = (x+0.5)/size; v = (y+0.5)/size
        if not mask[y][x]:
            return (0, 0, 0, 0)
        t = v
        r = top[0]*(1-t) + bot[0]*t
        g = top[1]*(1-t) + bot[1]*t
        b = top[2]*(1-t) + bot[2]*t
        # eyes
        for side in (-1, 1):
            ex = 0.5 + side*eyeDX
            d = math.hypot((u-ex)/0.05, (v-eyeY)/0.08)
            if d < 1:
                return (0.05, 0.05, 0.08, 1)
        # mouth
        my = eyeY + 0.16
        if abs(u-0.5) < 0.09 and abs(v - (my + mouth*0.06*(1-((u-0.5)/0.09)**2))) < 0.025:
            return (0.05, 0.05, 0.08, 1)
        return (r, g, b, 1)
    png_write(path, size, pixel)

if __name__ == "__main__":
    import sys
    make_icon(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "Blob")
    print("icon written")
