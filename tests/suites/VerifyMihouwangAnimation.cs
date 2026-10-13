using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyMihouwangAnimation : Node
{
    private readonly List<string> _failures=new();
    private int _checks;
    private void Check(bool value,string text){++_checks;if(!value)_failures.Add(text);}
    public override async void _Ready()
    {
        Shuiliandong? level=null;
        try
        {
            level=GD.Load<PackedScene>("res://game/levels/shuiliandong.tscn").Instantiate<Shuiliandong>();
            level.enable_player_controls=false;AddChild(level);level.session.SetPhysicsProcess(false);level.flow.Call("stop");
            var boss=level.session.Call("spawn_entity_2d","monsters",new StringName("水帘洞弥猴王"),new Vector2(950,1234),new StringName(""),true).As<Node2D>();
            boss.Call("_finish_spawn_appearance");boss.Get("ai_controller").AsGodotObject().Set("enabled",false);
            var adapter=boss.Get("animation").AsGodotObject();
            var sprite=boss.GetNode<Node2D>("AnimationAdapter/SpineVisual");
            var data=sprite.Get("skeleton_data_res").AsGodotObject();
            Check(data.Call("is_skeleton_data_loaded").AsBool(),"新骨架在Spine 4.3原生运行时加载");
            Check(data.Call("get_fps").AsDouble()==60,"保留DragonBones原60fps");
            var json=Json.ParseString(FileAccess.GetFileAsString("res://assets/monsters/zaomeng1/mihou_king/spine_conversion.json")).AsGodotDictionary();
            var actions=json["source_actions"].AsGodotDictionary();
            Check(actions.Count==21 && json["nested_armatures"].AsInt32()==3,"21个原始动作和三个嵌套动画");
            Check(sprite.Scale==Vector2.One*3,"显示比例匹配Boss身高");
            var font=level.session.Get("presentation").As<Node>().GetNode<Label>("BossFeedback/HUD/BossBar/Name").GetThemeFont("font");
            Check(font.ResourcePath=="res://assets/ui/fonts/huakang_haibao_w12.ttf","共享Boss姓名采用华康海报体W12");
            foreach(char glyph in "弥猴王玉石琵琶精")Check(font.HasChar(glyph),"姓名字体包含："+glyph);
            bool capture=System.Array.Exists(OS.GetCmdlineUserArgs(),a=>a=="--capture-mihouwang");
            // Prevent the authored idle AnimationPlayers from overwriting a
            // direct native source-clip preview during the render callback.
            boss.ProcessMode=ProcessModeEnum.Disabled;
            if(capture){level.camera.Position+=new Vector2(0,240);level.camera.ForceUpdateScroll();}
            // Source clips have no gameplay AnimationPlayer binding. Preview
            // them on a native sprite without the idle-bound SpineAnimationTrack.
            var preview=ClassDB.Instantiate("SpineSprite").As<Node2D>();
            preview.Set("skeleton_data_res",data);preview.Set("update_mode",2);
            preview.Position=boss.GlobalPosition;preview.Scale=sprite.Scale;
            level.AddChild(preview);sprite.Visible=false;
            var state=preview.Call("get_animation_state").AsGodotObject();
            var skeleton=preview.Call("get_skeleton").AsGodotObject();
            skeleton.Call("set_skin",data.Call("find_skin","基础"));
            Rect2? firstBounds=null;bool varyingPoses=false;
            foreach(var key in actions.Keys)
            {
                string name=key.AsString();double duration=actions[key].AsDouble();
                var entry=state.Call("set_animation",name,false,0).AsGodotObject();
                Check(entry!=null && data.Call("find_animation",name).AsGodotObject()!=null,"原动作完整："+name);
                foreach(double fraction in new[]{0.0,0.35,0.7})
                {
                    entry!.Call("set_track_time",duration*fraction);preview.Call("update_skeleton",0.0);
                    Rect2 bounds=skeleton.Call("get_bounds").AsRect2();
                    Check(float.IsFinite(bounds.Size.X)&&float.IsFinite(bounds.Size.Y)&&bounds.Size.X>0&&bounds.Size.Y>0,"动作可见且矩阵有效："+name+"/"+fraction);
                    if(firstBounds==null)firstBounds=bounds;
                    else varyingPoses|=!firstBounds.Value.IsEqualApprox(bounds);
                }
                if(capture)
                {
                    await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath($"res://.cleanup-backup/mihouwang-{name}.png"));
                }
            }
            Check(varyingPoses,"源动作实际改变骨骼姿态，而非停留在待机");
            preview.Free();sprite.Visible=true;boss.ProcessMode=ProcessModeEnum.Inherit;
            skeleton=sprite.Call("get_skeleton").AsGodotObject();
            VerifyEffects(boss,adapter,actions);
            foreach(string action in new[]{"attack1","attack2","attack3","attack4","skill1","skill2","skill3"})
            {
                double duration=actions[action].AsDouble();
                Check(Math.Abs(adapter.Call("get_action_duration",new StringName(action)).AsDouble()-duration)<0.00001,"技能使用源动作原始时长："+action);
                adapter.Call("play_action",new StringName(action),true);
                var start=adapter.Call("get_visual_bounds_global").AsRect2();
                adapter.Call("advance_animation",duration*.5/boss.GetNode<AnimationPlayer>("AnimationAdapter/AnimationPlayer").SpeedScale);
                Check(!start.IsEqualApprox(adapter.Call("get_visual_bounds_global").AsRect2()),"游戏动作时间轴实际驱动新骨架："+action);
                if(capture)
                {
                    await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                    await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                    GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath($"res://.cleanup-backup/mihouwang-game-{action}.png"));
                }
            }
            adapter.Call("play_action",new StringName("idle"),true);sprite.Call("update_skeleton",0.0);
            Rect2 idle=adapter.Call("get_visual_bounds_global").AsRect2();
            Check(idle.Size.Y>210 && idle.Size.Y<350,"新Boss脚底对齐且身高合理："+idle);
            adapter.Call("set_facing",-1);sprite.Call("update_skeleton",0.0);
            Check(skeleton.Call("get_scale_x").AsDouble()==-1,"原生镜像适配仍然正确");
            boss.Set("super_armor",true);adapter.Call("advance_status_visuals",0.1);
            var armor=boss.GetNode<Node>("AnimationAdapter/SuperArmorEffect");
            Check(armor.Get("active").AsBool(),"新骨架仍可使用独立霸体彩色描边");
            Check(armor.GetNode<Node>("Capture/Body").Get("skeleton_data_res").AsGodotObject()==data,"描边使用新猕猴王骨架");
            if(capture)
            {
                await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
                await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
                GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/mihouwang-hud.png"));
            }
        }
        catch(Exception error){_failures.Add(error.ToString());}
        finally{if(IsInstanceValid(level))level!.Free();}
        await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
        foreach(string error in _failures)GD.PushError(error);
        if(_failures.Count==0)GD.Print($"PASS Mihouwang animation: {_checks} checks; 21 source clips, ten native effects, original FPS/timing, seek/reset/tails, mirroring and W12 Boss font");
        GetTree().Quit(_failures.Count==0?0:1);
    }

    private void VerifyEffects(Node boss,GodotObject adapter,Dictionary actions)
    {
        var root=boss.GetNode<Node2D>("AnimationAdapter/AttackEffects");
        var metadata=Json.ParseString(FileAccess.GetFileAsString("res://assets/effects/mihouwang/conversion.json")).AsGodotDictionary()["effects"].AsGodotDictionary();
        Check(root.GetChildCount()==7 && metadata.Count==10,"七组伴随特效及三组独立弹道特效，无运行时创建节点");
        var master=(AnimationPlayer)adapter.Call("get_animation_player").AsGodotObject();
        foreach(var key in metadata.Keys)
        {
            string name=key.AsString();var info=metadata[key].AsGodotDictionary();
            string action=info["action"].AsString();double start=info["start_frame"].AsDouble()/60;
            double length=info["actions"].AsGodotDictionary()["build"].AsDouble();
            var effect=action is "skill1" or "runattack" ? boss.GetNode<Node2D>("Projectiles/Slot0/Native/"+name) : root.GetNode<Node2D>(name);var data=effect.Get("skeleton_data_res").AsGodotObject();
            Check(data.Call("is_skeleton_data_loaded").AsBool(),"特效骨架加载："+name);
            Check(data.Call("get_fps").AsDouble()==info["fps"].AsDouble(),"特效保留原24/60FPS："+name);
            Check(Math.Abs(data.Call("find_animation","build").AsGodotObject().Call("get_duration").AsDouble()-length)<.00001,"原始build时长："+name);
            if(action is "skill1" or "runattack")
            {
                adapter.Call("play_action",new StringName(action),true);adapter.Call("advance_animation",.4);
                Check(!root.HasNode(name),"发射型特效不再占用人物特效节点："+name);
                continue;
            }
            adapter.Call("play_action",new StringName(action),true);
            Check(effect.Visible==(start==0),"起手按绑定帧显示："+name);
            double time=Math.Min(start+Math.Min(length*.5,.125),actions[action].AsDouble()-.001);
            adapter.Call("advance_animation",time/master.SpeedScale);
            var entry=effect.Call("get_animation_state").AsGodotObject().Call("get_track",0).AsGodotObject();
            Check(effect.Visible && entry!=null,"技能帧正确附加特效："+name);
            if(entry!=null)Check(Math.Abs(entry.Call("get_track_time").AsDouble()-(time-start))<.0001,"局部特效时钟正确："+name);
            var bounds=effect.Call("get_skeleton").AsGodotObject().Call("get_bounds").AsRect2();
            Check(bounds.Size.X>10 && bounds.Size.Y>10 && float.IsFinite(bounds.Size.X),"实际特效附件矩阵有效："+name);
            adapter.Call("set_facing",-1);Check(root.Scale.X==-3,"特效和偏移统一镜像："+name);
            adapter.Call("set_facing",1);
            master.Seek(0,true);adapter.Call("_apply_player_pose");
            Check(effect.Visible==(start==0),"向后拖动时间轴不继承未来特效："+name);
            adapter.Call("play_action",new StringName("idle"),true);
            foreach(Node2D other in root.GetChildren())
                Check(!other.Visible && other.Call("get_animation_state").AsGodotObject().Call("get_track",0).AsGodotObject()==null,"待机清理特效："+name+"/"+other.Name);
        }
        adapter.Call("play_action",new StringName("skill2"),true);adapter.Call("advance_animation",29.0/60/master.SpeedScale);
        Check(root.GetNode<Node2D>("skill2").Visible,"二技能主体隐藏段仍显示原特效");
        adapter.Call("play_action",new StringName("skill3"),true);adapter.Call("advance_animation",100.0/60/master.SpeedScale);
        Check(root.GetNode<Node2D>("skill3").Visible,"三技能主体隐藏段仍显示原龙卷风");
        adapter.Call("play_action",new StringName("skill3"),true);adapter.Call("advance_animation",1);
        adapter.Call("play_action",new StringName("hurt"),true);
        foreach(Node2D effect in root.GetChildren())Check(!effect.Visible,"受击不遗留特效："+effect.Name);
    }
}
