package loader
{
   import config.*;
   import event.*;
   import flash.display.*;
   import flash.events.*;
   import flash.net.*;
   import flash.system.*;
   import flash.utils.*;
   
   public class Aloader
   {
       
      
      public var urls:Array;
      
      public var _i:uint;
      
      public var view:*;
      
      public var gc:Config;
      
      public var currentFileIdx:int;
      
      private var deMc:*;
      
      public function Aloader()
      {
         this.urls = ["Role.swf","Monster_v1.swf","Monster2_v4.swf","Monster3_v3.swf","OtherMat_v5.swf","backpack_v2.swf","Music.swf"];
         super();
         this.gc = Config.getInstance();
      }
      
      public function init() : *
      {
         this._i = 0;
         this.next();
      }
      
      public function next() : *
      {
         if(this._i >= this.urls.length)
         {
            GMain.getInstance().processComplete();
            this.gc.eventManger.dispatchEvent(new CommonEvent("LoadOver"));
            return;
         }
         this.doDecrypt(this.urls[this._i++],this.next,this._i + 1);
      }
      
      public function doDecrypt(param1:String, param2:Function, param3:int) : void
      {
         var uloader:URLLoader = null;
         var url:String = param1;
         var after:Function = param2;
         var files:int = param3;
         this.currentFileIdx = files;
         uloader = new URLLoader();
         uloader.dataFormat = URLLoaderDataFormat.BINARY;
         uloader.addEventListener(Event.COMPLETE,function(param1:*):*
         {
            var _loc5_:ByteArray = null;
            uloader.removeEventListener(Event.COMPLETE,arguments.callee);
            var _loc3_:ByteArray = uloader.data as ByteArray;
            var _loc4_:Loader = new Loader();
            if(url == "Monster3_v3.swf" || url == "Monster2_v4.swf" || url == "OtherMat_v5.swf")
            {
               _loc4_.loadBytes(_loc3_,new LoaderContext(false,ApplicationDomain.currentDomain));
            }
            else
            {
               _loc4_.loadBytes(_loc3_,new LoaderContext(false,ApplicationDomain.currentDomain));
            }
            _loc4_.unload();
            _loc4_ = null;
            uloader.removeEventListener(ProgressEvent.PROGRESS,__progress);
            uloader.close();
            uloader = null;
            after();
         });
         uloader.load(new URLRequest(url));
         uloader.addEventListener(ProgressEvent.PROGRESS,this.__progress);
      }
      
      private function __progress(param1:ProgressEvent) : void
      {
         var _loc2_:int = int(int(param1.bytesLoaded / param1.bytesTotal * 100));
         GMain.getInstance().showProgress(_loc2_,this.currentFileIdx);
      }
   }
}
