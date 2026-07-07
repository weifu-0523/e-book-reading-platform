#!/usr/bin/env python3
"""M4.6-fix21 investigation: parse zhiyue_pdf.log into per-attempt outcome table."""
import sys, re
from datetime import datetime

log = open(sys.argv[1], encoding='utf-8', errors='replace').read().splitlines()
events = []
for ln in log:
    m = re.match(r'(\S+) \[PDF-DIAG\] (.*)', ln)
    if not m:
        continue
    ts = datetime.fromisoformat(m.group(1)).timestamp()
    msg = m.group(2)
    if msg.startswith('=== openFile start:'):
        f = msg.split('openFile start: ', 1)[1].rsplit(' ===', 1)[0]
        events.append((ts, 'START', f))
    elif msg.startswith('openFile success'):
        events.append((ts, 'SUCCESS', ''))
    elif msg.startswith('openFile TIMEOUT'):
        events.append((ts, 'TIMEOUT', ''))
    elif msg.startswith('openFile ERROR'):
        events.append((ts, 'ERROR', ''))

i = 0; n = 0; attempts = []
while i < len(events):
    if events[i][1] == 'START':
        n += 1; j = i + 1; outcome = None; gap = None
        while j < len(events):
            if events[j][1] in ('SUCCESS', 'TIMEOUT', 'ERROR'):
                gap = events[j][0] - events[i][0]; outcome = events[j][1]; break
            if events[j][1] == 'START':
                gap = events[j][0] - events[i][0]; outcome = 'ABANDONED'; break
            j += 1
        if outcome is None:
            gap = 'EOF'; outcome = 'NO_TERMINAL'
        attempts.append((n, gap, outcome, events[i][2])); i = j
    else:
        i += 1

print('%2s  %11s  %-10s  file' % ('#', 'start->next', 'outcome'))
for n, gap, outcome, f in attempts:
    gs = '%.1fs' % gap if isinstance(gap, float) else str(gap)
    fn = re.sub(r'[0-9a-f]{40}', '<hash>', f)
    fn = fn.replace('\\', '/').split('/')[-1]
    flag = '  <-- STUCK' if (isinstance(gap, float) and gap > 3.0 and outcome != 'SUCCESS') else ''
    print('%2d  %11s  %-10s  %s%s' % (n, gs, outcome, fn, flag))

succ = [a for a in attempts if a[2] == 'SUCCESS']
stuck = [a for a in attempts if isinstance(a[1], float) and a[1] > 3.0 and a[2] != 'SUCCESS']
print('\nTOTAL: %d  SUCCESS: %d  STUCK(>3s,abandoned): %d' % (len(attempts), len(succ), len(stuck)))
print('Stuck gaps: %s' % ['%.0fs' % a[1] for a in stuck])
print('Success rate: %.1f%%' % (100.0 * len(succ) / len(attempts)))
