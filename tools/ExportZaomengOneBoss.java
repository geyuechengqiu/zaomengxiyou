import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.types.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

// Offline, recursive body.stick geometry; no ActionScript execution.
class ExportZaomengOneBoss {
    static SWF swf;
    static double[] transform(double[] r, MATRIX m) {
        double x0=1e30,y0=1e30,x1=-1e30,y1=-1e30;
        for(double x:new double[]{r[0],r[0]+r[2]}) for(double y:new double[]{r[1],r[1]+r[3]}) {
            double px=x*m.getScaleXFloat()+y*m.getRotateSkew1Float()+m.translateX/20.0;
            double py=x*m.getRotateSkew0Float()+y*m.getScaleYFloat()+m.translateY/20.0;
            x0=Math.min(x0,px);y0=Math.min(y0,py);x1=Math.max(x1,px);y1=Math.max(y1,py);
        }
        return new double[]{x0,y0,x1-x0,y1-y0};
    }
    static List<double[]> sticks(DefineSpriteTag clip,int frame,int depth) {
        List<double[]> result=new ArrayList<>();
        if(depth>6)return result;
        for(DepthState d:clip.getTimeline().getFrame(frame%clip.frameCount).layers.values()) {
            CharacterTag child=swf.getCharacter(d.characterId);
            if(child==null)continue;
            if(d.instanceName != null && d.instanceName.matches("stick[0-9]*")) {
                RECT r=((BoundedTag)child).getRectWithStrokes();
                result.add(transform(new double[]{r.Xmin/20.0,r.Ymin/20.0,(r.Xmax-r.Xmin)/20.0,(r.Ymax-r.Ymin)/20.0},d.matrix));
            } else if(child instanceof DefineSpriteTag) {
                for(double[] r:sticks((DefineSpriteTag)child,d.time,depth+1))result.add(transform(r,d.matrix));
            }
        }
        return result;
    }
    static String geometry(DefineSpriteTag clip,MATRIX parent) {
        StringJoiner frames=new StringJoiner(",");
        for(int f=0;f<clip.frameCount;f++) {
            List<double[]> rows=sticks(clip,f,0);
            for(double[] r:rows) {
                if(parent!=null)r=transform(r,parent);
                frames.add("{\"frame\":"+f+",\"rect\":"+Arrays.toString(r)+"}");
            }
        }
        return "{\"duration_frames\":"+clip.frameCount+",\"frames\":["+frames+"]}";
    }
    public static void main(String[] args)throws Exception {
        swf=new SWF(new FileInputStream(args[0]),false);swf.assignClassesToSymbols();swf.assignExportNamesToSymbols();
        DefineSpriteTag root=(DefineSpriteTag)swf.getCharacters().values().stream().filter(c->c.getClassNames().contains("export.monster.Monster4")).findFirst().orElseThrow();
        StringJoiner out=new StringJoiner(",","{","}\n");
        for(String label:new String[]{"hit1","hit2","hit3"}) for(int f=0;f<root.frameCount;f++) {
            Frame frame=root.getTimeline().getFrame(f);
            if(frame.labels.contains(label))for(DepthState d:frame.layers.values())if("body".equals(d.instanceName))out.add("\""+label+"\":"+geometry((DefineSpriteTag)swf.getCharacter(d.characterId),d.matrix));
        }
        DefineSpriteTag bullet=(DefineSpriteTag)swf.getCharacters().values().stream().filter(c->"Boss2Bullet1".equals(c.getExportName()) || c.getClassNames().contains("Boss2Bullet1")).findFirst().orElseThrow();
        out.add("\"bullet\":"+geometry(bullet,null));
        Files.writeString(Path.of(args[1]),out.toString());System.out.println("Exported original Boss4 sticks: "+args[1]);
    }
}
