# 403: damage / stamina cost x1.2, heal x1.8 on authoring JSON. Prints every change.
import json, glob, math, sys, os
D, H = 1.2, 1.8
root = 'data/authoring'
log = []
def r0(x): return math.floor(x + 0.5)
def r1(x): return math.floor(x * 10 + 0.5) / 10
def num(orig, new):
    if isinstance(orig, int) and float(new).is_integer(): return int(new)
    return float(new)
def setv(d, k, f, rnd, fname, what, default=None):
    o = d.get(k, default)
    if o is None or isinstance(o, bool) or not isinstance(o, (int, float)): return
    n = rnd(o * f)
    if n == o: log.append((fname, what, o, n)); return
    d[k] = num(o if k in d else float(o), n)
    log.append((fname, what, o, d[k]))

def walk_item(o, fname, ctx):
    if isinstance(o, dict):
        t = o.get('type')
        if t == 'deal_damage' and isinstance(o.get('amount'), (int, float)):
            setv(o, 'amount', D, r0, fname, 'deal_damage.amount')
        if t == 'resource' and 'amount_stat' not in o:
            setv(o, 'amount', D, r0, fname, 'cost.stamina', 10.0)
        if t == 'change_resource' and o.get('resource_key', 'hp') in ('hp', 'stamina') and not isinstance(o.get('amount'), dict):
            if o.get('amount', 5.0) > 0 and o.get('target', 'SELF') == 'SELF':
                setv(o, 'amount', H, r0, fname, 'heal.' + o.get('resource_key', 'hp'), 5.0)
        if o.get('stat') == 'regen_hp' and 'amount' in o:
            setv(o, 'amount', H, r1, fname, 'regen_hp(mod)')
        for k, v in o.items():
            if k == 'base_stats' and isinstance(v, dict):
                setv(v, 'damage', D, r0, fname, 'base_stats.damage')
                setv(v, 'regen_hp', H, r1, fname, 'base_stats.regen_hp')
            elif k == 'eat_trait' and isinstance(v, dict):
                setv(v, 'regen_hp', H, r1, fname, 'eat_trait.regen_hp')
            walk_item(v, fname, ctx)
    elif isinstance(o, list):
        for v in o: walk_item(v, fname, ctx)

def save(path, d):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')

files = sorted(glob.glob(root + '/items/*.json')) + sorted(glob.glob(root + '/rule_parts/*.json')) \
    + [root + '/run_buffs/guard_horn.json', root + '/buffs/sun_light.json']
for p in files:
    raw = open(p, encoding='utf-8').read()
    d = json.loads(raw)
    before = len(log)
    walk_item(d, os.path.relpath(p, root), None)
    if len(log) != before: save(p, d)

# canteen fruit flat regen
p = root + '/base_rules/canteen.json'
d = json.load(open(p, encoding='utf-8'))
for k, e in d['entries'].items():
    if e.get('category') == 'fruit' and 'flat' in e:
        setv(e, 'flat', H, r1, 'canteen.' + k, 'fruit regen_hp')
save(p, d)

# god cards
gods = {'god_brute_regen': [('regen', H, r1)], 'god_skill_vigor': [('per', H, r1)], 'god_skill_breath': [('per', H, r1)],
        'god_earth_vital': [('pct', H, r0)], 'god_skill_fist': [('damage', D, r0)]}
for gid, keys in gods.items():
    p = root + '/run_buffs/%s.json' % gid
    d = json.load(open(p, encoding='utf-8'))
    for e in d['effects']:
        if e.get('type') == 'god_card':
            for k, f, rnd in keys: setv(e['values'], k, f, rnd, gid, 'god.' + k)
    save(p, d)

json.dump(log, open(sys.argv[1], 'w'), ensure_ascii=False)
print(len(log), 'entries')
