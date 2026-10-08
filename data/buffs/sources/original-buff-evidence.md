# 阶段10原版源码证据

以下为只读节选；行号针对原仓库完整文件，不能作为独立脚本运行。

## exports/zmhj_character_state_control/sources/com/wdcgame/engine/model/buff/BuffManager.as

SHA256: `b2e0492f25f8e88c4d4f85a20270df172fc170e73823397599096c38732dadc7`

原文件第 267–284 行：

```actionscript

      public function getEntityBuffByBuffConfig(param1:IBuff, param2:BuffConfigVO) : BuffVO
      {
         var _loc4_:BuffVO = null;
         var _loc3_:* = null;
         var _loc6_:int = 0;
         var _loc5_:Vector.<BuffVO> = getEntityBuffs(param1);
         _loc6_ = 0;
         while(_loc6_ < _loc5_.length)
         {
            if((_loc4_ = _loc5_[_loc6_]) && _loc4_.config.group == param2.group && _loc4_.config.attributeT == param2.attributeT)
            {
               _loc3_ = _loc4_;
               break;
            }
            _loc6_++;
         }
         return _loc3_;
```

原文件第 453–519 行：

```actionscript
            {
               return;
            }
         }
         else if(_loc17_.replaceRule == 1)
         {
            if(_loc20_)
            {
               delBuff(_loc20_);
            }
         }
         else if(_loc17_.replaceRule == 2)
         {
            if(_loc20_)
            {
               if(_loc20_.nowTime >= _loc17_.totalTime)
               {
                  return;
               }
               delBuff(_loc20_);
            }
         }
         else if(_loc17_.replaceRule != 3)
         {
            if(_loc17_.replaceRule == 4)
            {
               _loc20_ = getEntityBuffByBuffConfigStack(param3,_loc17_);
            }
            else if(_loc17_.replaceRule == 5)
            {
               _loc20_ = getEntityBuffByBuffConfigStack(param3,_loc17_);
            }
            else if(_loc17_.replaceRule == 7)
            {
               _loc20_ = getEntityBuffByBuffConfigStack(param3,_loc17_);
            }
            else if(_loc17_.replaceRule == 8 || _loc17_.replaceRule == 81)
            {
               _loc20_ = getEntityBuffByBuffConfigStack(param3,_loc17_);
            }
            else if(_loc17_.replaceRule == 6)
            {
               if(_loc20_)
               {
                  SimpleTextLog.getIns().log2("oldBuff.currentTime=" + _loc20_.currentTime);
                  _loc20_.nowTime -= _loc17_.totalTime;
                  _loc20_.currentTime -= _loc17_.totalTime;
                  return;
               }
            }
            else if(_loc17_.replaceRule == 61)
            {
               if(_loc20_)
               {
                  if(!_loc20_.data)
                  {
                     _loc20_.data = {"num":0};
                  }
                  if(_loc20_.data.num >= _loc17_.stackMax)
                  {
                     return;
                  }
                  SimpleTextLog.getIns().log2("oldBuff.currentTime=" + _loc20_.currentTime,_loc17_.id,_loc17_.name);
                  _loc20_.nowTime -= _loc17_.totalTime;
                  _loc20_.currentTime -= _loc17_.totalTime;
                  _loc20_.data.num += 1;
                  if(_loc17_.childrens && _loc17_.childrens.length > 0)
```

原文件第 626–689 行：

```actionscript
         _loc18_.param = param6;
         _loc18_.otherData = param7;
         if(_loc17_.isIntervalDelay == false)
         {
            _loc18_.nowTime = _loc18_.interval;
         }
         if(param5)
         {
            if(param5.id)
            {
               _loc18_.sceneBuffId = param5.id;
            }
            if(param5.nowTime)
            {
               _loc18_.nowTime = param5.nowTime;
            }
            if(param5.totalTime)
            {
               _loc18_.totalTime = param5.totalTime;
               if(_loc18_.totalTime == -1)
               {
                  _loc18_.isForever = true;
               }
            }
            if(param5.resourceId)
            {
               _loc17_.resourceId = param5.resourceId;
            }
         }
         if(_loc17_.replaceRule == 4)
         {
            if(_loc20_)
            {
               _loc20_.addChildren(_loc18_);
               _loc18_.value = 0;
               _loc20_.Rest();
               if(_loc20_.value == undefined || isNaN(_loc20_.value))
               {
                  _loc20_.value = 0;
               }
               param3.updateStackBuff(_loc20_);
               _loc20_.RestTotalTime();
               _loc20_.interval = 0;
               if(_loc20_.config.isImmediate)
               {
                  _loc20_.advanceTime(GameFrame.PerTime);
               }
               return;
            }
         }
         else if(_loc17_.replaceRule == 5)
         {
            if(_loc20_)
            {
               _loc20_.addChildren(_loc18_);
               _loc18_.value = 0;
               _loc20_.RestTotalTime();
               return;
            }
         }
         else if(_loc17_.replaceRule == 7)
         {
            if(_loc20_)
            {
```

