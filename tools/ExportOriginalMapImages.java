import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.base.CharacterTag;
import com.jpexs.decompiler.flash.tags.base.ImageTag;
import com.jpexs.decompiler.flash.tags.base.BoundedTag;
import com.jpexs.decompiler.flash.tags.DefineSpriteTag;
import com.jpexs.decompiler.flash.AbortRetryIgnoreHandler;
import com.jpexs.decompiler.flash.exporters.FrameExporter;
import com.jpexs.decompiler.flash.exporters.modes.FrameExportMode;
import com.jpexs.decompiler.flash.exporters.settings.FrameExportSettings;
import javax.imageio.ImageIO;
import java.io.FileInputStream;
import java.nio.file.*;
// #region Read-only original map bitmaps and class-name evidence
class ExportOriginalMapImages {
 public static void main(String[] args) throws Exception {
  SWF swf = new SWF(new FileInputStream(args[0]), false);
  swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
  Path output = Path.of(args[1]); Files.createDirectories(output);
  StringBuilder evidence = new StringBuilder("id\twidth\theight\tclasses\n");
  StringBuilder symbols = new StringBuilder("id\tx\ty\twidth\theight\tframes\tclasses\n");
  AbortRetryIgnoreHandler handler = new AbortRetryIgnoreHandler() {
   public int handle(Throwable e) { throw new RuntimeException(e); }
   public AbortRetryIgnoreHandler getNewInstance() { return this; }
  };
  for (CharacterTag tag : swf.getCharacters().values()) {
   if (!(tag instanceof ImageTag) && tag instanceof BoundedTag && !tag.getClassNames().isEmpty()) {
    var rect = ((BoundedTag)tag).getRectWithStrokes();
    int frames = tag instanceof DefineSpriteTag ? ((DefineSpriteTag)tag).getTimeline().getFrameCount() : 1;
    symbols.append(tag.getCharacterId()+"\t"+rect.Xmin/20.0+"\t"+rect.Ymin/20.0+"\t"+(rect.Xmax-rect.Xmin)/20.0+"\t"+(rect.Ymax-rect.Ymin)/20.0+"\t"+frames+"\t"+String.join(";",tag.getClassNames())+"\n");
   }
   if (tag.getClassNames().contains("中景01")) {
    System.out.println("Middle01 symbol="+tag.getCharacterId()+" bounds="+((BoundedTag)tag).getRectWithStrokes());
    new FrameExporter().exportFrames(handler,output.resolve("middle01").toString(),swf,tag.getCharacterId(),java.util.Arrays.asList(0),new FrameExportSettings(FrameExportMode.PNG,1.0),null);
    var timeline = ((DefineSpriteTag)tag).getTimeline();
    StringBuilder rows = new StringBuilder("frame\tdepth\tcharacter\tx\ty\tscale_x\tscale_y\trotation_0\trotation_1\talpha\n");
    for (int frame=0;frame<timeline.getFrameCount();frame++) {
     for (var state:timeline.getFrame(frame).layers.values()) {
      var m=state.matrix;
      if(frame==0||frame==100||frame==200) System.out.println("CLOUD "+frame+" depth="+state.depth+" id="+state.characterId+" matrix="+m+" color="+state.colorTransForm);
      rows.append(frame+"\t"+state.depth+"\t"+state.characterId+"\t"+m.translateX/20.0+"\t"+m.translateY/20.0+"\t"+m.scaleX+"\t"+m.scaleY+"\t"+m.rotateSkew0+"\t"+m.rotateSkew1+"\t"+(state.colorTransForm==null?1.0:state.colorTransForm.getAlphaMulti()/256.0)+"\n");
     }
    }
    Files.writeString(output.resolve("cloud_timeline.tsv"),rows);
   }
   if (!(tag instanceof ImageTag)) continue;
   ImageTag image = (ImageTag)tag;
   var dimension = image.getImageDimension();
   ImageIO.write(image.getImageCached().getBufferedImage(), "png", output.resolve(tag.getCharacterId()+".png").toFile());
   String row = tag.getCharacterId()+"\t"+dimension.width+"\t"+dimension.height+"\t"+String.join(";", tag.getClassNames());
   evidence.append(row+"\n"); System.out.println(row);
  }
  Files.writeString(output.resolve("images.tsv"), evidence);
  Files.writeString(output.resolve("symbols.tsv"), symbols);
 }
}
// #endregion
