package config
{
   import PhysicsWorlds.PhysicsWorld;
   import base.BaseHero;
   import event.*;
   import export.*;
   import flash.display.MovieClip;
   import flash.display.Stage;
   import flash.net.LocalConnection;
   import flash.utils.Timer;
   import my.*;
   import storage.*;
   import user.*;
   
   public class Config
   {
      
      internal static var instance:Config;
      
      public static var MODE1:int = 1;
      
      public static var MODE2:int = 2;
      
      public static var MODE3:int = 3;
       
      
      public var memory:MemoryClass;
      
      public var opening:Boolean = false;
      
      public var eventManger:AEventDispatcher;
      
      public var playNum:uint;
      
      public var hero1:BaseHero;
      
      public var hero2:BaseHero;
      
      public var player1:User;
      
      public var player2:User;
      
      public var gameSence:GameSence;
      
      public var gameInfo:GameInfo;
      
      public var pWorld:PhysicsWorld;
      
      public var bg1:FloorBg;
      
      public var bg2:MovieClip;
      
      public var stage:Stage;
      
      public var isStopGame:Boolean = false;
      
      public var vControllor:ViewControllor;
      
      public var keyboardControl:KeyBoardControl;
      
      public var allEquip:AllEquipment;
      
      public var otherList:Array;
      
      public var isHideDebug:Boolean = true;
      
      public var isYourFather:Boolean = false;
      
      public var curBigStage:uint = 1;
      
      public var curBigLevel:uint = 1;
      
      public var lc:LocalConnection;
      
      public var playerName:String;
      
      public var logInfo:Object;
      
      public var isFirstLogin:Boolean = true;
      
      public var loginAlert:MovieClip;
      
      public var lastSubmitScore:int;
      
      public var usernameHash:String = "";
      
      public var huodong61Flag:Boolean = false;
      
      public var ts:Infomation;
      
      public var num1:int = 1;
      
      public var num2:int = 2;
      
      public var num5:int = 3;
      
      public var num7:int = 7;
      
      public var num3:int = 3;
      
      public var num6:int = 6;
      
      public var num4:int = 4;
      
      public var num8:int = 8;
      
      public var num9:int = 9;
      
      public var num0:int = 0;
      
      public var curLevel:uint = 1;
      
      public var curStage:uint = 4;
      
      public var isLevelClear:Boolean = false;
      
      public var maxMonsterPerScreen:int = 8;
      
      public var gameMode:int;
      
      public var saveIntervelCount:int;
      
      public var saveTimer:Timer;
      
      public var logInfoTimer:Timer;
      
      public var sdList:Array;
      
      public var curDate:String = "";
      
      public var MONSTER24_PER_DAY_TIMES:int = 1;
      
      public var ZHUWEI_1_PER_DAY_TIMES:int = 1;
      
      public var ZHUWEI_2_PER_DAY_TIMES:int = 1;
      
      public var ZHUWEI_3_PER_DAY_TIMES:int = 1;
      
      public var monster24Reward:int = 50;
      
      public var cangetDHQF:Boolean = true;
      
      public var cangetJGZ:Boolean = true;
      
      public var gongxun:int = 0;
      
      public var zhuwei_1_times:int = 0;
      
      public var zhuwei_2_times:int = 0;
      
      public var zhuwei_3_times:int = 0;
      
      public var monster24RewardTimes:int = 0;
      
      private var getTimeCb:Function;
      
      public function Config()
      {
         this.eventManger = new AEventDispatcher();
         this.allEquip = new AllEquipment();
         this.otherList = new Array();
         this.ts = new Infomation();
         this.sdList = new Array();
         super();
         if(!instance)
         {
            instance = this;
            this.initData();
         }
      }
      
      public static function getInstance() : Config
      {
         return instance;
      }
      
      public function initData() : void
      {
         this.hero1 = null;
         this.hero2 = null;
         this.player1 = new User();
         this.player1.controlPlayer = 0;
         this.player2 = new User();
         this.player2.controlPlayer = 1;
         this.curBigLevel = 1;
         this.curBigStage = 1;
         this.memory = new MemoryClass();
         this.gongxun = 0;
         this.zhuwei_1_times = 0;
         this.zhuwei_2_times = 0;
         this.zhuwei_3_times = 0;
         this.monster24RewardTimes = 0;
         this.cangetDHQF = true;
         this.cangetJGZ = true;
         this.allEquip.initHouDong(10);
         this.sdList.length = 0;
         this.sdList.push(this.allEquip.findByName("tndbthl"));
         this.sdList.push(this.allEquip.findByName("tndblg"));
         this.sdList.push(this.allEquip.findByName("zcld"));
         this.sdList.push(this.allEquip.findByName("hjsl"));
      }
      
      public function getGameTime(param1:*) : void
      {
         var _loc2_:Date = null;
         trace("===获取时间===");
         this.getTimeCb = param1;
         _loc2_ = new Date();
         this.curDate = _loc2_.getFullYear() + "-" + (_loc2_.getMonth() + 1) + "-" + _loc2_.getDate();
         trace("单机 this.curDate:" + this.curDate);
         this.getTimeCb();
      }
      
      public function showFloatTip(param1:String) : void
      {
         var _loc2_:Infomation = new Infomation();
         _loc2_.setTxt(param1);
         this.stage.addChild(_loc2_);
      }
      
      public function onGetServerTime(param1:*) : void
      {
         if(param1 == "")
         {
            this.ts.setTxt("获取时间失败！请刷新网页");
            this.stage.addChild(this.ts);
            return;
         }
         var _loc2_:Array = param1.split(" ");
         this.curDate = _loc2_[0];
         trace("联机 this.curDate:" + this.curDate);
         if(this.getTimeCb)
         {
            this.getTimeCb();
         }
      }
      
      public function destroyGame() : void
      {
         this.otherList = [];
         this.isLevelClear = false;
      }
      
      public function isFb() : Boolean
      {
         return this.curStage == 9 && this.curLevel == 1;
      }
      
      public function isFb1() : Boolean
      {
         return this.curStage == 9 && this.curLevel == 1;
      }
      
      public function getPlayerArray() : Array
      {
         var _loc1_:Array = [];
         if(this.hero1)
         {
            _loc1_.push(this.hero1);
         }
         if(this.hero2)
         {
            _loc1_.push(this.hero2);
         }
         return _loc1_;
      }
   }
}