## exports/zmhj_character_state_control/sources/com/wdcgame/engine/model/buff/BuffVO.as

SHA256: `b38752ed26486b696df1550e9db3089b6ca15d60289eefee982f155674dc1a15`

原文件第 122–191 行：

```actionscript
         {
            this.nowTime += param1;
            this.currentTime += param1;
            this.totalTime -= param1;
            if(this.nowTime >= this.interval)
            {
               this.nowTime -= this.interval;
               if(this.interval == 0 && this.config.totalTime > 0)
               {
                  this.interval = this.totalTime * 2;
               }
               if(this.receiveEntity)
               {
                  this.receiveEntity.updateBuffVo(this);
               }
            }
            _tempTime += param1;
            if(_tempTime >= 1)
            {
               _tempTime -= 1;
            }
            if(this.totalTime <= 0)
            {
               this.Deleted = true;
            }
         }
         else
         {
            if((this.replaceRule == 8 || this.replaceRule == 81) && this.childrens && this.childrens.length > 0)
            {
               updateChildren(param1);
            }
            this.nowTime += param1;
            this.currentTime += param1;
            if(this.nowTime >= this.interval)
            {
               this.nowTime -= this.interval;
               this.totalTime -= this.interval;
               if(this.interval == 0 && this.config.totalTime > 0)
               {
                  this.interval = this.totalTime * 2;
               }
               if(this.receiveEntity)
               {
                  _loc3_ = [230018,230019,190052,190053,804510];
                  _loc2_ = int(String(this.config.id).slice(0,6));
                  if(_loc3_.indexOf(_loc2_) > -1)
                  {
                     this.receiveEntity.updateStackBuff(this);
                  }
                  this.receiveEntity.updateBuffVo(this);
               }
            }
            if(this.nowTime >= this.totalTime)
            {
               this.Deleted = true;
            }
         }
      }

      private function updateChildren(param1:Number) : void
      {
         var _loc4_:int = 0;
         var _loc2_:BuffVO = null;
         _loc4_ = 0;
         _loc2_ = null;
         var _loc3_:* = -1;
         _loc4_ = 0;
         while(_loc4_ < childrens.length)
         {
```

## out/zmhj-equip-skill-diag/prefabs/scripts/ManEntity.as

SHA256: `e3dcfcc236578a9cf6953db22c6f7bae6297fa98ccf0a603e8054f6f38bb4bad`

原文件第 2365–2385 行：

```actionscript
            }
            param1.value = MathUtils.decimal(param1.value,2);
            _loc3_ = -param1.value;
            this.userVo.updatePropertyByBuff(_loc3_,"atkDmgRate");
            SimpleTextLog.getIns().log2("updateStackBuff atkDmgRate=",param1.id,param1.value,this.userVo.getBuffProperty("atkDmgRate"));
            param1.value = 0;
         }
         else if(param1.config.type == 8)
         {
            if(param1.config.attributeT == "allResist")
            {
               _loc3_ = -param1.value;
               _loc7_ = 1;
               while(_loc7_ < ResistType.Types.length)
               {
                  this.userVo.updatePropertyByBuff(_loc3_,ResistType.Types[_loc7_]);
                  _loc7_++;
               }
               param1.value = 0;
            }
            else
```

原文件第 2846–2872 行：

```actionscript
               _loc45_.updatePropertyByBuff(_loc55_,param1.config.attributeT);
            }
            else if(param1.config.attributeT == "mp")
            {
               _loc55_ = param1.config.attributeV1 * this.userVo.allmpMax + param1.config.attributeV3;
               param1.value += _loc55_;
               this.userVo.updateMp(_loc55_,false,"buff" + param1.config.id);
               if(param1.config.showValueOnHead)
               {
                  CommandModelManager.showAddHpNumber(this,_loc55_,param1.config.numOffset);
               }
            }
            else if(param1.config.attributeT == "mpMax")
            {
               _loc55_ = param1.config.attributeV1 * this.userVo.allmpMax + param1.config.attributeV3;
               param1.value += _loc55_;
               _loc45_.updatePropertyByBuff(_loc55_,param1.config.attributeT);
            }
            else if(param1.config.attributeT == "atk")
            {
               _loc55_ = param1.config.attributeV1 * this.userVo.allatk + param1.config.attributeV3;
               param1.value += _loc55_;
               _loc4_ = _loc55_;
               if(param1.childrens && param1.childrens.length > 0 && param1.config.stackMax > 0)
               {
                  _loc34_ = 0;
                  while(_loc34_ < param1.childrens.length)
```

