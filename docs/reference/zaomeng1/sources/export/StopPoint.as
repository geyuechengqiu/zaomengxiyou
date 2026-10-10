package export
{
   import base.*;
   import config.*;
   import flash.display.MovieClip;
   import flash.events.*;
   import flash.geom.*;
   
   [Embed(source="/_assets/assets.swf", symbol="export.StopPoint")]
   public class StopPoint extends MovieClip
   {
       
      
      public var betweenRandL:int = 1150;
      
      public var idx:int;
      
      public var isBoss:Boolean;
      
      private var data:Point;
      
      public var isSendMonster:Boolean = false;
      
      private var gc:Config;
      
      private var isFirstZero:Boolean = true;
      
      public var stophere:MovieClip;
      
      public var isAlive:Boolean = true;
      
      public function StopPoint()
      {
         this.data = new Point();
         super();
         this.gc = Config.getInstance();
         if(this.gc.curStage == 4 && this.gc.curLevel == 1 || this.gc.curStage == 9 && this.gc.curLevel == 1)
         {
            this.betweenRandL = 940;
         }
         if(this.gc.curStage == 1)
         {
            this.betweenRandL = 1450;
         }
      }
      
      public function setXY(param1:Number, param2:Number) : void
      {
         this.data.x = param1;
         this.data.y = param2;
      }
      
      public function touch() : void
      {
         var _loc1_:int = 0;
         var _loc2_:MonsterAppearPoint = null;
         if(!this.isSendMonster)
         {
            this.isSendMonster = true;
            this.isAlive = true;
            _loc1_ = 0;
            while(_loc1_ < this.gc.pWorld.getMonsterAppearArray().length)
            {
               _loc2_ = MonsterAppearPoint(this.gc.pWorld.getMonsterAppearArray()[_loc1_]);
               if(_loc2_.stopPointIdx == this.idx)
               {
                  _loc2_.start();
               }
               _loc1_++;
            }
         }
         if(!this.hasEventListener(Event.ENTER_FRAME))
         {
            this.addEventListener(Event.ENTER_FRAME,this.__enterFrame);
         }
      }
      
      private function __enterFrame(param1:Event) : void
      {
         var _loc4_:MonsterAppearPoint = null;
         var _loc2_:Boolean = true;
         var _loc3_:int = 0;
         while(_loc3_ < this.gc.pWorld.getMonsterAppearArray().length)
         {
            if((_loc4_ = MonsterAppearPoint(this.gc.pWorld.getMonsterAppearArray()[_loc3_])).stopPointIdx == this.idx)
            {
               if(!_loc4_.isOver)
               {
                  _loc2_ = false;
                  break;
               }
            }
            _loc3_++;
         }
         if(_loc2_ && this.gc.pWorld.monsterArray.length == 0)
         {
            this.destroy();
         }
      }
      
      public function destroy() : void
      {
         var _loc3_:MovieClip = null;
         var _loc1_:Array = this.gc.pWorld.getStopPointArray();
         var _loc2_:int = int(_loc1_.indexOf(this));
         if(_loc2_ != this.gc.pWorld.getStopPointArray().length - 1)
         {
            this.gc.vControllor.setAutoCamera();
            if(this.idx < 4)
            {
               _loc3_ = AUtils.getNewObj("GOGO");
               _loc3_.x = 860;
               _loc3_.y = 300;
               _loc3_.scaleX = 0.7;
               _loc3_.scaleY = 0.7;
               this.gc.gameInfo.addChild(_loc3_);
            }
         }
         if(_loc2_ != -1)
         {
            _loc1_.splice(_loc2_,1);
         }
         this.isAlive = false;
         this.removeEventListener(Event.ENTER_FRAME,this.__enterFrame);
      }
      
      public function getLeftDataX() : Number
      {
         return this.betweenRandL - 940;
      }
      
      public function getDataX() : Number
      {
         return this.data.x;
      }
   }
}
