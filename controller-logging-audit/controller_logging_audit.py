"""
Usage: python3 run_audit.py <project_dir> <output_file> [5xx_data_file]
"""
import re, os, sys
from collections import defaultdict

REST_ANNO_NAMES = {'GetMapping','PostMapping','PutMapping','DeleteMapping','PatchMapping','RequestMapping'}
HTTP_METHOD_MAP = {
    'GetMapping':['GET'], 'PostMapping':['POST'], 'PutMapping':['PUT'],
    'DeleteMapping':['DELETE'], 'PatchMapping':['PATCH'], 'RequestMapping': None,
}
LOG_INFO_RE  = re.compile(r'\blog\s*\.\s*info\s*\(')
CONST_DEF_RE = re.compile(
    r'public\s+static\s+final\s+String\s+(\w+)\s*=\s*'
    r'((?:"(?:[^"\\]|\\.)*"|\s*\+\s*)+)\s*;'
)

def load_constants(project_dir):
    by_class, by_name = {}, defaultdict(list)
    for root, _, files in os.walk(project_dir):
        if '/test/' in root: continue
        for fn in files:
            if not fn.endswith('.java'): continue
            try: content = open(os.path.join(root,fn), encoding='utf-8', errors='replace').read()
            except: continue
            cls_m = re.search(r'\bclass\s+(\w+)', content)
            cls = cls_m.group(1) if cls_m else fn.replace('.java','')
            consts = {}
            for m in CONST_DEF_RE.finditer(content):
                name = m.group(1)
                parts = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
                val = ''.join(parts)
                consts[name] = val
                by_name[name].append(val)
            if consts:
                by_class[cls] = consts
    return by_class, by_name

def resolve_value(token, by_class, by_name):
    token = token.strip()
    parts = re.split(r'\s*\+\s*', token)
    resolved = ['']
    for part in parts:
        part = part.strip()
        if part.startswith('"') and part.endswith('"'):
            options = [part[1:-1]]
        elif '.' in part:
            cls, name = part.rsplit('.', 1)
            options = [by_class[cls][name]] if cls in by_class and name in by_class[cls] \
                      else (by_name.get(name) or [''])
        else:
            options = by_name.get(part) or ['']
        resolved = [r + o for r in resolved for o in options]
    return list(set(resolved))

def parse_anno_args(anno_args, by_class, by_name):
    if not anno_args or not anno_args.strip(): return [''], None
    val_m = re.search(r'(?:value|path)\s*=\s*(\{[^}]*\}|[^,)]+)', anno_args)
    raw = val_m.group(1).strip() if val_m else ''
    if not raw:
        bare = re.match(r'^(\{[^}]*\}|"[^"]*"|[\w.]+(?:\s*\+\s*[\w."]+)*)', anno_args.strip())
        raw = bare.group(1) if bare else ''
    tokens = re.split(r',(?![^{]*})', raw[1:-1]) if raw.startswith('{') else [raw]
    paths = []
    for tok in tokens:
        tok = tok.strip()
        if tok: paths.extend(resolve_value(tok, by_class, by_name))
    if not paths: paths = ['']
    http_methods = None
    meth_m = re.search(r'method\s*=\s*\{?([^}),]+)\}?', anno_args)
    if meth_m:
        found = re.findall(r'RequestMethod\.(\w+)', meth_m.group(1))
        if found: http_methods = found
    return paths, http_methods

def collect_multiline(lines, start):
    text = lines[start].strip()
    if '(' not in text: return text, start
    depth = text.count('(') - text.count(')')
    j = start + 1
    while depth > 0 and j < len(lines):
        chunk = lines[j].strip()
        text += ' ' + chunk
        depth += chunk.count('(') - chunk.count(')')
        j += 1
    return text, j - 1

def get_class_base_paths(lines, by_class, by_name):
    cls_idx = next((i for i,l in enumerate(lines) if re.search(r'\bclass\s+\w+', l)), None)
    if cls_idx is None: return ['']
    for i in range(cls_idx-1, max(cls_idx-30,-1), -1):
        m = re.match(r'@RequestMapping(?:\s*\(\s*(.*?)\s*\))?$', lines[i].strip(), re.DOTALL)
        if m:
            paths, _ = parse_anno_args(m.group(1) or '', by_class, by_name)
            return paths
    return ['']