原文件第 3371–3443 行：

```actionscript
         else if(param1.config.type == 5)
         {
            if(param1.config.attributeT == "hp")
            {
               if(isNaN(param1.config.attributeV3))
               {
                  param1.config.attributeV3 = 0;
               }
               _loc55_ = param1.config.attributeV1 * _loc45_.allhpMax + param1.config.attributeV2 * _loc45_.allatk + param1.config.attributeV3;
               SimpleTextLog.getIns().log3(QCOnServerFrame.cliCurrFrame,"CHI_XI_SHANG_HAI",_loc55_,param1.config.attributeV1,_loc45_.allhpMax,param1.config.attributeV2,_loc45_.allatk,param1.config.attributeV3);
               if(this.userVo.isQc || this.userVo.isPk || this.userVo.isPvP)
               {
                  if(this.userVo.isPetPk)
                  {
                     _loc55_ *= CommonConfig.petpkHpMaxQualificationIndex;
                  }
                  else if(this.userVo.isPetBrawl)
                  {
                     _loc55_ *= CommonConfig.petBattleHpMaxQualificationIndex;
                  }
                  else if(this.userVo.isPvP2)
                  {
                     if(param1.config.isMulPVPreHp)
                     {
                        _loc55_ *= CommonConfig.PVP2reHpQualificationIndex;
                     }
                  }
                  else if(this.userVo.isPvP || this.userVo.isQc || this.userVo.isPk)
                  {
                     if(param1.config.isMulPVPreHp)
                     {
                        _loc55_ *= CommonConfig.PVPreHpQualificationIndex;
                     }
                  }
                  else
                  {
                     _loc55_ *= CommonConfig.pkHpMaxQualificationIndex;
                  }
               }
               if((_loc55_ = int(_loc55_)) > 0)
               {
                  _loc55_ = this.userVo.getHpValue(_loc55_);
               }
               param1.value += _loc55_;
               _loc30_ = _loc55_;
               if(_loc55_ < 0)
               {
                  _loc30_ = -_loc55_;
                  if(_loc55_ + this.userVo.hp < 0)
                  {
                     _loc30_ -= this.userVo.hp;
                  }
               }
               if(this.userVo.isWorldBoss == true && _loc55_ < 0)
               {
                  if(_loc58_ && _loc58_.userVo == this.userVo)
                  {
                     ApplicationFacade.getInstance().sendNotification("CMD_WORLD_BODD_SEND_DAMGE",{"damage":_loc55_});
                  }
               }
               this.userVo.updateHP(_loc55_,false,"CHI_XI_SHANG_HAI" + param1.config.id);
               SimpleTextLog.getIns().log3(QCOnServerFrame.cliCurrFrame,"CHI_XI_SHANG_HAI",_loc55_);
               if(_loc55_ < 0)
               {
                  GameFrame.battleModelManager.logPetPk(_loc38_,_loc30_);
               }
               if(param1.config.showValueOnHead)
               {
                  CommandModelManager.showAddHpNumber(this,_loc55_,param1.config.numOffset);
               }
               if(this.userVo.isPvP || this.userVo.isQc)
               {
                  if(_loc55_ < 0)
```

原文件第 3621–3648 行：

```actionscript
         else if(param1.config.type == 21)
         {
            _loc5_ = _loc55_ = param1.config.attributeV1;
            if(param1.childrens && param1.childrens.length > 0)
            {
               _loc34_ = 0;
               while(_loc34_ < param1.childrens.length)
               {
                  if(param1.childrens[_loc34_].config.type == 21)
                  {
                     _loc5_ += param1.childrens[_loc34_].config.attributeV1;
                  }
                  _loc34_++;
               }
            }
            if(_loc45_.getBuffProperty(param1.config.attributeT) + _loc5_ < -1)
            {
               _loc5_ = -1 - _loc45_.getBuffProperty(param1.config.attributeT);
            }
            param1.value += _loc5_;
            _loc45_.updatePropertyByBuff(_loc5_,param1.config.attributeT);
            _loc59_ = this;
         }
         else if(param1.config.type == 23)
         {
            _loc4_ = param1.attributeV3;
            if(param1.childrens && param1.childrens.length > 0)
            {
```

## exports/zmhj_damage_formulas/sources/prefabs/controls/DamageControl.as

