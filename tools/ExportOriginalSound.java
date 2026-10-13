import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.tags.DefineSoundTag;
import com.jpexs.decompiler.flash.tags.base.CharacterTag;
import java.io.*;
import java.nio.file.*;

// Offline exact MP3 extraction; getRawSoundData removes SWF's seek prefix.
class ExportOriginalSound {
    public static void main(String[] args) throws Exception {
        SWF swf = new SWF(new FileInputStream(args[0]), false);
        swf.assignClassesToSymbols(); swf.assignExportNamesToSymbols();
        for (CharacterTag tag : swf.getCharacters().values()) {
            if (!(tag instanceof DefineSoundTag sound)) continue;
            if (!tag.getClassNames().contains(args[1]) && !args[1].equals(tag.getExportName())) continue;
            if (sound.getSoundFormatId() != 2) throw new IOException("Expected original MP3");
            try (var output = new FileOutputStream(args[2])) {
                for (var part : sound.getRawSoundData()) output.write(part.getRangeData());
            }
            System.out.println("Exported " + args[1] + " -> " + args[2]);
            return;
        }
        throw new IOException("Sound symbol not found: " + args[1]);
    }
}
