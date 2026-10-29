import re, sys

P = {
  'forest': dict(navy='0E3B2E', bg='F6F4EC', coral='D9534F', teal='1F9D63',
                 gold='E3A72F', goldDark='8A5A00', ink='1D2A24',
                 muted='6F7B74', line='E4E1D6'),
  'plum':   dict(navy='3B1F5C', bg='F7F3FA', coral='E5484D', teal='12A594',
                 gold='F5B83D', goldDark='9A6B00', ink='231A33',
                 muted='7A7090', line='E6DFEF'),
  'mint':   dict(navy='1F2933', bg='F5F6F5', coral='E5484D', teal='2BB673',
                 gold='F5A623', goldDark='8F5A00', ink='1B2430',
                 muted='6B7684', line='E2E6E4'),
}
name = sys.argv[1] if len(sys.argv) > 1 else 'forest'
if name not in P:
    sys.exit('Pick one of: ' + ', '.join(P))
c = P[name]

block = 'class C {\n' + ''.join(
    f'  static const {k} = Color(0xFF{v});\n' for k, v in c.items()) + '}'
s = open('lib/theme.dart').read()
s2, n = re.subn(r'class C \{.*?\n\}', lambda m: block, s, count=1, flags=re.S)
if n == 0:
    sys.exit('FAILED: could not find class C in lib/theme.dart')
open('lib/theme.dart', 'w').write(s2)

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

m = open('tools/make_icon.py').read()
for var, key in (('NAVY', 'navy'), ('GOLD', 'gold'), ('TEAL', 'teal')):
    m = re.sub(var + r' = \(.*?\)', f'{var} = {rgb(c[key])}', m, count=1)
open('tools/make_icon.py', 'w').write(m)

p = open('pubspec.yaml').read()
p = re.sub(r'adaptive_icon_background: "#[0-9A-Fa-f]{6}"',
           f'adaptive_icon_background: "#{c["navy"]}"', p)
open('pubspec.yaml', 'w').write(p)
print('Theme set to', name)
