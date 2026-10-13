"""Build three fixed-size Boss skill cards using the original ZMX5 UI silhouette.

This is deterministic UI asset composition: shared original template, supplied
portrait and project font. No animation or gameplay resources are overwritten.
"""
from pathlib import Path
import json, hashlib, shutil, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/ui/boss/mihouwang'

def author(portrait=None, template=None):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if portrait: shutil.copyfile(portrait, OUTPUT/'portrait.png')
    if template: shutil.copyfile(template, OUTPUT/'template.png')
    base=Image.open(OUTPUT/'template.png').convert('RGBA')
    icon=Image.open(OUTPUT/'portrait.png').convert('RGBA')
    icon=icon.crop(icon.getbbox())
    width,height=base.size
    # The visible frame is shorter than its transparent texture canvas.
    # Keep the complete portrait inside both frame lines, with a 3px inset.
    portrait_box=(27,9,106,height-13)
    left,top,right,bottom=portrait_box
    face=ImageOps.contain(icon,(right-left,bottom-top),Image.Resampling.LANCZOS)
    portrait_layer=Image.new('RGBA',base.size)
    portrait_layer.alpha_composite(face,(left+(right-left-face.width)//2,
                                        top+(bottom-top-face.height)//2))
    # Also retain the original slanted silhouette if the template is changed.
    portrait_layer.putalpha(ImageChops.multiply(portrait_layer.getchannel('A'),base.getchannel('A')))
    font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/huakang_haibao_w12.ttf'),31)
    for index,title in enumerate(['狂风出击','疾风突袭','飓风强袭'],1):
        # Keep the original transparent brush silhouette and slanted frame.
        card=Image.new('RGBA',base.size)
        pixels=card.load(); source=base.load()
        for y in range(height):
            for x in range(width):
                alpha=source[x,y][3]
                light=max(0,1-abs(y-height*.52)/(height*.3))*max(0,1-abs(x-width*.55)/(width*.48))
                pixels[x,y]=(int(3+light*8),int(9+light*76),int(15+light*110),alpha)
        draw=ImageDraw.Draw(card)
        draw.line([(15,6),(width-10,6)],fill=(96,208,252,120),width=1)
        draw.line([(12,height-10),(width-17,height-10)],fill=(158,114,242,180),width=1)
        # Preserve the ZMX5 left cloud ornament under the new supplied portrait.
        ornament=base.crop((0,0,36,height))
        card.alpha_composite(ornament,(0,0))
        card.alpha_composite(portrait_layer)
        box=draw.textbbox((0,0),title,font=font,stroke_width=0)
        text_width=box[2]-box[0]; x=124; y=(height-(box[3]-box[1]))//2-box[1]-1
        if text_width>width-x-20:
            font_size=round(31*(width-x-20)/text_width)
            use_font=ImageFont.truetype(str(ROOT/'assets/ui/fonts/huakang_haibao_w12.ttf'),font_size)
        else: use_font=font
        glow=Image.new('RGBA',base.size); gd=ImageDraw.Draw(glow)
        gd.text((x,y),title,font=use_font,fill=(81,237,255),stroke_width=4,stroke_fill=(31,127,197,200))
        card.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2)))
        draw=ImageDraw.Draw(card)
        draw.text((x+1,y+2),title,font=use_font,fill=(24,68,113),stroke_width=2,stroke_fill=(2,8,24))
        draw.text((x,y),title,font=use_font,fill=(220,253,255),stroke_width=1,stroke_fill=(23,51,97))
        card.save(OUTPUT/f'skill{index}.png')
    data={'titles':['狂风出击','疾风突袭','飓风强袭'],'size':[width,height],
          'portrait_box':list(portrait_box),
          'template':'造梦西游5 icon/skill/dialog/2002010.png',
          'portrait_sha256':hashlib.sha256((OUTPUT/'portrait.png').read_bytes()).hexdigest(),
          'template_sha256':hashlib.sha256((OUTPUT/'template.png').read_bytes()).hexdigest(),
          'font':'res://assets/ui/fonts/huakang_haibao_w12.ttf'}
    (OUTPUT/'source.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'Authored three {width}x{height} original-template cut-ins')

if __name__=='__main__':author(*(sys.argv[1:3]))
