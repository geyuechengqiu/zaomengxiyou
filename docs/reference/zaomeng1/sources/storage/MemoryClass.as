package storage
{
   import base.*;
   import com.hexagonstar.util.debug.*;
   import config.*;
   import flash.display.*;
   import flash.events.*;
   import flash.net.*;
   import flash.text.*;
   import flash.utils.*;
   import my.*;
   import user.*;
   
   public class MemoryClass
   {
       
      
      private var gc:Config;
      
      public var so:SharedObject;
      
      private var storage1:Object;
      
      private var storage2:Object;
      
      private var storage0:Object;
      
      private var saveIndex:uint;
      
      public function MemoryClass()
      {
         super();
         this.gc = Config.getInstance();
         registerClassAlias("my.MyEquipObj",MyEquipObj);
         registerClassAlias("user.User",User);
         this.so = SharedObject.getLocal("DreamWork_XYCS");
      }
      
      public function getStorage(param1:uint) : void
      {
         var _loc2_:* = this["storage" + param1];
         if(_loc2_)
         {
            this.gc.player1.setSaveObj(_loc2_.player1_obj);
            this.gc.player2.setSaveObj(_loc2_.player2_obj);
            this.gc.curBigLevel = uint(_loc2_.curBigLevel);
            this.gc.curBigStage = uint(_loc2_.curBigStage);
            if(_loc2_.gongxun != undefined)
            {
               this.gc.gongxun = int(_loc2_.gongxun);
            }
            if(_loc2_.cangetDHQF != undefined)
            {
               this.gc.cangetDHQF = Boolean(_loc2_.cangetDHQF);
            }
            else
            {
               this.gc.cangetDHQF = true;
            }
            if(_loc2_.cangetJGZ != undefined)
            {
               this.gc.cangetJGZ = Boolean(_loc2_.cangetJGZ);
            }
            else
            {
               this.gc.cangetJGZ = true;
            }
            if(_loc2_.lastDate != undefined)
            {
               if(_loc2_.lastDate != this.gc.curDate)
               {
                  this.gc.monster24RewardTimes = 0;
                  this.gc.zhuwei_1_times = 0;
                  this.gc.zhuwei_2_times = 0;
                  this.gc.zhuwei_3_times = 0;
               }
               else
               {
                  this.gc.monster24RewardTimes = int(_loc2_.monster24RewardTimes);
                  this.gc.zhuwei_1_times = int(_loc2_.zhuwei_1_times);
                  this.gc.zhuwei_2_times = int(_loc2_.zhuwei_2_times);
                  this.gc.zhuwei_3_times = int(_loc2_.zhuwei_3_times);
               }
            }
            if(this.gc.playNum == 1)
            {
               this.newRole(this.gc.player1.getControlPlayer() + 1,this.gc.player1.roleid);
            }
            if(this.gc.playNum == 2)
            {
               this.newRole(this.gc.player1.getControlPlayer() + 1,this.gc.player1.roleid);
               this.newRole(this.gc.player2.getControlPlayer() + 1,this.gc.player2.roleid);
            }
         }
      }
      
      private function newRole(param1:int, param2:int) : void
      {
         this.gc["hero" + param1] = AUtils.getNewObj("export.hero.Role" + param2) as BaseHero;
         this.gc["hero" + param1].x = 300;
         this.gc["hero" + param1].y = 100;
         this.gc["hero" + param1].name = param1 + "";
         this.gc["hero" + param1].setPlayer(this.gc["player" + param1]);
         this.gc["hero" + param1].roleProperies.setinitExper(User(this.gc["player" + param1]).protectedObject.curExp);
         this.gc["hero" + param1].roleProperies.setinitLevel(User(this.gc["player" + param1]).protectedObject.curLevel);
      }
      
      public function storageValue(param1:uint, param2:*) : void
      {
         this["storage" + param1] = param2;
         Debug.trace("storage   " + param1 + "  " + this["storage" + param1]);
         Debug.trace("data:" + param2);
      }
      
      public function judgeSave() : Boolean
      {
         if(this.gc.playNum == 1)
         {
            if(this.storage1 || this.storage0)
            {
               return true;
            }
         }
         else if(this.gc.playNum == 2)
         {
            if(this.storage2)
            {
               return true;
            }
         }
         return false;
      }
      
      public function searchSave(param1:uint) : Boolean
      {
         if(this["storage" + param1])
         {
            return true;
         }
         return false;
      }
      
      private function setSaveIndex() : void
      {
         if(this.gc.playNum == 1)
         {
            if(this.gc.hero1.roleName == "孙悟空")
            {
               this.saveIndex = 1;
            }
            else if(this.gc.hero1.roleName == "唐僧")
            {
               this.saveIndex = 0;
            }
         }
         else
         {
            this.saveIndex = 2;
         }
      }
      
      public function setStorage() : void
      {
         this.setSaveIndex();
         if(this.saveIndex == 1)
         {
            this.storage1 = {};
         }
         else if(this.saveIndex == 2)
         {
            this.storage2 = {};
         }
         else if(this.saveIndex == 0)
         {
            this.storage0 = {};
         }
         this["storage" + this.saveIndex].player1_obj = this.gc.player1.getSaveObj();
         this["storage" + this.saveIndex].player2_obj = this.gc.player2.getSaveObj();
         this["storage" + this.saveIndex].curBigStage = this.gc.curBigStage;
         this["storage" + this.saveIndex].curBigLevel = this.gc.curBigLevel;
         this["storage" + this.saveIndex].gongxun = this.gc.gongxun;
         this["storage" + this.saveIndex].lastDate = this.gc.curDate;
         this["storage" + this.saveIndex].cangetDHQF = this.gc.cangetDHQF;
         this["storage" + this.saveIndex].cangetJGZ = this.gc.cangetJGZ;
         this["storage" + this.saveIndex].monster24RewardTimes = this.gc.monster24RewardTimes;
         this["storage" + this.saveIndex].zhuwei_1_times = this.gc.zhuwei_1_times;
         this["storage" + this.saveIndex].zhuwei_2_times = this.gc.zhuwei_2_times;
         this["storage" + this.saveIndex].zhuwei_3_times = this.gc.zhuwei_3_times;
         this["storage" + this.saveIndex].playNum = this.gc.playNum;
         var _loc2_:String = String(JSON.stringify(this["storage" + this.saveIndex]));
         new FileReference().save(_loc2_,"");
      }
   }
}
