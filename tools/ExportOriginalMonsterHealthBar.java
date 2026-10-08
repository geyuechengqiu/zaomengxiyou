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
// #region 原版血条符号解析与只读导出
class ExportOriginalMonsterHealthBar {
 static SWF swf;
 static void inspect(int id,String indent) throws Exception {
  CharacterTag c=swf.getCharacter(id);
  System.out.println(indent+id+" "+c.getClass().getSimpleName()+" "+((BoundedTag)c).getRectWithStrokes());
  if(c instanceof DefineSpriteTag){
   Frame f=((DefineSpriteTag)c).getTimeline().getFrame(0);
   for(DepthState d:f.layers.values()){
    System.out.println(indent+" depth="+d.depth+" name="+d.instanceName+" clip="+d.clipDepth+" matrix="+d.matrix+" color="+d.colorTransForm);
    inspect(d.characterId,indent+"  ");
   }
  }
 }
 public static void main(String[] args)throws Exception{
  swf=new SWF(new FileInputStream(args[0]),false);swf.assignClassesToSymbols();swf.assignExportNamesToSymbols();
  if(!swf.getCharacter(179).getClassNames().contains("monsterBleedBar"))throw new IllegalArgumentException("Unexpected source symbol");
  inspect(179,"");
  AbortRetryIgnoreHandler h=new AbortRetryIgnoreHandler(){public int handle(Throwable e){throw new RuntimeException(e);}public AbortRetryIgnoreHandler getNewInstance(){return this;}};
  if(args.length>1){
   Path output=Path.of(args[1]);Files.createDirectories(output);
   new ShapeExporter().exportShapes(h,output.resolve("shapes").toString(),swf,new ReadOnlyTagList(java.util.Arrays.asList(swf.getCharacter(174),swf.getCharacter(176))),new ShapeExportSettings(ShapeExportMode.SVG,1.0),null,1.0);
   for(int id:new int[]{179,177})new FrameExporter().exportFrames(h,output.resolve("symbol_"+id).toString(),swf,id,null,new FrameExportSettings(FrameExportMode.PNG,1.0),null);
  }
 }
}

// #endregion
