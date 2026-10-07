import io, sys

def load(p):
    s = open(p, 'rb').read().decode('utf-8', 'surrogateescape')
    return s.replace('\r\n', '\n')

def save(p, s):
    open(p, 'wb').write(s.replace('\n', '\r\n').encode('utf-8', 'surrogateescape'))

def sub(p, old, new, count=1):
    s = load(p)
    n = s.count(old)
    if n != count:
        print(f"!! {p}: expected {count} occurrences, found {n}")
        sys.exit(1)
    s = s.replace(old, new, count)
    save(p, s)
    print(f"ok {p}: {count} replacement(s)")
