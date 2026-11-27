"""Read existing Phase 15.9G samples; no ADB calls or device mutations."""
import argparse
import csv
import json
import re
from datetime import datetime
from pathlib import Path


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def number(text, pattern):
    match = re.search(pattern, text, re.MULTILINE)
    return int(match.group(1)) if match else None


def mib(value):
    return None if value is None else round(value / 1024, 2)


def load(folder):
    meta = json.loads(read(folder / 'metadata.json'))
    mem, gfx, battery = (read(folder / (name + '.txt')) for name in ('memory', 'graphics', 'battery'))
    pid = number(read(folder / 'process.txt'), r'^\s*(\d+)\s*$')
    mem_pid = number(mem, r'MEMINFO in pid\s+(\d+)')
    gfx_pid = number(gfx, r'Graphics info for pid\s+(\d+)')
    if pid is None or pid != mem_pid or pid != gfx_pid:
        raise ValueError('missing or inconsistent process ID')
    pss = number(mem, r'^\s*TOTAL PSS:\s*(\d+)')
    if pss is None:
        raise ValueError('TOTAL PSS not available')
    return dict(folder=folder.name, timestamp=meta['timestamp'], stage=meta['stage'],
                package=meta['package'], device=meta.get('device') or '', pid=pid,
                pss_mib=mib(pss), rss_mib=mib(number(mem, r'TOTAL RSS:\s*(\d+)')),
                graphics_mib=mib(number(mem, r'^\s*Graphics:\s*(\d+)')),
                native_mib=mib(number(mem, r'^\s*Native Heap:\s*(\d+)')),
                battery_percent=number(battery, r'^\s*level:\s*(\d+)'),
                temperature_c=(lambda x: None if x is None else x / 10)(number(battery, r'^\s*temperature:\s*(-?\d+)')),
                charge_counter_uah=number(battery, r'^\s*Charge counter:\s*(-?\d+)'),
                charging_status=number(battery, r'^\s*status:\s*(\d+)'),
                gfx_epoch=number(gfx, r'^Stats since:\s*(\d+)'),
                frames=number(gfx, r'^Total frames rendered:\s*(\d+)'),
                janky=number(gfx, r'^Janky frames:\s*(\d+)'))


def compare(start, end):
    seconds = (datetime.fromisoformat(end['timestamp']) - datetime.fromisoformat(start['timestamp'])).total_seconds()
    if seconds < 0 or start['package'] != end['package'] or start['device'] != end['device']:
        raise ValueError('different package/device or invalid time range')
    result = {'elapsed_seconds': seconds, 'pss_delta_mib': round(end['pss_mib'] - start['pss_mib'], 2)}
    for key in ('graphics_mib', 'native_mib', 'battery_percent', 'temperature_c', 'charge_counter_uah'):
        if start[key] is not None and end[key] is not None:
            result[key + '_delta'] = round(end[key] - start[key], 2)
    result['same_reported_pid'] = start['pid'] == end['pid']
    result['battery_discharge_comparable'] = (seconds >= 1800 and start['charging_status'] == end['charging_status'] == 3)
    result['note'] = 'Endpoint samples only; intervening charging, process restarts or workload differences cannot be excluded.'
    if (result['same_reported_pid'] and start['gfx_epoch'] is not None and start['gfx_epoch'] == end['gfx_epoch']
            and all(x[k] is not None for x in (start, end) for k in ('frames', 'janky'))):
        frames = end['frames'] - start['frames']
        jank = end['janky'] - start['janky']
        if frames >= 0 and 0 <= jank <= frames:
            result['gfxinfo_frame_delta'] = frames
            result['gfxinfo_jank_delta'] = jank
            result['gfxinfo_jank_percent'] = round(100 * jank / frames, 2) if frames else None
    if not result['battery_discharge_comparable']:
        result['battery_warning'] = 'Less than 30 minutes or endpoints not both discharging; do not estimate battery efficiency.'
    if not result['same_reported_pid']:
        result['memory_warning'] = 'Process changed; memory delta is not a continuous-process trend.'
    if not start['device']:
        result['device_warning'] = 'Device serial absent in metadata; confirm both samples came from the same device.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='Directory containing extracted start/sample/end folders')
    parser.add_argument('--output', type=Path, default=Path('build/phase15_9h'))
    args = parser.parse_args()
    samples, skipped = [], []
    for folder in sorted(args.directory.iterdir()):
        if not folder.is_dir():
            continue
        try:
            samples.append(load(folder))
        except (OSError, ValueError, KeyError) as error:
            skipped.append({'folder': folder.name, 'reason': str(error)})
    samples.sort(key=lambda x: datetime.fromisoformat(x['timestamp']))
    if not samples:
        parser.error('No complete diagnostic samples found')
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / 'samples.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=list(samples[0]))
        writer.writeheader()
        writer.writerows(samples)
    # Pair each end with the latest preceding start; never silently combine sessions.
    sessions = []
    starts = {}
    for sample in samples:
        key = (sample['package'], sample['device'])
        if sample['stage'] == 'start':
            starts[key] = sample
        elif sample['stage'] == 'end' and key in starts:
            start = starts.pop(key)
            sessions.append(dict(start=start['folder'], end=sample['folder'], **compare(start, sample)))
    report = dict(complete_samples=len(samples), skipped=skipped, sessions=sessions,
                  caution='gfxinfo is not a complete Flutter SurfaceView frame measure; PSS graphics includes OS-managed buffers.')
    (args.output / 'summary.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
