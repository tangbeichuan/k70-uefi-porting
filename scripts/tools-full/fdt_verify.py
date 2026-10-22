import struct

P = r'/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_cb20.dtb'
b = open(P, 'rb').read()
magic, total, off_struct, off_strings = struct.unpack('>IIII', b[:16])
print('magic=%08x total=%d struct=%#x strings=%#x' % (magic, total, off_struct, off_strings))

BEGIN, ENDN, PROP, NOP, ENDT = 1, 2, 3, 4, 9


def be32(o):
    return struct.unpack('>I', b[o:o + 4])[0]


def node_name(o):
    end = b.index(b'\0', o)
    return b[o:end].decode('latin1')


def skip(node):
    q = node + 4
    q = (b.index(b'\0', q) + 4) & ~3
    depth = 1
    while q + 4 <= total:
        t = be32(q)
        if t == BEGIN:
            depth += 1
            q += 4
            q = (b.index(b'\0', q) + 4) & ~3
        elif t == PROP:
            ln = be32(q + 4)
            q += 12 + ((ln + 3) & ~3)
        elif t == NOP:
            q += 4
        elif t == ENDN:
            depth -= 1
            q += 4
            if depth == 0:
                return q
        else:
            return total
    return total


def find_child(node, want):
    q = node + 4
    q = (b.index(b'\0', q) + 4) & ~3
    while q + 4 <= total:
        t = be32(q)
        if t == BEGIN:
            nm = node_name(q + 4)
            if nm == want or nm.split('@')[0] == want:
                return q
            q = skip(q)
        elif t == PROP:
            ln = be32(q + 4)
            q += 12 + ((ln + 3) & ~3)
        elif t == NOP:
            q += 4
        else:
            return None
    return None


def path(p):
    node = off_struct
    for part in [x for x in p.split('/') if x]:
        node = find_child(node, part)
        if node is None:
            return None
    return node


def getprop(node, name):
    q = node + 4
    q = (b.index(b'\0', q) + 4) & ~3
    while q + 4 <= total:
        t = be32(q)
        if t == PROP:
            ln = be32(q + 4)
            no = be32(q + 8)
            pn = node_name(off_strings + no)
            if pn == name:
                return b[q + 12:q + 12 + ln]
            q += 12 + ((ln + 3) & ~3)
        elif t == NOP:
            q += 4
        elif t == BEGIN:
            q = skip(q)
        else:
            break
    return None


def u32(v):
    if v and len(v) >= 4:
        return struct.unpack('<I', v[:4])[0]
    return None


for p in ('/soc', '/soc/ufs0', '/soc/ufs0/timeout_values',
          '/soc/ufs0/init_speed_params', '/soc/ufs0/perf_speed_params'):
    n = path(p)
    print('%-32s -> %s' % (p, hex(n) if n else 'NOT FOUND'))

u = path('/soc/ufs0')
if u:
    print('  compatible =', getprop(u, 'compatible'))
    r = getprop(u, 'reg')
    print('  reg        =', r, '-> base', hex(u32(r) or 0))
    print('  FUA_Value  =', getprop(u, 'FUA_Value'))
    bm = getprop(u, 'BatteryThresholdMv')
    print('  BattMv     =', bm, '->', u32(bm))
tv = path('/soc/ufs0/timeout_values')
if tv:
    v = getprop(tv, 'fDeviceInitTimeoutUs')
    print('  fDeviceInitTimeoutUs =', v, '->', hex(u32(v) or 0))
    v = getprop(tv, 'UTRDPollTimeoutUs')
    print('  UTRDPollTimeoutUs    =', v, '->', hex(u32(v) or 0))
