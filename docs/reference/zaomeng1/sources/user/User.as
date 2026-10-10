package user
{
   import config.*;
   import my.*;
   
   public class User
   {
      
      public static var batterNum:int;
       
      
      internal var gc:Config;
      
      public var controlPlayer:int;
      
      public var protectedObject:Object;
      
      public var roleid:uint = 1;
      
      public var tarray:Array;
      
      public var zblist:Array;
      
      public var djlist:Array;
      
      public var rwlist:Array;
      
      public var curarray:Array;
      
      public var propsArray:Array;
      
      public var isstudyskill:Array;
      
      public var ispassiveskill:Array;
      
      public var saveObj:Object;
      
      private var curEquipType:Array;
      
      public function User()
      {
         this.protectedObject = {
            "lhValue":0,
            "myscore":0,
            "curLevel":1,
            "curExp":0
         };
         this.tarray = [];
         this.zblist = [];
         this.djlist = [];
         this.rwlist = [];
         this.curarray = [];
         this.propsArray = [];
         this.isstudyskill = [0,0,0,0,0];
         this.ispassiveskill = [0,0,0,0,0];
         this.saveObj = {};
         super();
         this.gc = Config.getInstance();
         if(this.gc.isYourFather)
         {
            this.isstudyskill = [1,1,1,1,1];
         }
      }
      
      public function init(param1:uint) : *
      {
         this.controlPlayer = param1;
      }
      
      public function getControlPlayer() : int
      {
         return this.controlPlayer;
      }
      
      public function getEquipNum() : Object
      {
         var _loc3_:MyEquipObj = null;
         var _loc1_:Object = {
            "zbfj":1,
            "zbwq":1
         };
         var _loc2_:uint = uint(this.curarray.length);
         while(_loc2_-- > 0)
         {
            _loc3_ = this.curarray[_loc2_];
            if(this.curarray[_loc2_].type == "zbfj")
            {
               _loc1_.zbfj = _loc3_.showid;
            }
            else if(this.curarray[_loc2_].type == "zbwq")
            {
               _loc1_.zbwq = _loc3_.showid;
            }
         }
         return _loc1_;
      }
      
      public function getBagEquipSaveString() : String
      {
         var _loc1_:* = "";
         var _loc2_:uint = uint(this.zblist.length);
         while(_loc2_-- > 0)
         {
            if(this.zblist[_loc2_])
            {
               _loc1_ += MyEquipObj(this.zblist[_loc2_]).getEquipSaveObj();
               if(_loc2_ != 0)
               {
                  _loc1_ += "}";
               }
            }
         }
         return _loc1_;
      }
      
      public function getCurEquipSaveString() : String
      {
         var _loc1_:* = "";
         var _loc2_:uint = uint(this.curarray.length);
         while(_loc2_-- > 0)
         {
            _loc1_ += MyEquipObj(this.curarray[_loc2_]).getEquipSaveObj();
            if(_loc2_ != 0)
            {
               _loc1_ += "}";
            }
         }
         return _loc1_;
      }
      
      public function getSaveObj() : Object
      {
         this.saveObj.controlPlayer = this.controlPlayer;
         this.saveObj.lhValue = this.protectedObject.lhValue;
         this.saveObj.myscore = this.protectedObject.myscore;
         this.saveObj.curExp = this.protectedObject.curExp;
         this.saveObj.curLevel = this.protectedObject.curLevel;
         this.saveObj.roleid = this.roleid;
         this.saveObj.tarray = this.tarray;
         this.saveObj.djlist = this.djlist;
         this.saveObj.rwlist = this.rwlist;
         this.saveObj.propsArray = this.propsArray;
         this.saveObj.isstudyskill = this.isstudyskill;
         this.saveObj.ispassiveskill = this.ispassiveskill;
         this.saveObj.bagSaveString = this.getBagEquipSaveString();
         this.saveObj.curSaveString = this.getCurEquipSaveString();
         return this.saveObj;
      }
      
      public function setSaveObj(param1:Object) : void
      {
         var _loc2_:uint = 0;
         var _loc3_:MyEquipObj = null;
         var _loc4_:Array = null;
         var _loc5_:uint = 0;
         var _loc6_:MyEquipObj = null;
         var _loc7_:String = null;
         var _loc8_:String = null;
         var _loc9_:int = 0;
         var _loc10_:int = 0;
         this.zblist = [];
         this.curarray = [];
         this.curEquipType = ["zbwq","zbfj","zbsp","zbfb"];
         this.controlPlayer = param1.controlPlayer;
         this.protectedObject.lhValue = param1.lhValue;
         this.protectedObject.myscore = param1.myscore;
         this.protectedObject.curExp = param1.curExp;
         this.protectedObject.curLevel = param1.curLevel;
         this.roleid = param1.roleid;
         this.tarray = param1.tarray;
         this.djlist = param1.djlist;
         this.rwlist = param1.rwlist;
         if(param1.bagSaveString != undefined)
         {
            _loc7_ = String(param1.bagSaveString);
            if(_loc7_.charAt(_loc7_.length - 1) == "}")
            {
               _loc7_ = String(_loc7_.substr(0,_loc7_.length - 2));
            }
            _loc2_ = uint((_loc4_ = _loc7_.split("}")).length);
            while(_loc2_-- > 0)
            {
               if(_loc4_[_loc2_] != "")
               {
                  _loc3_ = new MyEquipObj();
                  _loc3_.setEquipSaveObj(_loc7_.split("}")[_loc2_]);
                  this.zblist.push(_loc3_);
               }
            }
         }
         else
         {
            _loc2_ = uint(param1.zbarr.length);
            while(_loc2_-- > 0)
            {
               _loc3_ = new MyEquipObj();
               _loc3_.setOldEquipSaveObj(param1.zbarr[_loc2_]);
               this.zblist.push(_loc3_);
            }
         }
         if(param1.curSaveString != undefined)
         {
            _loc8_ = String(param1.curSaveString);
            if(_loc8_.charAt(_loc8_.length - 1) == "}")
            {
               _loc8_ = String(_loc8_.substr(0,_loc8_.length - 2));
            }
            _loc5_ = uint((_loc4_ = _loc8_.split("}")).length);
            _loc9_ = 0;
            while(_loc9_ < _loc5_)
            {
               if(_loc4_[_loc9_] != "")
               {
                  (_loc6_ = new MyEquipObj()).setEquipSaveObj(_loc8_.split("}")[_loc9_]);
                  if(this.curEquipType.length > 0)
                  {
                     if(_loc6_.type)
                     {
                        if((_loc10_ = int(this.curEquipType.indexOf(_loc6_.type))) != -1)
                        {
                           this.curarray.push(_loc6_);
                           this.curEquipType.splice(_loc10_,1);
                        }
                        else
                        {
                           this.zblist.push(_loc6_);
                        }
                     }
                  }
               }
               _loc9_++;
            }
         }
         else
         {
            _loc5_ = uint(param1.curarr.length);
            while(_loc5_-- > 0)
            {
               (_loc6_ = new MyEquipObj()).setOldEquipSaveObj(param1.curarr[_loc5_]);
               this.curarray.push(_loc6_);
            }
         }
         this.propsArray = param1.propsArray;
         this.isstudyskill = param1.isstudyskill;
         this.ispassiveskill = param1.ispassiveskill;
      }
   }
}
