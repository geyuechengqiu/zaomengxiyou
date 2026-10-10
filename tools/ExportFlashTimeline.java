import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.*;
import java.io.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
// #region Export original display-list placements and frame labels without running Flash
class ExportFlashTimeline {
 static String quote(String value) { return value==null?"null":"\""+value.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r")+"\""; }
 public static void main(String[] args) throws Exception {
  SWF swf=new SWF(new FileInputStream(args[0]),false);
  swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
  StringBuilder out=new StringBuilder("{\"fps\":"+swf.frameRate+",\"symbols\":[");
  boolean firstSymbol=true;
  for(CharacterTag tag:swf.getCharacters().values()) {
   if(!(tag instanceof DefineSpriteTag)) continue;
   Set<String> names=new TreeSet<>(tag.getClassNames());
   if(tag.getExportName()!=null) names.add(tag.getExportName());
   if(names.stream().noneMatch(n->Arrays.asList(args[2].split(",")).contains(n))) continue;
   if(!firstSymbol) out.append(',');firstSymbol=false;
   DefineSpriteTag sprite=(DefineSpriteTag)tag;
   out.append("{\"names\":[");
   boolean first=true;for(String name:names){if(!first)out.append(',');first=false;out.append(quote(name));}
   out.append("],\"frames\":[");
   for(int index=0;index<sprite.frameCount;index++) {
    if(index>0)out.append(',');
    Frame frame=sprite.getTimeline().getFrame(index);
    out.append("{\"frame\":"+(index+1)+",\"labels\":[");
    first=true;for(String label:frame.labels){if(!first)out.append(',');first=false;out.append(quote(label));}
    out.append("],\"placements\":[");first=true;
    for(DepthState state:frame.layers.values()) {
     if(state.characterId<=0)continue;
     if(!first)out.append(',');first=false;
     CharacterTag child=swf.getCharacter(state.characterId);
     out.append("{\"instance\":"+quote(state.instanceName)+",\"character_id\":"+state.characterId+",\"classes\":[");
     boolean firstClass=true;for(String name:child.getClassNames()){if(!firstClass)out.append(',');firstClass=false;out.append(quote(name));}
     out.append("],\"x\":"+(state.matrix.translateX/20.0)+",\"y\":"+(state.matrix.translateY/20.0)+",\"scale_x\":"+state.matrix.getScaleXFloat()+",\"scale_y\":"+state.matrix.getScaleYFloat()+"}");
    }
    out.append("]}");
   }
   out.append("]}");
  }
  out.append("]}");
  Files.createDirectories(Path.of(args[1]).getParent());
  Files.writeString(Path.of(args[1]),out.toString(),StandardCharsets.UTF_8);
  System.out.println("Exported original timeline: "+args[1]);
 }
}
// #endregion
