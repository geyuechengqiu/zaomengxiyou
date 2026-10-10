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
import javax.imageio.ImageIO;
// #region Read-only SWF symbol discovery, registration and exact source frames
class ExportOriginalBattleUI {
 static SWF swf;
 static Set<Integer> visited = new HashSet<>();
 static void inspect(int id, String indent, int level) throws Exception {
  CharacterTag c=swf.getCharacter(id);
  System.out.println(indent+"id="+id+" type="+c.getClass().getSimpleName()+" bounds="+(c instanceof BoundedTag ? ((BoundedTag)c).getRectWithStrokes() : "none"));
  if(c instanceof DefineEditTextTag) {
   for(java.lang.reflect.Field f:c.getClass().getFields()) if(Arrays.asList("fontId","fontHeight","initialText","textColor").contains(f.getName())) System.out.println(indent+"  "+f.getName()+"="+f.get(c));
  }
  if(level>0 && c instanceof DefineSpriteTag && visited.add(id)) {
   DefineSpriteTag sprite=(DefineSpriteTag)c;
   System.out.println(indent+"frames="+sprite.frameCount);
   int labelFrame=0;
   for(Tag tag:sprite.getTags()) {
    if(tag instanceof FrameLabelTag) System.out.println(indent+"LABEL "+((FrameLabelTag)tag).name+"="+labelFrame);
    if(tag instanceof ShowFrameTag) labelFrame++;
   }
   for(int f=0;f<Math.min(sprite.frameCount,2);f++) {
   System.out.println(indent+"FRAME "+f);
   for(DepthState d:sprite.getTimeline().getFrame(f).layers.values()) {
    if(d.characterId<=0) continue;
    System.out.println(indent+" depth="+d.depth+" name="+d.instanceName+" matrix="+d.matrix+" clip="+d.clipDepth);
    inspect(d.characterId,indent+"  ",level-1);
   }
   }
  }
 }
 public static void main(String[] args) throws Exception {
  swf=new SWF(new FileInputStream(args[0]),false);
  swf.assignClassesToSymbols();swf.assignExportNamesToSymbols();
  String requested=args.length>2?args[2]:"";
  if(requested.equals("fonts")) {
   Files.createDirectories(Path.of(args[1]));
   for(CharacterTag c:swf.getCharacters().values()) if(c instanceof FontTag) {
    FontTag font=(FontTag)c;
    System.out.println("FONT "+c.getCharacterId()+" "+font.getFontName()+" chars="+font.getCharacterCount());
    new FontExporter().exportFont(font,FontExportMode.TTF,Path.of(args[1],"font_"+c.getCharacterId()+".ttf").toFile());
   }
   return;
  }
  Set<String> requests=new HashSet<>(Arrays.asList(requested.split(",")));
  boolean backgrounds=args.length>3 && args[3].equals("background");
  AbortRetryIgnoreHandler h=new AbortRetryIgnoreHandler(){public int handle(Throwable e){throw new RuntimeException(e);}public AbortRetryIgnoreHandler getNewInstance(){return this;}};
  for(CharacterTag c:swf.getCharacters().values()) {
   Set<String> names=new TreeSet<>(c.getClassNames());
   if(c.getExportName()!=null) names.add(c.getExportName());
   if(requested.isEmpty()) { if(!names.isEmpty()) System.out.println(c.getCharacterId()+" "+names+" "+(c instanceof DefineSpriteTag?((DefineSpriteTag)c).frameCount:""));continue; }
   String target=null;
   for(String name:requests) if(names.contains(name) || name.equals("#"+c.getCharacterId())) {target=name;break;}
   if(target==null)continue;
   System.out.println("SYMBOL "+target);
   visited.clear();
   inspect(c.getCharacterId(),"",4);
   Path folder=Path.of(args[1],target.replace("#","id-"));Files.createDirectories(folder);
   if(backgrounds && c instanceof DefineSpriteTag) {
    DefineSpriteTag sprite=(DefineSpriteTag)c;
    for(DepthState d:sprite.getTimeline().getFrame(0).layers.values()) {
     if(target.equals("roleInfo1") && d.instanceName!=null && !d.instanceName.equals("head")) sprite.removeTag(d.placeObjectTag);
     if(target.equals("roleSkill1") && d.instanceName!=null) sprite.removeTag(d.placeObjectTag);
     if(target.equals("battletime") && swf.getCharacter(d.characterId) instanceof DefineEditTextTag) sprite.removeTag(d.placeObjectTag);
     if(target.equals("bagPanel") && (swf.getCharacter(d.characterId) instanceof DefineEditTextTag || d.instanceName!=null && (d.instanceName.startsWith("btn_") || d.instanceName.startsWith("txt_")))) sprite.removeTag(d.placeObjectTag);
     // Export the static bag panel separately from animated/interactive overlays.
     if(target.equals("bodyPanel") && ("progress".equals(d.instanceName)
       || Arrays.asList(57,94,125,140,147,163).contains(d.characterId))) sprite.removeTag(d.placeObjectTag);
    }
    sprite.resetTimeline();
   }
   if(c instanceof BoundedTag) System.out.println("RENDER_BOUNDS "+target+" "+((BoundedTag)c).getRectWithStrokes());
   List<Integer> frames=new ArrayList<>();
   int count=c instanceof DefineSpriteTag?((DefineSpriteTag)c).frameCount:(c instanceof ButtonTag?3:1);
   for(int i=0;i<count;i++)frames.add(i);
   if(c instanceof ImageTag) ImageIO.write(((ImageTag)c).getImageCached().getBufferedImage(),"PNG",folder.resolve("1.png").toFile());
   else if(c instanceof DefineShapeTag || c instanceof DefineShape2Tag || c instanceof DefineShape3Tag || c instanceof DefineShape4Tag)
    new ShapeExporter().exportShapes(h,folder.toString(),swf,new ReadOnlyTagList(Arrays.asList(c)),new ShapeExportSettings(ShapeExportMode.PNG,1.0),null,1.0);
   else new FrameExporter().exportFrames(h,folder.toString(),swf,c.getCharacterId(),frames,new FrameExportSettings(FrameExportMode.PNG,1.0),null);
  }
 }
}
// #endregion