def has_entry_log(lines, body_start):
    for bl in range(body_start, min(body_start+10, len(lines))):
        bline = lines[bl].strip()
        if not bline: continue
        if LOG_INFO_RE.search(bline): return True
        if not bline.startswith('@') and not bline.startswith('//'): return False
    return False

def analyze_file(filepath, by_class, by_name):
    try: lines = open(filepath, encoding='utf-8', errors='replace').read().split('\n')
    except: return []
    base_paths = get_class_base_paths(lines, by_class, by_name)
    results = []
    i = 0
    while i < len(lines):
        hit = re.search(
            r'@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping)\b',
            lines[i].strip()
        )
        if not hit: i += 1; continue
        anno_name = hit.group(1)
        anno_text, end_i = collect_multiline(lines, i)
        args_m = re.search(r'@(?:\w+Mapping|RequestMapping)\s*\(\s*(.*?)\s*\)\s*$', anno_text, re.DOTALL)
        anno_args = args_m.group(1) if args_m else ''
        method_paths, http_methods = parse_anno_args(anno_args, by_class, by_name)
        if http_methods is None:
            http_methods = HTTP_METHOD_MAP.get(anno_name) or ['GET','POST','PUT','DELETE','PATCH']
        j = end_i + 1
        while j < min(end_i+15, len(lines)):
            jline = lines[j].strip()
            if jline.startswith('@'):
                if re.search(r'@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping)\b', jline): break
                j += 1; continue
            if re.search(r'\bpublic\b', jline) and '(' in jline:
                sig, k = jline, j
                while ')' not in sig and k < j+8:
                    k += 1
                    if k < len(lines): sig += ' ' + lines[k].strip()
                mm = re.search(r'\bpublic\b[^(]*\s+(\w+)\s*\(', sig)
                if not mm: break
                method_name = mm.group(1)
                body_start = k + 1
                for bk in range(k, min(k+10, len(lines))):
                    if '{' in lines[bk]: body_start = bk+1; break
                logged = has_entry_log(lines, body_start)
                full_paths = []
                for bp in base_paths:
                    for mp in method_paths:
                        p = '/' + bp.strip('/') + '/' + mp.strip('/')
                        p = re.sub(r'/+', '/', p).rstrip('/') or '/'
                        full_paths.append(p)
                results.append({
                    'method': method_name, 'full_paths': list(set(full_paths)),
                    'has_log': logged, 'line': j+1, 'filepath': filepath,
                })
                i = k; break
            break
        i += 1
    return results

def path_to_regex(template):
    esc = re.escape(template).replace(r'\/', '/')
    pat = re.sub(r'\\\{[^}]+\\}', '[^/]+', esc)
    return re.compile('^' + pat + r'(\?.*)?$')

