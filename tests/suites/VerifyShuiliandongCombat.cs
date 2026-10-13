using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyShuiliandongCombat : Node
{
    private Shuiliandong _level=null!;
    private Node _session=null!;
    private CharacterBody2D _player=null!,_boss=null!;
    private readonly List<string> _failures=new();
    private int _checks;
    private void Check(bool value,string message){++_checks;if(!value)_failures.Add(message);}
    private async Task Tick(int count=1)
    {
        for(int i=0;i<count;++i)
        {
            await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);_session.Call("advance_physics",1.0/60);
            await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
        }
    }
    public override async void _Ready()
    {
        try{await Run();}catch(Exception e){_failures.Add(e.ToString());}
        finally{if(IsInstanceValid(_level))_level.Free();}
        await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
        foreach(var error in _failures)GD.PushError(error);
        if(_failures.Count==0)GD.Print($"PASS Shuiliandong combat: {_checks} checks; native seven attacks, edited scene geometry affects damage, instance isolation, mirroring, pause, cleanup and native AI skills");
        GetTree().Quit(_failures.Count==0?0:1);
    }
    private async Task Run()
    {
        _level=GD.Load<PackedScene>("res://game/levels/shuiliandong.tscn").Instantiate<Shuiliandong>();_level.enable_player_controls=false;AddChild(_level);
        _session=_level.session;_player=_level.player;_session.SetPhysicsProcess(false);_level.flow.Call("stop");
        foreach(var gate in _level.GetNode("BattleSession/Actors/Gates").GetChildren())gate.Call("set_locked",false);
        await VerifyIslandUndersideAndWater();
        await TraverseTerrain();
        var attrs=_player.Get("attributes").AsGodotObject();attrs.Call("set_base_value",new StringName("hpMax"),100000.0);
        attrs.Call("get_vital",new StringName("health")).AsGodotObject().Call("set_current_value",100000.0);_player.Set("super_armor",true);
        _boss=_session.Call("spawn_entity_2d","monsters",new StringName("水帘洞弥猴王"),new Vector2(800,1234),new StringName(""),true).As<CharacterBody2D>();
        _boss.Call("_finish_spawn_appearance");_boss.Get("ai_controller").AsGodotObject().Set("enabled",false);
        _player.Position=new(850,1234);await Tick(50);
        var authoring=_boss.GetNode<BattleAttackRangeEditor2D>("AnimationAdapter/AttackRanges");
        Check(!authoring.Visible,"运行时隐藏编辑框且不生成额外伤害Area");
        Check(!_boss.HasNode("Projectile") && !_boss.HasNode("Guard"),"移除造1旧弹道和旋转无敌规则");
        foreach(string action in new[]{"attack1","attack2","attack3","attack4","skill1","skill2","skill3"})
        foreach(int facing in new[]{1,-1})
        {
            _boss.Position=new(800,1234);_boss.Velocity=Vector2.Zero;
            _boss.Get("motion").As<BattleMotionController2D>().clear_impulse();
            _player.Position=new(800+facing*150,1234);_player.Velocity=Vector2.Zero;
            _player.Get("motion").As<BattleMotionController2D>().clear_impulse();
            await Tick(20);
            _boss.Get("animation").AsGodotObject().Call("set_facing",facing);
            if(action=="jumpattack")
            {
                Check(_boss.Call("try_jump").AsBool(),"空中攻击先通过角色跳跃接口进入腾空状态");
            }
            if(action=="runattack")_boss.Get("action_state").AsGodotObject().Call("enter",6,new Dictionary());
            double before=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
            Check(_boss.Call("try_activate_skill",new StringName("mihouwang_"+action),new Dictionary { ["skip_cooldown"] = true }).AsBool(),$"原始动作{action}朝向{facing}实际施放");
            var cast=_boss.Get("attack_instance").AsGodotObject();
            for(int i=0;i<300;++i)
            {
                _player.Position=new(_boss.Position.X+facing*150,1234);_player.Velocity=Vector2.Zero;
                await Tick();
            }
            Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()<before,$"{action}镜像方向实际扣血");
            Check(!cast.Get("active").AsBool() && cast.Get("windows").AsGodotDictionary().Count==0,"攻击结束无旧攻击框残留");
            if(action == "skill3")Check(cast.Get("hit_count").AsInt32()>1,"多段技能共享窗口并按间隔重复命中："+action);
        }
        // Edit the exact scene handle used in Godot, then verify real HP rather
        // than merely comparing serialized rectangles.
        var range=authoring.GetNode<BattleEditableAttackRange2D>("attack1");
        var shape=range.GetNode<CollisionShape2D>("CollisionShape2D");
        var rectangle=(RectangleShape2D)shape.Shape;
        var originalPosition=shape.Position;var originalSize=rectangle.Size;
        _boss.Position=new(800,1234);_boss.Get("animation").AsGodotObject().Call("set_facing",1);
        _player.Position=new(950,1234);await Tick(30);
        var originalRuntimeRect=Segment(_boss).Get("hit_rect").AsRect2();
        var originalTemplateRect=range.skill_definition!.Get("features").AsGodotArray()[1].As<Resource>().Get("attack_segments").AsGodotArray()[0].As<Resource>().Get("hit_rect").AsRect2();
        shape.Position=new(950,-100);rectangle.Size=new(20,20);
        Check(authoring.apply_to_actor(_boss),"场景修改可应用到实际技能副本");
        double missedBefore=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_attack1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"移开判定框后施放");
        await Tick(40);
        Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()==missedBefore,"移开判定框后不再造成伤害");
        var other=_session.Call("spawn_entity_2d","monsters",new StringName("水帘洞弥猴王"),new Vector2(1600,1234),new StringName(""),true).As<Node>();
        other.Get("ai_controller").AsGodotObject().Set("enabled",false);
        Resource Segment(Node actor)
        {
            var instance=actor.Get("abilities").AsGodotObject().Call("get_ability_instance",new StringName("mihouwang_attack1")).AsGodotObject();
            var feature=instance.Call("get_definition").As<Resource>().Get("features").AsGodotArray()[1].As<Resource>();
            return feature.Get("attack_segments").AsGodotArray()[0].As<Resource>();
        }
        Check(Segment(other).Get("hit_rect").AsRect2()!=Segment(_boss).Get("hit_rect").AsRect2(),"调整一个Boss不会污染另一个Boss或资源模板");
        Check(Segment(other).Get("hit_rect").AsRect2()==originalRuntimeRect,"新Boss仍采用用户保存的实例范围");
        Check(range.skill_definition!.Get("features").AsGodotArray()[1].As<Resource>().Get("attack_segments").AsGodotArray()[0].As<Resource>().Get("hit_rect").AsRect2()==originalTemplateRect,"外部技能资源未被运行时改写");
        var otherRanges=other.GetNode<BattleAttackRangeEditor2D>("AnimationAdapter/AttackRanges");
        var unshifted=Segment(other).Get("hit_rect").AsRect2();
        otherRanges.Position=new Vector2(90,30);otherRanges.apply_to_actor(other);
        Check(Segment(other).Get("hit_rect").AsRect2().Position.IsEqualApprox(unshifted.Position+new Vector2(30,10)),"移动范围父节点同步改变实际判定位置");
        otherRanges.Position=Vector2.Zero;otherRanges.apply_to_actor(other);
        shape.Position=originalPosition;rectangle.Size=originalSize;authoring.apply_to_actor(_boss);
        double hitBefore=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_attack1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"恢复判定框后施放");
        await Tick(40);
        Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()<hitBefore,"恢复范围后实际伤害恢复");
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"特效尾帧实际技能起手");
        await Tick(68);
        var attackEffects=_boss.GetNode<Node2D>("AnimationAdapter/AttackEffects");
        var projectilePool=_boss.GetNode<MihouwangProjectilePool2D>("Projectiles");
        Check(!_boss.Get("attack_instance").AsGodotObject().Get("active").AsBool() && !attackEffects.HasNode("skill1"),"发射子弹不延长施法锁定或显示人物绑定特效");
        double tailHealth=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        await Tick(30);
        Check(!attackEffects.HasNode("skill1") && attrs.Call("get_vital_value",new StringName("health")).AsDouble()==tailHealth,"尾帧自动释放且不额外扣血");
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill3"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"原始长技能暂停验证起手");
        await Tick(10);var pausedCast=_boss.Get("attack_instance").AsGodotObject();
        double beforePause=pausedCast.Get("elapsed").AsDouble();
        var pausedEffect=attackEffects.GetNode<Node2D>("skill3");
        var pausedEntry=pausedEffect.Call("get_animation_state").AsGodotObject().Call("get_track",0).AsGodotObject();
        double effectTime=pausedEntry.Call("get_track_time").AsDouble();
        _session.Call("set_paused",true);await Tick(30);
        Check(pausedCast.Get("elapsed").AsDouble()==beforePause,"暂停冻结原动作和攻击窗口时钟");
        Check(pausedEffect.Visible && pausedEntry.Call("get_track_time").AsDouble()==effectTime,"暂停同时冻结技能特效时钟");
        _session.Call("set_paused",false);await Tick(300);
        await VerifyProjectiles();
        var controller=_boss.Get("ai_controller").AsGodotObject();controller.Set("enabled",true);
        for(int i=0;i<1500;++i){_player.Position=new(_boss.Position.X+150,1234);_player.Velocity=Vector2.Zero;await Tick();}
        var chosen=controller.Get("selected_skills").AsGodotArray();
        Check(chosen.Contains(new StringName("mihouwang_skill3")),"近距离Boss AI能选择旋风技能");
        controller.Set("enabled",false);
        _session.Call("despawn_entity",_boss.Get("entity_id"));await Tick(2);
        Check(!IsInstanceValid(authoring),"Boss退出释放编辑数据与战斗节点");
    }
    private async Task VerifyProjectiles()
    {
        var pool=_boss.GetNode<MihouwangProjectilePool2D>("Projectiles");
        var attrs=_player.Get("attributes").AsGodotObject();
        MihouwangProjectile2D Active()
        {
            foreach(MihouwangProjectile2D slot in pool.GetChildren())if(slot.active)return slot;
            throw new Exception("No active projectile");
        }
        async Task Setup(float distance=700)
        {
            _boss.Call("cancel_skill");pool.clear_projectiles();
            _boss.Position=new(800,1234);_boss.Velocity=Vector2.Zero;
            _boss.Get("motion").As<BattleMotionController2D>().clear_impulse();
            _boss.Get("animation").AsGodotObject().Call("set_facing",1);
            _player.Position=new(800+distance,1234);_player.Velocity=Vector2.Zero;
            _player.Get("motion").As<BattleMotionController2D>().clear_impulse();await Tick(5);
        }
        Check(pool.skill1_native_probability==.5 && pool.GetChildCount()==6,"skill1默认50%概率且预置六个弹道槽");
        await Setup();pool.skill1_native_probability=1;
        double before=attrs.Call("get_vital_value",new StringName("health")).AsDouble();int spawned=pool.spawn_count;
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"新子弹技能实际激活");
        await Tick(17);Check(pool.spawn_count==spawned && attrs.Call("get_vital_value",new StringName("health")).AsDouble()==before,"发射前无子弹/近战伤害");
        await Tick(2);var shot=Active();
        Check(pool.spawn_count==spawned+1 && shot.variant=="skill1","第14帧仅发射一枚新子弹");
        var start=shot.GlobalPosition;
        _boss.Position=new(300,1234);_boss.Get("animation").AsGodotObject().Call("set_facing",-1);
        await Tick(40);
        Check(shot.active && shot.GlobalPosition.X>start.X+400 && shot.GlobalPosition.Y==start.Y,"人物移动/转身不改变已发射子弹轨迹");
        Check(Mathf.IsEqualApprox(shot.GetNode<Node2D>("Native").Scale.X,3*Mathf.Abs(_boss.GlobalScale.X)),"已发射子弹保持发射朝向及角色比例");
        Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()<before,"新子弹可伤害原近战框外的远处人物");
        if(System.Array.Exists(OS.GetCmdlineUserArgs(),a=>a=="--capture-projectiles"))
        {
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/mihouwang-skill1-projectile.png"));
        }
        double hitHealth=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        await Tick(80);Check(!shot.active && attrs.Call("get_vital_value",new StringName("health")).AsDouble()==hitHealth,"新子弹结束释放且不重复扣血");
        var range=_boss.GetNode<BattleEditableAttackRange2D>("AnimationAdapter/AttackRanges/skill1");
        var shape=range.GetNode<CollisionShape2D>("CollisionShape2D");var position=shape.Position;
        await Setup();shape.Position+=new Vector2(0,-1500);
        Check(_boss.GetNode<BattleAttackRangeEditor2D>("AnimationAdapter/AttackRanges").apply_to_actor(_boss),"子弹继续绑定原编辑框");
        before=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"移开子弹判定框后发射");
        await Tick(100);
        Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()==before,"移动编辑矩形改变实际远程命中");
        pool.skill1_native_probability=0;
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"造1子弹也使用编辑框的偏移");
        await Tick(120);
        Check(attrs.Call("get_vital_value",new StringName("health")).AsDouble()==before,"移开的范围同样使造1子弹无法命中");
        var feature=range.skill_definition!.Get("features").AsGodotArray()[1].As<Resource>();
        var template=feature.GetMeta("projectile_segment").As<Resource>();
        var instance=_boss.Get("abilities").AsGodotObject().Call("get_ability_instance",new StringName("mihouwang_skill1")).AsGodotObject();
        var runtime=instance.Call("get_definition").As<Resource>().Get("features").AsGodotArray()[1].As<Resource>().GetMeta("projectile_segment").As<Resource>();
        Check(template.Get("hit_rect").AsRect2()!=runtime.Get("hit_rect").AsRect2(),"修改子弹实例不污染外部技能资源");
        shape.Position=position;_boss.GetNode<BattleAttackRangeEditor2D>("AnimationAdapter/AttackRanges").apply_to_actor(_boss);
        await Setup();pool.skill1_native_probability=0;
        before=attrs.Call("get_vital_value",new StringName("health")).AsDouble();
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"造1子弹分支实际激活");
        await Tick(19);shot=Active();Check(shot.variant=="zaomeng1" && !shot.GetNode<Node2D>("Native").Visible,"造1分支只显示原子弹");
        await Tick(50);Check(shot.active && !_boss.Get("attack_instance").AsGodotObject().Get("active").AsBool(),"原子弹在施法结束后独立飞行");
        if(System.Array.Exists(OS.GetCmdlineUserArgs(),a=>a=="--capture-projectiles"))
        {
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/mihouwang-original-projectile.png"));
        }
        await Tick(60);
        Check(!shot.active && attrs.Call("get_vital_value",new StringName("health")).AsDouble()<before,"原子弹出回轨迹实际伤害并按原寿命回收");
        Check(_boss.Get("attack_instance").AsGodotObject().Get("hit_count").AsInt32()==2,"原子弹去程和回程各命中一次");
        await Setup(600);pool.skill1_native_probability=1;
        Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"子弹暂停起手");
        await Tick(19);shot=Active();
        var pausedPosition=shot.GlobalPosition;double pausedAge=shot.age;
        _session.Call("set_paused",true);await Tick(20);
        Check(shot.GlobalPosition==pausedPosition && shot.age==pausedAge,"暂停冻结独立子弹位置及动画年龄");
        _session.Call("set_paused",false);await Tick(110);
        Check(!shot.active,"子弹按寿命回收");
        // Verify the exact deterministic random stream consumed by each real
        // cast; distributions alone cannot prove one draw per cast.
        var random=_session.Get("random").As<BattleRandom>();var saved=random.snapshot();
        var prediction=new BattleRandom();prediction.initialize(42);random.initialize(42);pool.skill1_native_probability=.5;
        int initialNative=pool.native_skill1_count,initialOriginal=pool.original_skill1_count,expectedNative=0;
        _player.Position=new(4500,800);
        for(int i=0;i<64;++i)
        {
            _boss.Call("cancel_skill");pool.clear_projectiles();
            _boss.Position=new(800,1234);_boss.Velocity=Vector2.Zero;
            bool expected=prediction.random_float("mihouwang_projectile")<.5;if(expected)++expectedNative;
            Check(_boss.Call("try_activate_skill",new StringName("mihouwang_skill1"),new Dictionary { ["skip_cooldown"] = true }).AsBool(),"随机技能真实起手："+i);
            int previous=pool.spawn_count;await Tick(19);
            Check(pool.spawn_count==previous+1 && pool.last_variant==(expected?"skill1":"zaomeng1"),"每次恰好一次50%随机且仅发射一种："+i);
        }
        Check(pool.native_skill1_count-initialNative==expectedNative && pool.original_skill1_count-initialOriginal==64-expectedNative && expectedNative>16 && expectedNative<48,"两个分支分别生效，概率使用原战斗随机流");
        _boss.Call("cancel_skill");pool.clear_projectiles();random.restore(saved);prediction.Dispose();
        Check(pool.GetChildCount()==6,"多次释放不增加弹道节点");
        await Setup(150);
    }
    private async Task VerifyIslandUndersideAndWater()
    {
        var motion=_player.Get("motion").As<BattleMotionController2D>();
        var profile=_player.Get("action_profile").As<Resource>();
        motion.horizontal_bounds_active=false;
        async Task Move(int frames,float speed)
        {
            for(int i=0;i<frames;++i)
            {
                await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);
                motion.advance(1.0/60,speed,profile,1);
            }
        }
        _player.Position=new(2600,1200);_player.Velocity=Vector2.Zero;motion.clear_impulse();
        await Move(30,0);
        int jumps=motion.jump_serial;
        await Move(90,600);
        Check(_player.Position.X>3200 && motion.grounded && motion.jump_serial==jumps,"截图处无需跳跃可从左侧走过悬空平台下方");
        await Move(90,-600);
        Check(_player.Position.X<2750 && motion.grounded && motion.jump_serial==jumps,"悬空平台下方反向行走不再碰空气墙");
        _player.Position=new(2939,850);_player.Velocity=Vector2.Zero;
        await Move(90,0);
        Check(motion.grounded && Mathf.Abs(_player.Position.Y-904.2f)<4,"移除空气墙后仍能落在原悬空平台上");
        foreach(float x in new[]{4300f,6500f})
        {
            _player.Position=new(x,1200);_player.Velocity=Vector2.Zero;motion.clear_impulse();
            await Move(90,0);
            Check(motion.grounded && Mathf.Abs(_player.Position.Y-1302.3f)<4,"落在可见水面上方而非水下旧碰撞："+_player.Position);
        }
        var artwork=_level.GetNode<Node2D>("BattleSession/Actors/Visuals/ShuiliandongVisual");
        Check(artwork.GetNode<Node2D>("ForegroundOccluders").ZIndex<artwork.GetNode<Node2D>("GroundArtwork").ZIndex && artwork.GetNode<Node2D>("ForegroundOccluders").ZIndex<_player.ZIndex,"水面绘制在地板和人物之后");
        _player.Position=new(256,1200);_player.Velocity=Vector2.Zero;
        if(System.Array.Exists(OS.GetCmdlineUserArgs(),a=>a=="--capture-water-surface"))
        {
            // The second region includes the screenshot's island underside.
            _player.Position=new(2800,1230);
            var rig=_session.Get("camera_rig").AsGodotObject();
            rig.Call("set_region_bounds",new Rect2(1880,0,1880,1400),true);
            await Tick(2);
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/water-island-underside.png"));
            _player.Position=new(4300,1302);
            rig.Call("set_region_bounds",new Rect2(3760,0,1880,1400),true);
            await Tick(2);
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/water-surface-preview.png"));
            _player.Position=new(256,1200);
        }
    }
    private async Task TraverseTerrain()
    {
        var motion=_player.Get("motion").As<BattleMotionController2D>();
        var profile=_player.Get("action_profile").As<Resource>();
        motion.horizontal_bounds_active=false;
        float speed=_player.Get("attributes").AsGodotObject().Call("get_value",new StringName("runSpeed")).AsSingle();
        int jumps=0;
        foreach(float destination in new[]{8460f,256f})
        {
            int direction=destination>_player.Position.X?1:-1;
            int frames=0;
            while(direction*(destination-_player.Position.X)>15 && frames++<4000)
            {
                await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);
                var from=_player.GlobalPosition+new Vector2(direction*100,-40);
                using var ray=PhysicsRayQueryParameters2D.Create(from,from+new Vector2(0,160),1,
                    new Godot.Collections.Array<Rid>{_player.GetRid()});
                bool ahead=_player.GetWorld2D().DirectSpaceState.IntersectRay(ray).Count>0;
                if((motion.grounded && (!ahead||motion.on_wall)) ||
                   (!motion.grounded && _player.Velocity.Y>0 && !ahead && motion.jumps_used<2))
                    if(motion.jump(profile))++jumps;
                motion.advance(1.0/60,speed*direction,profile,1);
            }
            Check(frames<4000 && _player.Position.Y<1600,
                $"实体地形可连续奔跑/两段跳抵达{destination}，无传送：{_player.Position}");
        }
        Check(jumps>0,"地图实际通行经过跳跃平台或水面间隙");
    }
}
