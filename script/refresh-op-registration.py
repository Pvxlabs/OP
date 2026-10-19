#!/usr/bin/env python3
"""Refresh the installed OP registration without removing apps or resetting LaunchServices."""
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess

installed = pathlib.Path('/Applications/OP.app')
info = installed / 'Contents/Info.plist'
identity = plistlib.loads(info.read_bytes())['CFBundleIdentifier']
if identity != 'local.personal.OP.CEFIntegration':
    raise SystemExit('Expected the CEF-backed OP installation at /Applications/OP.app')
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
register = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
roots = [pathlib.Path.home() / 'Library/Application Support/OP/Backups',
         pathlib.Path(__file__).resolve().parents[1] / 'build']
dump = subprocess.check_output([register, '-dump'], text=True)
preserved = {}
removed = 0
for record in re.split(r'\n-{20,}\n', dump):
    match = re.search(r'^identifier:\s+(local\.personal\.(?:OP\.CEFIntegration|ChatGPTNative))\s*$', record, re.M)
    path = re.search(r'^path:\s+(.*?)\s+\(0x[0-9a-f]+\)$', record, re.M)
    if not match or not path:
        continue
    bundle = pathlib.Path(path[1])
    if bundle == installed or not any(bundle.is_relative_to(root) for root in roots):
        continue
    metadata = bundle / 'Contents/Info.plist'
    if metadata.exists():
        preserved[metadata] = hashlib.sha256(metadata.read_bytes()).digest()
    subprocess.run([register, '-u', str(bundle)], check=True)
    removed += 1
subprocess.run([register, '-f', str(installed)], check=True)
subprocess.run(['mdimport', str(installed)], check=True)
if not all(hashlib.sha256(path.read_bytes()).digest() == digest for path, digest in preserved.items()):
    raise SystemExit('Unexpected backup metadata change')
print(json.dumps({'status': 'PASS', 'installed': str(installed), 'identifier': identity,
                  'unregisteredCopies': removed, 'backupMetadataPreserved': len(preserved)}, indent=2))