def main():
    project_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    out_file    = sys.argv[2] if len(sys.argv) > 2 else '/tmp/audit-report.txt'
    data_file   = sys.argv[3] if len(sys.argv) > 3 else '/tmp/5xx_endpoints.txt'
    proj_name   = os.path.basename(project_dir.rstrip('/'))

    print(f"Project: {proj_name}", flush=True)
    print("Loading constants...", flush=True)
    by_class, by_name = load_constants(project_dir)
    print(f"  {sum(len(v) for v in by_class.values())} constants in {len(by_class)} classes", flush=True)

    print("Analyzing controllers...", flush=True)
    all_endpoints = []
    for root, _, files in os.walk(project_dir):
        if '/test/' in root: continue
        for fn in files:
            if not fn.endswith('Controller.java'): continue
            for m in analyze_file(os.path.join(root, fn), by_class, by_name):
                all_endpoints.append(m)

    total   = len(all_endpoints)
    n_logged   = sum(1 for m in all_endpoints if m['has_log'])
    n_unlogged = total - n_logged
    pct = n_logged / total * 100 if total else 0
    print(f"  {total} REST endpoints: {n_logged} logged ({pct:.1f}%), {n_unlogged} unlogged ({100-pct:.1f}%)", flush=True)

    # Load nginx 5xx, strip context root
    error_by_stripped = {}
    try:
        with open(data_file) as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) != 2: continue
                cnt, uri = int(parts[0]), parts[1].split('?')[0]
                segs = [s for s in uri.split('/') if s]
                stripped = '/' + '/'.join(segs[1:]) if len(segs) > 1 else uri
                prev = error_by_stripped.get(stripped, (uri, 0))
                error_by_stripped[stripped] = (uri, prev[1] + cnt)
    except FileNotFoundError:
        print("  (no 5xx data file, skipping nginx matching)")

    print(f"  {len(error_by_stripped)} distinct stripped nginx URIs", flush=True)

    endpoint_regexes = []
    for m in all_endpoints:
        for path in m['full_paths']:
            try: endpoint_regexes.append((path_to_regex(path), path, m))
            except: pass

    matched_results, unmatched = [], []
    for stripped, (orig_uri, count) in sorted(error_by_stripped.items(), key=lambda x: -x[1][1]):
        hits = [(tmpl, m) for rx, tmpl, m in endpoint_regexes if rx.match(stripped)]
        if hits:
            for tmpl, m in hits:
                matched_results.append({
                    'count': count, 'uri': orig_uri, 'template': tmpl,
                    'filepath': m['filepath'], 'method': m['method'],
                    'has_log': m['has_log'], 'line': m['line'],
                })
        else:
            unmatched.append((count, orig_uri))

    deduped = {}
    for r in matched_results:
        key = (r['filepath'], r['method'])
        if key not in deduped or r['count'] > deduped[key]['count']:
            deduped[key] = r

    matched_unlogged = sorted([r for r in deduped.values() if not r['has_log']], key=lambda x: -x['count'])
    matched_logged   = sorted([r for r in deduped.values() if r['has_log']],     key=lambda x: -x['count'])
    all_unlogged     = sorted([m for m in all_endpoints if not m['has_log']],
                               key=lambda x: x['filepath'])

    # Write report
    with open(out_file, 'w') as f:
        f.write(f"Controller Logging Audit — {proj_name}\n")
        f.write(f"Generated by parsing @*Mapping paths + Java constants, matched against nginx access logs.\n")
        f.write("=" * 110 + "\n\n")

        f.write("COVERAGE SUMMARY\n")
        f.write(f"  Total REST endpoints : {total}\n")
        f.write(f"  Logged on entry      : {n_logged} ({pct:.1f}%)\n")
        f.write(f"  Missing log on entry : {n_unlogged} ({100-pct:.1f}%)\n\n")

        f.write("PRIORITY: UNLOGGED ENDPOINTS WITH PRODUCTION 5xx ERRORS (last 30d)\n")
        f.write(f"{'5xx Errors':>12}  {'Method':<50}  URL Template\n")
        f.write('-' * 130 + "\n")
        total_errs = 0
        for r in matched_unlogged:
            short = re.sub(r'.*/java/', '', r['filepath'])
            f.write(f"{r['count']:>12}  {r['method']:<50}  {r['template']}\n")
            f.write(f"{'':>12}  {short} (line {r['line']})\n\n")
            total_errs += r['count']
        f.write(f"\n  → {len(matched_unlogged)} unlogged endpoints, {total_errs} combined 5xx errors\n\n")

        f.write("\nALL UNLOGGED ENDPOINTS (no 5xx data match)\n")
        f.write(f"{'Line':>6}  {'Method':<50}  Paths\n")
        f.write('-' * 130 + "\n")
        matched_keys = {(r['filepath'], r['method']) for r in matched_unlogged}
        for m in all_unlogged:
            if (m['filepath'], m['method']) in matched_keys: continue
            short = re.sub(r'.*/java/', '', m['filepath'])
            paths_str = ', '.join(m['full_paths'][:3])
            f.write(f"{m['line']:>6}  {m['method']:<50}  {paths_str}\n")
            f.write(f"{'':>6}  {short}\n\n")

        f.write(f"\nUnmatched nginx 5xx URIs (top 30, no Java mapping found):\n")
        for c, u in sorted(unmatched, key=lambda x: -x[0])[:30]:
            f.write(f"  {c:>8}  {u}\n")

    # Print priority table to stdout
    print(f"\n{'5xx Errors':>10}  {'Method':<50}  URL Template")
    print('-' * 110)
    for r in matched_unlogged:
        print(f"{r['count']:>10}  {r['method']:<50}  {r['template']}")
    print(f"\n--- SUMMARY ---")
    print(f"Total endpoints  : {total}")
    print(f"Logged           : {n_logged} ({pct:.1f}%)")
    print(f"Unlogged         : {n_unlogged} ({100-pct:.1f}%)")
    print(f"With 5xx errors  : {len(matched_unlogged)} endpoints, {total_errs} errors")
    print(f"\nReport: {out_file}")

if __name__ == '__main__':
    main()
