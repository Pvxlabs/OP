"""Versioned framework staging. Idempotent on repeated Xcode builds (unlike ln -sf on directory links)."""
import pathlib, shutil, sys, os
source, destination = map(pathlib.Path, sys.argv[1:])
version = destination/'Versions/A'; version.mkdir(parents=True, exist_ok=True)
# Remove only self-links created by the prior CEF sample copy macro in this build output.
for rel in ['A','Libraries/Libraries','Resources/Resources']:
    link = version/rel
    if link.is_symlink(): link.unlink()
shutil.copytree(source, version, dirs_exist_ok=True, symlinks=True)
for rel, target in [('Chromium Embedded Framework','Versions/A/Chromium Embedded Framework'),('Libraries','Versions/A/Libraries'),('Resources','Versions/A/Resources'),('Versions/Current','A')]:
    link = destination/rel
    if link.is_symlink(): link.unlink()
    if link.exists(): raise SystemExit('Refusing to replace unexpected staging path: '+str(link))
    link.symlink_to(target)
