import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.exporters.*;
import com.jpexs.decompiler.flash.exporters.modes.*;
import com.jpexs.decompiler.flash.exporters.settings.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
// #region Read-only original HUD registration and monster appearance frames
class ExportOriginalEntranceUI {
 static SWF swf;
 static void inspect(int id, String indent) throws Exception {
  CharacterTag c = swf.getCharacter(id);
  System.out.println(indent + id + " " + c.getClass().getSimpleName() + " " + ((BoundedTag)c).getRectWithStrokes());
  if(c instanceof DefineEditTextTag) {
   for(java.lang.reflect.Field f:c.getClass().getFields()) {
    if(Arrays.asList("fontId","fontHeight","textColor","initialText","bounds","fontClass","align").contains(f.getName()))
     System.out.println(indent+"  "+f.getName()+"="+f.get(c));
   }
  }
  if(c instanceof DefineSpriteTag) for(DepthState d:((DefineSpriteTag)c).getTimeline().getFrame(0).layers.values()) {
   System.out.println(indent+" depth="+d.depth+" name="+d.instanceName+" matrix="+d.matrix);
   inspect(d.characterId, indent+"  ");
  }
 }
 public static void main(String[] args) throws Exception {
  swf = new SWF(new FileInputStream(args[0]), false);
  swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
  Path output = Path.of(args[1]); Files.createDirectories(output);
  if(args.length > 2) {
   SWF fonts = new SWF(new FileInputStream(args[2]),false);
   for(CharacterTag c:fonts.getCharacters().values()) if(c instanceof FontTag) {
    FontTag font=(FontTag)c;
    System.out.println("external font "+font.getFontName()+" glyphs="+font.getCharacterCount());
    if(font.containsChar('\u7389') && font.containsChar('\u7435') && font.containsChar('\u7cbe'))
     new FontExporter().exportFont(font,FontExportMode.TTF,output.resolve("boss-name.ttf").toFile());
   }
  }
  for(int id:new int[]{55,1333}) {
   FontTag font = (FontTag)swf.getCharacter(id);
   System.out.println("font "+id+" name="+font.getFontName()+" glyphs="+font.getCharacterCount()+" boss_supported="+font.getCharacters().contains("玉"));
   new FontExporter().exportFont(font,FontExportMode.TTF,output.resolve("font-"+id+".ttf").toFile());
  }
  AbortRetryIgnoreHandler h=new AbortRetryIgnoreHandler(){public int handle(Throwable e){throw new RuntimeException(e);}public AbortRetryIgnoreHandler getNewInstance(){return this;}};
  for(int id:new int[]{1326,1327,1330}) new ShapeExporter().exportShapes(h,output.resolve("protect-shapes").toString(),swf,new ReadOnlyTagList(Arrays.asList(swf.getCharacter(id))),new ShapeExportSettings(ShapeExportMode.PNG,1.0),null,1.0);
  for(CharacterTag c:swf.getCharacters().values()) for(String name:c.getClassNames()) {
   if(name.equals("boosBleedBar")) inspect(c.getCharacterId(), "");
   if(name.matches("appear\\d+")) {
    DefineSpriteTag sprite = (DefineSpriteTag)c;
    System.out.println(name+" id="+c.getCharacterId()+" frames="+sprite.frameCount+" bounds="+sprite.getRectWithStrokes());
    List<Integer> frames = new ArrayList<>();
    for(int i=0;i<sprite.frameCount;i++) frames.add(i);
    new FrameExporter().exportFrames(h, output.resolve(name).toString(),swf,c.getCharacterId(),frames,new FrameExportSettings(FrameExportMode.PNG,1.0),null);
    List<Path> images;
    try(var stream=Files.walk(output.resolve(name))) { images=stream.filter(p->p.toString().endsWith(".png")).sorted(Comparator.comparingInt(p->Integer.parseInt(p.getFileName().toString().replace(".png","")))).toList(); }
    BufferedImage first=ImageIO.read(images.get(0).toFile());
    int cellW=first.getWidth()+4,cellH=first.getHeight()+4;
    BufferedImage atlas=new BufferedImage(cellW*5,cellH*((images.size()+4)/5),BufferedImage.TYPE_INT_ARGB);
    var graphics=atlas.createGraphics();
    for(int i=0;i<images.size();i++) graphics.drawImage(ImageIO.read(images.get(i).toFile()),i%5*cellW+2,i/5*cellH+2,null);
    graphics.dispose(); ImageIO.write(atlas,"PNG",output.resolve(name+"-atlas.png").toFile());
   }
  }
 }
}
// #endregion
