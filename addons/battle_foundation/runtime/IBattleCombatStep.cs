/// <summary>Authored effects that run after all actors move, on the battle clock.</summary>
public interface IBattleCombatStep
{
    void advance_combat(double delta);
}
