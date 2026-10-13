using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

// Keep this runner beside CurrentScene so the actual world-map/level scene
// transitions can be exercised rather than replaced with mocks.
public partial class VerifyCampaignTransitions : Node
{
    private readonly List<string> _failures=new();
    private int _checks;
    private void Check(bool value,string text){++_checks;if(!value)_failures.Add(text);}
    public override async void _Ready()
    {
        try{await Run();}catch(Exception e){_failures.Add(e.ToString());}
        foreach(var error in _failures)GD.PushError(error);
        if(_failures.Count==0)GD.Print($"PASS Campaign transitions: {_checks} checks; actual map -> flower victory -> result -> map -> water -> retry -> map, UI actions and persistent progress");
        GetTree().Quit(_failures.Count==0?0:1);
    }
    private async Task Frames(int count=1)
    {
        for(int i=0;i<count;++i)await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
    }
    private async Task<T> Scene<T>() where T:Node
    {
        for(int i=0;i<2400;++i)
        {
            await Frames();
            if(GetTree().CurrentScene is T scene && scene.IsNodeReady() && !StageLoadingScreen.LoadingStage)return scene;
        }
        throw new Exception("场景未按预期切换："+typeof(T).Name);
    }
    private async Task Run()
    {
        Check(OS.GetUserDataDir().Contains("campaign_transitions-user"),"场景切换测试使用隔离存档");if(_failures.Count>0)return;
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(ZaomengOneCampaign.SavePath));
        var campaign=GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign");campaign.LoadProgress();
        await Frames();GetTree().CurrentScene=null;
        Check(campaign.ReturnToMap(),"打开真实大地图");
        var map=await Scene<ZaomengOneWorldMap>();
        Check(map.GetNode<AudioStreamPlayer>("Music").Stream.ResourcePath == "res://assets/audio/zaomeng1/world_map.mp3" && map.GetNode<AudioStreamPlayer>("Music").Playing,"大地图保留造梦西游1原版音乐");
        var loading=campaign.GetLoadingScreen();
        bool? failed=null;
        var invalid=new Dictionary { ["scene"]="res://game/levels/huaguoshan.tscn", ["loading_manifest"]="res://data/missing-loading-manifest.json", ["loading_audio"]="res://data/levels/huaguoshan/audio.json" };
        Check(loading.Begin(invalid, success=>failed=success),"开始异常资源恢复验证");
        for(int i=0;i<120 && failed==null;++i)await Frames();
        Check(failed==false && loading.LastError.Length>0 && !GetTree().Paused && map.IsInsideTree(),"加载失败保持地图、恢复暂停状态并显示原因");
        loading.GetNode<Button>("Overlay/Dismiss").EmitSignal(Button.SignalName.Pressed);
        Check(!loading.GetNode<Control>("Overlay").Visible,"失败后可关闭加载面板并重试");
        var phases=new HashSet<string>();double previous=0;bool monotonic=true, frozen=true, captured=false;
        loading.PhaseChanged += OnPhase;
        void OnPhase(string description,double progress)
        {
            if(progress==0)previous=0;
            monotonic &= progress>=previous && progress<=100;previous=progress;phases.Add(description);
            if(progress==96 && GetTree().CurrentScene is BattleLevelScene current)
                frozen &= GetTree().Paused && current.session.Get("clock").AsGodotObject().Get("paused").AsBool() && !current.player.Get("operations").AsGodotObject().Get("enabled").AsBool();
            if(progress==88 && !captured && System.Array.Exists(OS.GetCmdlineUserArgs(), arg=>arg=="--loading-capture")) {captured=true;Capture();}
        }
        async void Capture()
        {
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            using var image=GetViewport().GetTexture().GetImage();image.SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/stage-loading.png"));
        }
        Check(map.GetNodeOrNull("Selection")==null,"地图没有二级窗口");
        map.GetNode<TextureButton>("Stages/Stage_1_1").EmitSignal(Button.SignalName.Pressed);
        Check(loading.IsLoading && loading.GetNode<Control>("Overlay").Visible && UiModalManager.Top==loading.GetNode<Control>("Overlay"),"点击关卡立即显示遮罩加载界面");
        Check(!map.SelectLevel("1-1"),"重复按键只提交一次场景切换");
        var flower=await Scene<Huaguoshan>();flower.enable_player_controls=false;flower.player.Get("operations").As<Node>().Set("enabled",false);flower.session.SetPhysicsProcess(false);
        Check(loading.DisplayedProgress==100 && loading.WarmedVisualCount>=4,"Tween缓动到100%且角色及所有怪物画面已预热后进入关卡");
        Check(loading.GetNode("WarmupViewport/Visuals").GetChildCount()==0,"加载预热节点释放，不残留虚拟怪物或战斗实体");
        Check(flower.GetNode("BattleSession/BattlePresentation/DamageNumbers/Rows").Get("created_count").AsInt32()>=128 && flower.GetNode("BattleSession/BattlePresentation").Get("feedback_created").AsInt32()==8,"战斗数字与反馈对象池在加载界面完成预分配");
        Check(monotonic && frozen && loading.Progress==100 && phases.Count>=8,"实际资源进度单调、包含初始化阶段，完成前冻结战斗和输入");
        Check(!loading.GetNode<Control>("Overlay").Visible && !GetTree().Paused && !flower.session.Get("clock").AsGodotObject().Get("paused").AsBool(),"初始化完成才隐藏界面并恢复战斗");
        Check(loading.GetNode<TextureRect>("Overlay/Title").Texture is AtlasTexture title && title.Region==new Rect2(0,0,301,146),"加载标题仅包含造梦西游online，排除上古天帝篇副标题");
        var attrs=flower.player.Get("attributes").AsGodotObject();attrs.Call("set_level",3);attrs.Call("set_experience",22.0);
        flower.player.Get("inventory").As<Node>().Call("set_display_name","跨关卡悟空");
        foreach(var rv in flower.flow.Get("regions").AsGodotArray())
        {
            var region=rv.AsGodotObject();var entry=region.Get("definition").AsGodotObject().Get("entry_rect").AsRect2();
            flower.player.Position=new(entry.GetCenter().X,950);flower.player.Velocity=Vector2.Zero;
            int ticks=0;
            while(!region.Get("completed").AsBool()&&ticks++<2200)
            {
                foreach(var value in flower.session.Call("get_entities").AsGodotArray())
                {
                    var actor=value.As<Node>();if(actor==flower.player||!actor.Call("is_alive").AsBool())continue;
                    actor.Call("_finish_spawn_appearance");actor.Get("ai_controller").AsGodotObject().Set("enabled",false);
                    flower.session.Call("apply_secondary_damage",actor,flower.player,10000000.0,new StringName("verification"),new Dictionary());
                }
                await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);flower.session.Call("advance_physics",1.0/60);
            }
            Check(region.Get("completed").AsBool(),"实际场景的区域完成");
            if(flower.flow.Get("current_region_index").AsInt32()<4)
            {
                flower.player.Position=new(region.Get("definition").AsGodotObject().Get("exit_rect").AsRect2().GetCenter().X,950);
                Check(flower.flow.Call("request_exit",flower.player,false).AsBool(),"实际场景区域推进");
            }
        }
        for(int i=0;i<420;++i){await ToSignal(GetTree(),SceneTree.SignalName.PhysicsFrame);flower.session.Call("advance_physics",1.0/60);}
        flower.player.Position=flower.GetNode<BattleFinalExit2D>("BattleSession/Actors/FinalExit").get_exit_rect().GetCenter();
        Check(flower.flow.Call("request_exit",flower.player,false).AsBool(),"确认光效实际通关");
        Check(campaign.CanEnter("1-2")&&flower.GetNode<Control>("HUD/CampaignResult/Overlay").Visible,"根场景自动记录通关并显示结果面板");
        flower.GetNode<Button>("HUD/CampaignResult/Overlay/Panel/Return").EmitSignal(Button.SignalName.Pressed);
        map=await Scene<ZaomengOneWorldMap>();Check(!IsInstanceValid(flower),"返回地图释放原关卡");
        Check(!map.GetNode<TextureButton>("Stages/Stage_1_2").Disabled,"新地图立即刷新解锁状态");
        Check(map.GetNode<Control>("Stages/Stage_1_2/Glow").Visible && !map.GetNode<Control>("Stages/Stage_1_1/Glow").Visible,"解锁后只有最新解锁关卡使用Godot发光");
        map.GetNode<TextureButton>("Stages/Stage_1_2").EmitSignal(Button.SignalName.Pressed);
        var water=await Scene<Shuiliandong>();
        Check(water.player.Get("inventory").As<Node>().Get("display_name").AsString()=="跨关卡悟空"&&water.player.Get("attributes").AsGodotObject().Get("current_level").AsInt32()>=3,"真实水帘洞启动恢复角色数据");
        ulong old=water.GetInstanceId();water.GetNode<Button>("HUD/Restart").EmitSignal(Button.SignalName.Pressed);await Frames(4);
        water=await Scene<Shuiliandong>();Check(water.GetInstanceId()!=old,"重开创建独立关卡实例");
        Check(water.player.Get("inventory").As<Node>().Get("display_name").AsString()=="跨关卡悟空","重开保留角色信息");
        water.menu.Call("set_open",true);
        water.menu.GetNode<BaseButton>("Main/Map").EmitSignal(Button.SignalName.Pressed);
        await Scene<ZaomengOneWorldMap>();Check(!campaign.IsUnlocked("1-3"),"中途返回不解锁第三关");
        loading.PhaseChanged -= OnPhase;
    }
}
