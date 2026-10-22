#!/usr/bin/env python3
"""Read-only update preview. checkupdates uses a separate pacman database."""
import configparser
import concurrent.futures
import json
import shutil
import subprocess


def query(source, command):
    if not shutil.which(command[0]):
        return [], f'{source}: {command[0]} was not found.'
    try:
        proc = subprocess.run(command, capture_output=True, text=True, timeout=90)
    except (OSError, subprocess.TimeoutExpired) as error:
        return [], f'{source}: {error}'
    # Query mode follows pacman's convention: exit 1 with no output means
    # there are no matching upgrades. Do not hide errors that include diagnostics.
    if source == 'AUR' and proc.returncode == 1 and not proc.stdout.strip() and not proc.stderr.strip():
        return [], ''
    if proc.returncode not in (0, 2) or (source == 'AUR' and proc.returncode != 0):
        return [], f'{source}: {(proc.stderr or proc.stdout).strip()[:1200] or "Unable to query updates"}'
    rows = []
    for line in proc.stdout.splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[2] == '->':
            rows.append(dict(name=parts[0], current=parts[1], new=parts[3], source=source))
    return rows, ''


def add_icons(packages):
    """Map each package to its own installed desktop launcher, once per query."""
    if not packages:
        return
    try:
        listing = subprocess.run(['pacman', '-Ql', *[p['name'] for p in packages]],
                                 capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return
    icons = {}
    for line in listing.stdout.splitlines():
        fields = line.split(' ', 1)
        if len(fields) != 2:
            continue
        package, filename = fields
        if '/applications/' not in filename or not filename.endswith('.desktop'):
            continue
        try:
            desktop = configparser.ConfigParser(interpolation=None, strict=False)
            desktop.read(filename, encoding='utf-8')
            entry = desktop['Desktop Entry']
            if entry.get('NoDisplay', 'false').lower() == 'true' or entry.get('Hidden', 'false').lower() == 'true':
                continue
            icon = entry.get('Icon', '').strip()
            if icon:
                icons.setdefault(package, icon)
        except (OSError, UnicodeError, configparser.Error, KeyError):
            continue
    for package in packages:
        package['icon'] = icons.get(package['name'], 'package-x-generic')


def main():
    helper = next((app for app in ('paru', 'yay') if shutil.which(app)), None)
    tasks = [('Repository', ['checkupdates', '--nocolor'])]
    if helper:
        tasks.append(('AUR', [helper, '-Qua', '--color', 'never']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda args: query(*args), tasks))
    packages = sorted([row for rows, _ in results for row in rows], key=lambda row: row['name'])
    add_icons(packages)
    print(json.dumps(dict(packages=packages,
                         errors=[error for _, error in results if error], helper=helper or 'pacman'), ensure_ascii=False))


if __name__ == '__main__':
    main()
