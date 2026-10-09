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
// #region Original Boss UI symbols, read-only Flash rendering
class ExportOriginalBossUI {
 public static void main(String[] args) throws Exception {
  SWF swf=new SWF(new FileInputStream(args[0]),false);
  swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
  Path output=Path.of(args[1]); Files.createDirectories(output);
  AbortRetryIgnoreHandler h=new AbortRetryIgnoreHandler(){public int handle(Throwable e){throw new RuntimeException(e);}public AbortRetryIgnoreHandler getNewInstance(){return this;}};
  for(CharacterTag tag:swf.getCharacters().values()) {
   Set<String> names=tag.getClassNames();
   for(String name:names) if(Arrays.asList("boosBleedBar","bossbar1","bossbar2","bossbar3","bossComing").contains(name)) {
    int id=tag.getCharacterId();
    System.out.println(name+" id="+id+" bounds="+((BoundedTag)tag).getRectWithStrokes());
    new FrameExporter().exportFrames(h,output.resolve(name).toString(),swf,id,Arrays.asList(0),new FrameExportSettings(FrameExportMode.PNG,1.0),null);
    if(tag instanceof DefineSpriteTag) for(DepthState d:((DefineSpriteTag)tag).getTimeline().getFrame(0).layers.values())
      System.out.println("  depth="+d.depth+" name="+d.instanceName+" id="+d.characterId+" matrix="+d.matrix);
   }
  }
  new ShapeExporter().exportShapes(h,output.resolve("frame").toString(),swf,new ReadOnlyTagList(Arrays.asList(swf.getCharacter(1324))),new ShapeExportSettings(ShapeExportMode.PNG,1.0),null,1.0);
  new FrameExporter().exportFrames(h,output.resolve("protect").toString(),swf,1331,Arrays.asList(0),new FrameExportSettings(FrameExportMode.PNG,1.0),null);
 }
}
// #endregion
