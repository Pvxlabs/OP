"""Local signing with a single existing identity. Never exports keys or provisions accounts."""
import os, pathlib, re, subprocess, sys, plistlib
app = pathlib.Path(sys.argv[1]).resolve()
identity = os.environ.get('OP_CEF_SIGN_IDENTITY')
if not identity:
    identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    found = re.search(r'([A-F0-9]{40}) "(?:Apple Development|Developer ID Application):', identities)
    if not found:
        sys.exit('No existing signing identity. Hardened local CEF requires consistent identity; ad-hoc library-validation bypass is not used.')
    identity = found.group(1)
framework = app/'Contents/Frameworks/Chromium Embedded Framework.framework'
entitlements = app.parent/'entitlements'; entitlements.mkdir(exist_ok=True)
for name, values in [('jit', {'com.apple.security.cs.allow-jit': True}), ('empty', {})]:
    (entitlements/(name+'.plist')).write_bytes(plistlib.dumps(values))
def sign(path, runtime=False, jit=False):
    args = ['codesign','--force','--sign',identity]
    if runtime: args += ['--options','runtime','--entitlements',str(entitlements/('jit.plist' if jit else 'empty.plist'))]
    subprocess.run(args+[str(path)], check=True)
for lib in (framework/'Versions/A/Libraries').rglob('*'):
    if lib.is_file() and 'Mach-O' in subprocess.check_output(['file','-b',str(lib)], text=True): sign(lib)
sign(framework)
sign(app/'Contents/Frameworks/libOPNative.dylib', True)
for helper in (app/'Contents/Frameworks').glob('OPCEFIntegration Helper*.app'):
    sign(helper, True, '(Renderer)' in helper.name or '(GPU)' in helper.name)
sign(app, True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)], check=True)
