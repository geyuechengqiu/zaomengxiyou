package base
{
   import PhysicsWorlds.PhysicsWorld;
   import config.*;
   import flash.display.MovieClip;
   import flash.events.*;
   import flash.utils.*;
   import my.*;
   
   [Embed(source="/_assets/assets.swf", symbol="base.MonsterAppearPoint")]
   public class MonsterAppearPoint extends MovieClip
   {
       
      
      public var delay:int;
      
      public var interval:Number;
      
      public var totalNum:int;
      
      public var enemyType:int;
      
      public var isRandom:Boolean;
      
      public var stopPointIdx:int;
      
      public var monsterDisapperaPoint:MovieClip;
      
      private var pWorld:PhysicsWorld;
      
      private var count:int = 0;
      
      private var isStart:Boolean = false;
      
      private var gc:Config;
      
      private var currentCount:int = 0;
      
      public var isOver:Boolean = false;
      
      private var isReady:Boolean = false;
      
      private var randomArray:Array;
      
      public function MonsterAppearPoint()
      {
         this.randomArray = [1,2,4,5,7,8,11,12,13];
         super();
         this.gc = Config.getInstance();
         this.addEventListener(Event.REMOVED_FROM_STAGE,this.__removed,true,0,false);
      }
      
      private function __removed(param1:Event) : void
      {
         this.removeEventListener(Event.ENTER_FRAME,this.__step);
      }
      
      public function start() : void
      {
         var self:* = undefined;
         this.addEventListener(Event.ENTER_FRAME,this.__step);
         if(!this.gc.isHideDebug)
         {
            self = this;
            setTimeout(function():*
            {
               self.totalNum = 1;
            },1000);
         }
      }
      
      public function __step(param1:Event) : void
      {
         var _loc2_:int = 0;
         if(this.gc.isStopGame)
         {
            return;
         }
         if(!this.isStart)
         {
            if(this.count / 24 >= this.delay)
            {
               this.isStart = true;
               this.count = 0;
            }
         }
         if(this.isStart)
         {
            if(this.currentCount < this.totalNum)
            {
               if(this.count / 24 >= this.interval)
               {
                  this.isReady = true;
               }
            }
            if(this.count / 24 >= this.interval)
            {
               this.count = 0;
            }
         }
         if(this.isReady)
         {
            if(!this.gc.isFb())
            {
               if(this.gc.pWorld.monsterArray.length < this.gc.maxMonsterPerScreen)
               {
                  MainGame.getInstance().createMonster(this.enemyType,this.x,this.y);
                  ++this.currentCount;
                  this.isReady = false;
               }
            }
            else if(this.gc.isFb1())
            {
               if(this.gc.pWorld.monsterArray.length == 0)
               {
                  MainGame.getInstance().createMonster(this.enemyType,this.x,this.y,this.currentCount);
                  ++this.currentCount;
                  this.isReady = false;
               }
            }
         }
         if(this.currentCount >= this.totalNum)
         {
            this.isOver = true;
            if(this.parent)
            {
               this.parent.removeChild(this);
               _loc2_ = int(this.gc.pWorld.getMonsterAppearArray().indexOf(this));
               if(_loc2_ != -1)
               {
                  this.gc.pWorld.getMonsterAppearArray().splice(_loc2_,1);
               }
            }
         }
         if(!this.isReady)
         {
            ++this.count;
         }
      }
   }
}