SHA256: `2775e78eb9b167670c22598f6fea92bc7d13d5700ac3c23d34d6164f602b3764`

原文件第 914–940 行：

```actionscript
            {
               _loc64_ = 1;
            }
            this.damageLittleReal *= _loc64_;
            _loc132_ = BuffManager.getIns().getBuffByType(_loc134_,81);
            _loc5_ = true;
            if(ManEntity(_loc52_) && ManEntity(_loc52_).summonSkill)
            {
               _loc5_ = false;
               if(_loc52_.userVo && _loc52_.userVo.configVo && _loc52_.userVo.configVo.boss == 1 || _loc52_.userVo && _loc52_.userVo.configVo && _loc52_.userVo.configVo.bySuckBleed)
               {
                  _loc5_ = true;
               }
            }
            if(_loc132_ && _loc132_.config.validSkills && _loc5_)
            {
               _loc5_ = _loc132_.config.validSkills.indexOf(String(this.skill.skillConfig.id)) > -1;
            }
            if(_loc132_ && _loc5_ && _loc114_)
            {
               if(_loc132_.config.triggerNum > 0 && skill.addBuff81 < _loc132_.config.triggerNum * skill.atkMax || _loc132_.config.triggerNum < 1)
               {
                  skill.addBuff81++;
                  _loc55_ = this.skill.skillConfig.GetSkillDefault() + this.skill.skillConfig.skillAdd * (this.skill.skillConfig.getRealLevel() - 1);
                  _loc76_ = _loc132_.config.attributeV1 * (_loc116_.value + this.damageLittleReal);
                  _loc118_ = _loc55_ * _loc132_.config.attributeV2;
                  if(_loc132_.config.isMulPVPreHp)
```

原文件第 1756–1800 行：

```actionscript
            _loc35_ = Number(EntityBase(_loc52_).userVo.getBuffProperty("fangShang"));
            _loc53_ = _loc52_.GetFansShangByBuff(_loc134_);
            _loc99_ = (_loc35_ += _loc53_[0]) * (this.damage + this.damageLittleReal);
            if((_loc84_ = Number(_loc53_[1])) > 0)
            {
               if(_loc99_ > _loc52_.userVo.allatk * _loc84_)
               {
                  _loc99_ = _loc52_.userVo.allatk * _loc84_;
               }
            }
            _loc117_ = _loc52_.GetFansShangByBuff2(_loc134_,skill);
            if(skill.notTriggerFangsan152)
            {
               _loc117_ = 0;
            }
            _loc99_ += _loc117_;
            if(_loc134_.userVo && _loc134_.userVo.configVo && _loc134_.userVo.configVo.superMan)
            {
               _loc99_ = 0;
            }
            if(skill.skillConfig.owner == "weaponSpirit")
            {
               _loc99_ = 0;
            }
            if(_loc134_.isRealWuDi())
            {
               _loc99_ = 0;
            }
            if(_loc99_ > 0)
            {
               if(_loc134_.userVo.isUnionBoss == false && _loc134_.userVo.isWorldBoss == false)
               {
                  _loc66_ = _loc99_;
                  if(_loc99_ > _loc134_.userVo.hp)
                  {
                     _loc99_ = _loc134_.userVo.hp;
                  }
                  _loc134_.onDamage(-_loc99_);
                  _loc134_.CalHurtDamage(_loc99_);
                  GameFrame.battleModelManager.logPetPk(_loc52_.userVo,_loc66_);
               }
               (_loc41_ = new AttackInfoVO(_loc134_.GetPosition().clone(),_loc134_.GetPosition().clone(),_loc99_,_loc116_.type,_loc134_.userVo,_loc134_.userVo)).bleedPos = new Point(_loc41_.hurtPos.x,_loc41_.hurtPos.y - 60);
               _loc41_.bleedPos = BScene(GameFrame.scene).localToGlobal(_loc41_.bleedPos);
               _loc41_.damage_double = _loc116_.damage_double;
               if(!_loc134_.userVo.configVo.bleedOffset)
```

## out/zmhj-equip-skill-diag/com/wdcgame/engine/model/UserVOBase.as

SHA256: `60909e954e33558532dd10799e25b0373a85a57697740e982f7ccd8f9af706a8`

原文件第 612–629 行：

```actionscript
      public function updateHP(param1:Number, param2:Boolean, param3:String) : void
      {
         if(isDie || this.useHurtNum > 0)
         {
            return;
         }
         hp += param1;
         if(hp >= hpMax)
         {
            hp = hpMax;
         }
         else if(hp <= 0)
         {
            hp = 0;
            isDie = true;
         }
      }

```
