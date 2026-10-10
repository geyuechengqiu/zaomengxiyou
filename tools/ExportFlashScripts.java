import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.exporters.modes.*;
import com.jpexs.decompiler.flash.exporters.settings.*;
import java.io.*;
// #region Offline read-only source export for the supplied Flash archive
class ExportFlashScripts {
 public static void main(String[] args) throws Exception {
  SWF swf = new SWF(new FileInputStream(args[0]), false);
  System.out.println("SWF version="+swf.version+" fps="+swf.frameRate+" rect="+swf.displayRect+" AS3="+swf.isAS3());
  AbortRetryIgnoreHandler handler = new AbortRetryIgnoreHandler() {
   public int handle(Throwable e) { throw new RuntimeException(e); }
   public AbortRetryIgnoreHandler getNewInstance() { return this; }
  };
  swf.exportActionScript(handler, args[1], new ScriptExportSettings(ScriptExportMode.AS, false, false, false, false), true, null);
  System.out.println("Exported scripts to " + args[1]);
 }
}
// #endregion
