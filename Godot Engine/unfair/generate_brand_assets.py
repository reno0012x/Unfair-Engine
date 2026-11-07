"""Build deterministic native Unfair brand assets; preserve original files once.

The AI-generated concept is retained separately. This script draws the clean
production vector design from geometry, rather than editing that concept image.
Run with Python + Pillow from any working directory.
"""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "unfair/branding"
BACKUP = ROOT / "unfair/original-assets"
OUT.mkdir(parents=True, exist_ok=True)
POLYGON = [(19.8,17.5),(48,34.4),(48,80.3),(56.5,86.6),(68.8,86.6),
           (77.4,80.3),(77.4,34.4),(105.7,17.5),(105.7,90.1),
           (83.5,108.3),(41.6,108.3),(19.8,90),(19.8,69.4),(38.3,58),(19.8,47.9)]
# Faithfully retain the reference's triangular cut and long diagonal slash.
CUTS = [[(81.4,68.7),(97.4,58.1),(97.4,77.3)],
        [(49.1,108.3),(97.4,77.3),(97.4,82.2),(56.8,108.3)]]
GLYPHS = {
    'U': [[(0, 0), (0, 28), (8, 34), (16, 28), (16, 0)]],
    'N': [[(0, 34), (0, 0), (18, 34), (18, 0)]],
    'F': [[(0, 34), (0, 0), (18, 0)], [(0, 16), (14, 16)]],
    'A': [[(0, 34), (9, 0), (18, 34)], [(4, 22), (14, 22)]],
    'I': [[(9, 0), (9, 34)]],
    'R': [[(0, 34), (0, 0), (15, 0), (19, 5), (19, 12),
           (15, 17), (0, 17)], [(10, 17), (20, 34)]],
}

def preserve(path):
    if path.is_relative_to(OUT):
        return
    if path.exists():
        dest = BACKUP / path.relative_to(ROOT)
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)

def save(path, data):
    preserve(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data, encoding="utf-8")
    else:
        if path.suffix == '.webp':
            data.save(path, lossless=True)
        else:
            data.save(path)

