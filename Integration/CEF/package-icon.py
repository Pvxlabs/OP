"""Package the existing OP icon assets without redesigning them."""
import pathlib, shutil, subprocess, sys
source, output = map(pathlib.Path, sys.argv[1:])
iconset = output.parent/'OP.iconset'; iconset.mkdir(exist_ok=True)
for size in [16,32,128,256,512]:
    shutil.copy2(source/f'icon_{size}.png',iconset/f'icon_{size}x{size}.png')
    shutil.copy2(source/f'icon_{size*2}.png',iconset/f'icon_{size}x{size}@2x.png')
subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(output)],check=True)
