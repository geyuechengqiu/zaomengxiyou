import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.*;
import com.jpexs.decompiler.flash.types.*;
import java.io.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;

// Read the original body.stick placements; never execute the Flash scripts.
class ExportZaomengOneAttacks {
    static double[] transform(double[] r, MATRIX m) {
        double loX=Double.POSITIVE_INFINITY, loY=loX, hiX=-loX, hiY=-loX;
        for (double x : new double[]{r[0],r[0]+r[2]}) for (double y : new double[]{r[1],r[1]+r[3]}) {
            double px=x*m.getScaleXFloat()+y*m.getRotateSkew1Float()+m.translateX/20.0;
            double py=x*m.getRotateSkew0Float()+y*m.getScaleYFloat()+m.translateY/20.0;
            loX=Math.min(loX,px); hiX=Math.max(hiX,px); loY=Math.min(loY,py); hiY=Math.max(hiY,py);
        }
        return new double[]{loX,loY,hiX-loX,hiY-loY};
    }
    public static void main(String[] args) throws Exception {
        SWF swf=new SWF(new FileInputStream(args[0]),false);
        swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
        StringBuilder out=new StringBuilder("{\"units\":[");
        for(int kind=1;kind<=3;kind++) {
            DefineSpriteTag root=null;
            for(CharacterTag c:swf.getCharacters().values()) if(c instanceof DefineSpriteTag && c.getClassNames().contains("export.monster.Monster"+kind)) root=(DefineSpriteTag)c;
            if(root==null) throw new IllegalStateException("Monster not found: "+kind);
            DepthState body=null;
            for(int i=0;i<root.frameCount;i++) {
                Frame f=root.getTimeline().getFrame(i);
                if(f.labels.contains("hit1")) for(DepthState d:f.layers.values()) if("body".equals(d.instanceName)) body=d;
            }
            if(body==null) throw new IllegalStateException("hit1 body missing");
            DefineSpriteTag clip=(DefineSpriteTag)swf.getCharacter(body.characterId);
            if(kind>1) out.append(',');
            out.append("{\"kind\":"+kind+",\"duration_frames\":"+clip.frameCount+",\"frames\":[");
            boolean first=true;
            for(int i=0;i<clip.frameCount;i++) for(DepthState d:clip.getTimeline().getFrame(i).layers.values()) {
                if(!"stick".equals(d.instanceName)) continue;
                CharacterTag hit=swf.getCharacter(d.characterId);
                RECT r=((BoundedTag)hit).getRectWithStrokes();
                double[] bounds=transform(transform(new double[]{r.Xmin/20.0,r.Ymin/20.0,(r.Xmax-r.Xmin)/20.0,(r.Ymax-r.Ymin)/20.0},d.matrix),body.matrix);
                if(!first) out.append(','); first=false;
                out.append("{\"frame\":"+i+",\"rect\":["+bounds[0]+","+bounds[1]+","+bounds[2]+","+bounds[3]+"]}");
            }
            out.append("]}");
        }
        int hurtFrames=0;
        if(args.length>2) {
            SWF role=new SWF(new FileInputStream(args[2]),false); role.assignClassesToSymbols();
            for(CharacterTag c:role.getCharacters().values()) if(c instanceof DefineSpriteTag && c.getClassNames().contains("export.hero.Role1")) {
                DefineSpriteTag hero=(DefineSpriteTag)c;
                for(int i=0;i<hero.frameCount;i++) {
                    Frame f=hero.getTimeline().getFrame(i);
                    if(f.labels.contains("hurt")) for(DepthState d:f.layers.values()) if("body".equals(d.instanceName)) hurtFrames=((DefineSpriteTag)role.getCharacter(d.characterId)).frameCount;
                }
            }
        }
        out.append("],\"player_hurt_frames\":"+hurtFrames+"}\n");
        Files.createDirectories(Path.of(args[1]).getParent());
        Files.writeString(Path.of(args[1]),out.toString(),StandardCharsets.UTF_8);
        System.out.println(out);
    }
}
