package PhysicsWorlds
{
   import base.*;
   import com.greensock.*;
   import config.*;
   import export.*;
   import flash.display.*;
   import flash.events.*;
   import my.*;
   
   public class PhysicsWorld
   {
       
      
      private var wallArray:Array;
      
      private var stopPointArray:Array;
      
      private var monsterDisappertPointArray:Array;
      
      private var markArray:Array;
      
      private var thronArray:Array;
      
      private var continueArray:Array;
      
      private var transferDoorArray:Array;
      
      private var fbEnter:MovieClip;
      
      public var monsterArray:Array;
      
      public var heroArray:Array;
      
      private var h:HitTestPoint;
      
      private var gc:Config;
      
      public function PhysicsWorld()
      {
         this.wallArray = [];
         this.stopPointArray = [];
         this.monsterDisappertPointArray = [];
         this.markArray = [];
         this.thronArray = [];
         this.continueArray = [];
         this.transferDoorArray = [];
         this.monsterArray = new Array();
         this.heroArray = new Array();
         super();
         this.gc = Config.getInstance();
         this.h = new HitTestPoint();
         this.h.x = 200;
         this.h.y = -150;
         this.h.width *= 0.5;
         this.h.height *= 0.5;
         this.gc.num5 = 3;
      }
      
      public function addSubObj(param1:*) : void
      {
         var _loc2_:MovieClip = null;
         var _loc3_:StopPoint = null;
         var _loc4_:int = 0;
         var _loc5_:StopPoint = null;
         if(param1 is MovieClip)
         {
            _loc2_ = param1 as MovieClip;
            if(_loc2_.getChildByName("isWall"))
            {
               if(_loc2_.rotation == 0)
               {
                  this.wallArray.push(_loc2_ as MovieClip);
               }
               else
               {
                  this.wallArray.unshift(_loc2_ as MovieClip);
               }
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("isThroughWall"))
            {
               this.wallArray.push(_loc2_ as MovieClip);
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("isTurnBack"))
            {
               this.markArray.push(_loc2_ as Sprite);
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("isthron"))
            {
               this.thronArray.push(_loc2_ as MovieClip);
            }
            if(_loc2_.getChildByName("noContinueGo"))
            {
               this.continueArray.push(_loc2_ as Sprite);
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("isTransferDoor"))
            {
               this.transferDoorArray.push(_loc2_ as Sprite);
               _loc2_.visible = false;
            }
            if(_loc2_.getChildByName("monsterDisapperaPoint"))
            {
               this.monsterDisappertPointArray.push(_loc2_);
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("isFb"))
            {
               this.fbEnter = _loc2_;
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
            if(_loc2_.getChildByName("stophere"))
            {
               _loc3_ = new StopPoint();
               _loc3_.setXY(_loc2_.x,_loc2_.y);
               if(this.stopPointArray.length > 0)
               {
                  _loc4_ = 0;
                  while(_loc4_ < this.stopPointArray.length)
                  {
                     if((_loc5_ = this.stopPointArray[_loc4_] as StopPoint).getDataX() >= _loc2_.x)
                     {
                        this.stopPointArray.splice(_loc4_,0,_loc3_);
                        break;
                     }
                     if(_loc4_ == this.stopPointArray.length - 1)
                     {
                        this.stopPointArray.splice(_loc4_ + 1,0,_loc3_);
                        break;
                     }
                     _loc4_++;
                  }
               }
               else
               {
                  this.stopPointArray.push(_loc3_);
               }
               if(this.gc.isHideDebug)
               {
                  _loc2_.visible = false;
               }
            }
         }
      }
      
      public function pWorldStart() : void
      {
         var _loc2_:StopPoint = null;
         this.gc.gameInfo.addChild(this.h);
         this.gc.vControllor = new ViewControllor();
         var _loc1_:int = 0;
         while(_loc1_ < this.stopPointArray.length)
         {
            _loc2_ = StopPoint(this.stopPointArray[_loc1_]);
            _loc2_.idx = _loc1_;
            _loc1_++;
         }
      }
      
      public function getWallArray() : Array
      {
         return this.wallArray;
      }
      
      public function getMarkArray() : Array
      {
         return this.markArray;
      }
      
      public function getNoContinueArray() : Array
      {
         return this.continueArray;
      }
      
      public function getTransferDoorArray() : Array
      {
         return this.transferDoorArray;
      }
      
      public function getStopPointArray() : Array
      {
         return this.stopPointArray;
      }
      
      public function getMonsterAppearArray() : Array
      {
         return this.monsterDisappertPointArray;
      }
      
      public function step() : void
      {
         var alen:uint;
         var p:Array = null;
         var i:int = 0;
         var bh:BaseHero = null;
         this.gc.gameInfo.step();
         alen = uint(this.monsterArray.length);
         while(alen-- > 0)
         {
            if(this.monsterArray[alen])
            {
               this.monsterArray[alen].step();
            }
         }
         alen = uint(this.heroArray.length);
         while(alen-- > 0)
         {
            if(this.heroArray[alen])
            {
               this.heroArray[alen].step();
            }
         }
         this.gc.vControllor.step();
         this.h.step();
         this.stepThrons();
         if(this.fbEnter)
         {
            p = this.gc.getPlayerArray();
            i = 0;
            while(i < p.length)
            {
               bh = p[i] as BaseHero;
               if(Math.abs(bh.x - this.fbEnter.x) <= 600 && Math.abs(bh.y - this.fbEnter.y) <= 200)
               {
                  if(bh.colipse.hitTestObject(this.fbEnter))
                  {
                     this.gc.keyboardControl.destroy();
                     TweenMax.to(this.gc.gameInfo,1,{"alpha":0});
                     TweenMax.to(this.gc.gameSence,1,{
                        "alpha":0,
                        "onComplete":function():*
                        {
                           gc.eventManger.dispatchEvent(new Event("fbfbfbfb"));
                        }
                     });
                     this.fbEnter = null;
                     break;
                  }
               }
               i++;
            }
         }
      }
      
      private function stepThrons() : void
      {
         var _loc1_:uint = uint(this.thronArray.length);
         while(_loc1_-- > 0)
         {
            this.thronArray[_loc1_].step();
         }
      }
      
      public function destroy() : void
      {
         var _loc1_:int = 0;
         var _loc2_:BaseHero = null;
         var _loc3_:BaseMonster = null;
         this.h.destroy();
         this.stopPointArray = [];
         this.wallArray = [];
         this.markArray = [];
         this.thronArray = [];
         this.continueArray = [];
         this.transferDoorArray = [];
         this.monsterDisappertPointArray = [];
         this.fbEnter = null;
         _loc1_ = 0;
         while(_loc1_ < this.heroArray.length)
         {
            _loc2_ = this.heroArray[_loc1_] as BaseHero;
            _loc2_.destroy();
            _loc1_++;
         }
         this.heroArray = [];
         _loc1_ = 0;
         while(_loc1_ < this.monsterArray.length)
         {
            _loc3_ = this.monsterArray[_loc1_] as BaseMonster;
            _loc3_.destroy();
            _loc1_++;
         }
         this.monsterArray = [];
         this.gc.num7 = 4;
      }
   }
}