def symbol(size, tile=False):
    scale = size * 4 / 128
    im = Image.new('RGBA', (size * 4, size * 4), (14, 14, 14, 255) if tile else (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    draw.polygon([(x*scale, y*scale) for x,y in POLYGON], fill='white')
    for cut in CUTS:
        draw.polygon([(x*scale, y*scale) for x,y in cut], fill=(14,14,14,255) if tile else (0,0,0,0))
    return im.resize((size, size), Image.Resampling.LANCZOS)

def svg_symbol(size=128, document=False):
    points = ' '.join(f'{x},{y}' for x,y in POLYGON)
    # One compound path uses evenodd so the diagonal notch is transparent.
    def path(poly): return 'M'+' L'.join(f'{x} {y}' for x,y in poly)+' Z'
    mark = '<path fill="#fff" fill-rule="evenodd" d="'+path(POLYGON)+' '+' '.join(path(c) for c in CUTS)+'"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 128 128">{mark}</svg>\n'

def wordmark():
    width, height = 512, 160
    im = Image.new('RGBA', (width*4,height*4))
    im.paste(symbol(140*4), (0,10*4))
    d = ImageDraw.Draw(im)
    font_path = ROOT/'thirdparty/fonts/Inter_Bold.woff2'
    face = ImageFont.truetype(str(font_path),74*4)
    x = 155.0
    for char in 'UNFAIR':
        d.text((x*4,104*4),char,font=face,fill='white',anchor='ls')
        x += face.getlength(char)/4+4
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="160" viewBox="0 0 512 160">'
    svg += f'<g transform="translate(0 10) scale({140/128})">'+svg_symbol().split('>',1)[1].rsplit('</svg>',1)[0]+'</g>'
    font = TTFont(font_path)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = 74/font['head'].unitsPerEm
    x = 155.0
    for char in 'UNFAIR':
        glyph = cmap[ord(char)]
        pen = SVGPathPen(glyphs)
        glyphs[glyph].draw(TransformPen(pen,(scale,0,0,-scale,x,104)))
        svg += '<path fill="#fff" d="'+pen.getCommands()+'"/>'
        x += font['hmtx'][glyph][0]*scale+4
    return im.resize((width,height),Image.Resampling.LANCZOS), svg+'</svg>\n'

icon = symbol(256)
logo, logo_svg = wordmark()
save(OUT/'unfair-symbol-white.svg', svg_symbol())
save(OUT/'unfair-symbol-white.png', icon)
save(OUT/'unfair-wordmark-white.svg', logo_svg)
save(OUT/'unfair-wordmark-white.png', logo)
save(ROOT/'editor/icons/UnfairBrand.svg', svg_symbol(40).replace('viewBox="0 0 128 128"', 'viewBox="17 15 92 96"'))
for rel in ['editor/icons/Godot.svg','editor/icons/GodotMonochrome.svg',
            'editor/icons/TitleBarLogo.svg',
            'misc/logo/icon.svg','misc/logo/icon_outlined.svg',
            'misc/dist/windows/icon_console.svg']:
    save(ROOT/rel, svg_symbol(16 if rel.startswith('editor') else 256))
for rel in ['misc/logo/logo.svg','misc/logo/logo_outlined.svg']:
    save(ROOT/rel, logo_svg)
save(ROOT/'editor/icons/Logo.svg', logo_svg.replace('width="512" height="160"', 'width="187" height="69"'))
save(ROOT/'misc/dist/html/logo.svg', logo_svg)
save(ROOT/'editor/icons/DefaultProjectIcon.svg', svg_symbol(128).replace('<path ', '<rect width="128" height="128" rx="20" fill="#0e0e0e"/><path ', 1))
doc_mark = svg_symbol(64).split('>',1)[1].rsplit('</svg>',1)[0]
save(ROOT/'editor/icons/GodotFile.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M12 5H37L52 20V59H12Z M37 5V20H52" fill="none" stroke="#fff" stroke-width="2"/><g transform="translate(12 20) scale(.31)">'+doc_mark+'</g></svg>\n')
for rel in ['main/app_icon.png','misc/logo/icon.png']:
    save(ROOT/rel, symbol(128 if rel.startswith('main') else 256, tile=True))
for rel in ['misc/logo/logo.png','misc/logo/logo_outlined.png']:
    save(ROOT/rel, logo)
save(ROOT/'misc/logo/icon_outlined.png', icon)
for rel in ['main/splash.png','main/splash_editor.png']:
    splash = Image.new('RGBA',(800,600),(14,14,14,255))
    splash.alpha_composite(logo, (144,220))
    if rel == 'main/splash_editor.png':
        credit_font = ImageFont.truetype(str(ROOT/'thirdparty/fonts/Inter_Regular.woff2'),16)
        ImageDraw.Draw(splash).text((400,422),'Forked from Godot Engine',font=credit_font,
                                    fill=(174,174,174,255),anchor='mm')
    save(ROOT/rel,splash)
for rel in ['platform/windows/godot.ico','platform/windows/godot_console.ico']:
    path = ROOT/rel
    preserve(path)
    symbol(256, tile=True).save(path, format='ICO', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
for rel in ['misc/dist/macos_tools.app/Contents/Resources/GodotLG.icns',
            'misc/dist/macos_template.app/Contents/Resources/icon.icns']:
    path = ROOT/rel
    preserve(path)
    symbol(1024,tile=True).save(path,format='ICNS')
for path in (ROOT/'platform/android/java/lib/src/main/res').glob('mipmap*/icon*.webp'):
    size = Image.open(path).size
    if 'background' in path.name:
        image = Image.new('RGBA',size,(14,14,14,255))
    else:
        image = Image.new('RGBA',size)
        mark = symbol(round(min(size)*.66),tile=path.name == 'icon.webp')
        image.alpha_composite(mark,((size[0]-mark.width)//2,(size[1]-mark.height)//2))
    save(path,image)
for rel in ['platform/android/java/lib/src/main/res/drawable/splash_icon.webp',
            'platform/android/java/lib/src/main/res/drawable/splash_branding_image.webp',
            'platform/android/java/editor/src/picoos/assets/vr_splash.png',
            'platform/android/java/editor/src/horizonos/assets/vr_splash.png',
            'misc/dist/apple_embedded_xcode/godot_apple_embedded/Images.xcassets/SplashImage.imageset/splash@2x.png',
            'misc/dist/apple_embedded_xcode/godot_apple_embedded/Images.xcassets/SplashImage.imageset/splash@3x.png']:
    path = ROOT/rel
    if not path.exists(): continue
    size = Image.open(path).size
    image = Image.new('RGBA',size,(0,0,0,0))
    mark = logo.copy() if 'branding' in rel or size[0] > size[1]*1.4 else symbol(256)
    mark.thumbnail((max(1,round(size[0]*.72)),max(1,round(size[1]*.72))), Image.Resampling.LANCZOS)
    image.alpha_composite(mark,((size[0]-mark.width)//2,(size[1]-mark.height)//2))
    save(path,image)
for path in (ROOT/'misc/dist/macos/GodotLG.icon/Assets').glob('layer_*.svg'):
    save(path, '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 128 128">'+ ('<rect width="128" height="128" fill="#0e0e0e"/>' if path.stem == 'layer_0' else (svg_symbol().split('>',1)[1].rsplit('</svg>',1)[0] if path.stem == 'layer_1' else ''))+'</svg>\n')
(OUT/'asset-provenance.json').write_text(json.dumps({
    'brand':'Unfair', 'concept':'unfair-ai-refined-v2.png',
    'generation':'Built-in image_gen refinement of user reference 5; transparent white angular U',
    'production':'Reference-faithful geometric U with triangular notch and long diagonal slit; Inter Bold wordmark outlines',
    'font_license':'thirdparty/fonts/LICENSE.Inter.txt',
    'regenerate':'python unfair/generate_brand_assets.py (Pillow, fontTools, Brotli required)',
    'originals':'unfair/original-assets; Godot legal notices retained',
},indent=2),encoding='utf-8')
print('Generated Unfair vectors, splash screens, PNG, Windows ICO and macOS ICNS assets.')
