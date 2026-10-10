package my
{
   import base.*;
   import config.*;
   import event.*;
   import export.*;
   import flash.display.Sprite;
   import flash.events.*;
   import flash.utils.*;
   import manager.*;
   
   public class MainGame
   {
      
      private static var _this:MainGame;
       
      
      private var gc:Config;
      
      private var root:Sprite;
      
      public function MainGame(param1:Sprite)
      {
         super();
         this.gc = Config.getInstance();
         this.root = param1;
         this.gc.eventManger.addEventListener("LevelClear",this.__levelClear);
         this.gc.eventManger.addEventListener("fbfbfbfb",this.__fbfbfbfb);
         if(!_this)
         {
            _this = this;
         }
      }
      
      public static function getInstance() : MainGame
      {
         return _this;
      }
      
      public function GameStart(param1:uint = 1, param2:uint = 1) : void
      {
         this.newGame(param1,param2);
      }
      
      private function __fbfbfbfb(param1:Event) : void
      {
         if(this.gc.curStage == 1 && this.gc.curLevel == 2)
         {
            this.destroyGame();
            this.gc.curStage = 9;
            this.gc.curLevel = 1;
            this.gc.eventManger.dispatchEvent(new Event("ReStart"));
         }
      }
      
      private function __levelClear(param1:Event) : void
      {
         SoundManager.play("begin");
         if(this.gc.curStage == this.gc.curBigStage)
         {
            if(this.gc.curBigStage <= 3)
            {
               if(this.gc.curLevel == this.gc.curBigLevel)
               {
                  if(this.gc.curLevel == 3)
                  {
                     ++this.gc.curBigStage;
                     this.gc.curBigLevel = 1;
                  }
                  else if(this.gc.curLevel < 3)
                  {
                     ++this.gc.curBigLevel;
                  }
               }
            }
            else if(this.gc.curBigStage == 4)
            {
               this.gc.curBigLevel = 1;
            }
         }
         this.destroyGame();
         GMain.getInstance().switchSence("showStageMap");
      }
      
      public function createMonster(param1:int, param2:Number, param3:Number, param4:int = -1) : BaseMonster
      {
         var _loc6_:int = 0;
         var _loc7_:int = 0;
         var _loc5_:BaseMonster;
         (_loc5_ = AUtils.getNewObj("export.monster.Monster" + param1) as BaseMonster).x = param2;
         _loc5_.y = param3;
         this.gc.pWorld.monsterArray.push(_loc5_);
         if(param1 == 21)
         {
            if(this.gc.hero1)
            {
               _loc6_ = int(this.gc.gameSence.getChildIndex(this.gc.hero1));
            }
            else
            {
               _loc6_ = 99999;
            }
            if(this.gc.hero2)
            {
               _loc7_ = int(this.gc.gameSence.getChildIndex(this.gc.hero2));
            }
            else
            {
               _loc7_ = 99999;
            }
            this.gc.gameSence.addChildAt(_loc5_,Math.min(_loc6_,_loc7_));
         }
         else
         {
            this.gc.gameSence.addChild(_loc5_);
         }
         return _loc5_;
      }
      
      public function stopGame(param1:int = 0) : void
      {
         var b:BaseHero = null;
         var time:int = param1;
         var i:int = 0;
         while(i < this.gc.getPlayerArray().length)
         {
            b = this.gc.getPlayerArray()[i] as BaseHero;
            AUtils.stopAllChildren(b);
            i++;
         }
         if(time != 0)
         {
            setTimeout(function():*
            {
               continueGame();
            },time);
         }
         this.gc.isStopGame = true;
      }
      
      public function continueGame() : void
      {
         var _loc2_:BaseHero = null;
         var _loc1_:int = 0;
         while(_loc1_ < this.gc.getPlayerArray().length)
         {
            _loc2_ = this.gc.getPlayerArray()[_loc1_] as BaseHero;
            AUtils.startAllChildren(_loc2_);
            _loc1_++;
         }
         this.gc.isStopGame = false;
      }
      
      public function destroyGame() : void
      {
         this.root.removeEventListener(Event.ENTER_FRAME,this.__enterFrame);
         this.gc.eventManger.removeEventListener("LevelClear",this.__levelClear);
         this.gc.eventManger.removeEventListener("fbfbfbfb",this.__fbfbfbfb);
         this.gc.gameSence.destroy();
         this.gc.gameInfo.destroy();
         this.gc.pWorld.destroy();
         this.gc.bg1.destroy();
         this.gc.keyboardControl.destroy();
         this.gc.isStopGame = false;
         this.gc.destroyGame();
         if(this.gc.hero1)
         {
            this.gc.hero1.levelClear();
         }
         if(this.gc.hero2)
         {
            this.gc.hero2.levelClear();
         }
         _this = null;
      }
      
      public function destroyMode() : void
      {
         this.destroyGame();
         if(this.gc.hero1)
         {
            this.gc.hero1.dispose();
            this.gc.hero1.roleProperies.destory();
         }
         if(this.gc.hero2)
         {
            this.gc.hero2.dispose();
            this.gc.hero2.roleProperies.destory();
         }
         this.gc.initData();
      }
      
      public function newGame(param1:uint = 1, param2:uint = 1) : void
      {
         this.gc.keyboardControl = new KeyBoardControl(this.gc.stage);
         this.gc.bg1 = new FloorBg();
         if(this.gc.curStage == 9)
         {
            this.gc.bg1.gotoAndStop(3);
         }
         else
         {
            this.gc.bg1.gotoAndStop(this.gc.curStage);
         }
         this.root.addChild(this.gc.bg1);
         if(this.gc.gameMode == 1)
         {
            this.gc.maxMonsterPerScreen = 6;
         }
         else if(this.gc.gameMode == 2)
         {
            this.gc.maxMonsterPerScreen = 8;
         }
         this.gc.gameSence = new GameSence(param1,param2);
         AUtils.checkLoadOK(this.gc.gameSence,this.nextDoAfterLoad);
      }
      
      private function nextDoAfterLoad() : void
      {
         this.root.addChild(this.gc.gameSence);
         this.gc.gameInfo = new GameInfo();
         this.root.addChild(this.gc.gameInfo);
         this.gc.pWorld.pWorldStart();
         if(this.gc.hero1)
         {
            this.gc.pWorld.heroArray.push(this.gc.hero1);
            this.gc.gameSence.addChild(this.gc.hero1);
            this.gc.keyboardControl.setRole1(this.gc.hero1);
            this.gc.vControllor.setRole1(this.gc.hero1);
            this.gc.hero1.upGrade(this.gc.hero1.roleProperies.getLevel());
            this.gc.hero1.x = 200;
            this.gc.hero1.y = 200;
         }
         if(this.gc.hero2)
         {
            this.gc.pWorld.heroArray.push(this.gc.hero2);
            this.gc.gameSence.addChild(this.gc.hero2);
            this.gc.keyboardControl.setRole2(this.gc.hero2);
            this.gc.vControllor.setRole2(this.gc.hero2);
            this.gc.hero2.upGrade(this.gc.hero2.roleProperies.getLevel());
            if(this.gc.gameMode != Config.MODE3)
            {
               this.gc.hero2.x = 300;
            }
            else
            {
               this.gc.hero2.x = 750;
            }
            this.gc.hero2.y = 200;
         }
         if(!this.root.hasEventListener(Event.ENTER_FRAME))
         {
            this.root.addEventListener(Event.ENTER_FRAME,this.__enterFrame);
         }
         if(this.gc.curStage > 4)
         {
            SoundManager.play("stage4");
         }
         else
         {
            SoundManager.play("stage" + this.gc.curStage);
         }
      }
      
      private function __enterFrame(param1:Event) : void
      {
         if(this.gc.isStopGame)
         {
            return;
         }
         this.gc.pWorld.step();
         this.updateOther();
         this.setFource();
      }
      
      public function updateOther() : void
      {
         var _loc1_:uint = uint(this.gc.otherList.length);
         while(_loc1_-- > 0)
         {
            this.gc.otherList[_loc1_].step();
         }
      }
      
      private function setFource() : void
      {
         if(this.root.stage.focus != this.root)
         {
            this.root.stage.focus = this.root.stage;
         }
      }
      
      public function gameOver() : void
      {
         var _loc1_:uint = uint(this.gc.getPlayerArray().length);
         if(_loc1_ == 1)
         {
            if(this.gc.hero1.isDead())
            {
               this.destroyGame();
               this.gc.eventManger.dispatchEvent(new CommonEvent("GameOver"));
            }
         }
         else if(Boolean(this.gc.hero1.isDead()) && Boolean(this.gc.hero2.isDead()))
         {
            this.destroyGame();
            this.gc.eventManger.dispatchEvent(new CommonEvent("GameOver"));
         }
      }
   }
}
