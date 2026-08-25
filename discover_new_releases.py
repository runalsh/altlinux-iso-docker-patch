#!/usr/bin/env python3
"""
Discovers available ALT Linux Server ISO images from official ALT Linux mirrors.
"""
import re
import urllib.request
import os

MIRRORS = [
    "https://ftp.altlinux.org/pub/distributions/ALTLinux/",
    "https://mirror.yandex.ru/altlinux/",
]

BRANCHES = ["p11", "p10", "p12"]

def fetch_releases():
    releases = {}
    iso_pattern = re.compile(r'href=["\']?(alt-server-([0-9]+\.[0-9]+(?:\.[0-9]+)?)-x86_64\.iso)["\']?')

    for branch in BRANCHES:
        for mirror in MIRRORS:
            url = f"{mirror}{branch}/images/server/x86_64/"
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    html = resp.read().decode('utf-8', errors='ignore')
                    matches = iso_pattern.findall(html)
                    for filename, version in matches:
                        full_iso_url = f"{url}{filename}"
                        if version not in releases:
                            releases[version] = full_iso_url
                break
            except Exception as e:
                continue

    return releases

def main():
    releases_file = "releases.txt"
    existing = {}
    if os.path.exists(releases_file):
        with open(releases_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split(maxsplit=1)
                    if len(parts) == 2:
                        existing[parts[0]] = parts[1]

    discovered = fetch_releases()
    for v, url in discovered.items():
        if v not in existing:
            existing[v] = url

    # Sort versions
    def version_key(v):
        try:
            return [int(x) for x in v.split('.')]
        except Exception:
            return [0]

    sorted_versions = sorted(existing.keys(), key=version_key, reverse=True)

    with open(releases_file, "w") as f:
        for v in sorted_versions:
            f.write(f"{v} {existing[v]}\n")

    print(f"Updated {releases_file} with {len(sorted_versions)} releases.")

if __name__ == "__main__":
    main()
