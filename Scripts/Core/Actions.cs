using Godot;

namespace PigeonRush.Core;

/// <summary>Nomi delle input action in cache (evita allocazioni di StringName nel game loop).</summary>
public static class Actions
{
    public static readonly StringName MoveLeft = "move_left";
    public static readonly StringName MoveRight = "move_right";
    public static readonly StringName MoveUp = "move_up";
    public static readonly StringName MoveDown = "move_down";
    public static readonly StringName Poop = "poop";
    public static readonly StringName Pause = "pause";

    /// <summary>Registra le action via codice: tastiera, frecce e gamepad.</summary>
    public static void EnsureRegistered()
    {
        if (InputMap.HasAction(Poop))
            return; // già registrate (es. dopo ReloadCurrentScene)

        AddKeys(MoveLeft, Key.A, Key.Left);
        AddAxis(MoveLeft, JoyAxis.LeftX, -1f);
        AddButton(MoveLeft, JoyButton.DpadLeft);

        AddKeys(MoveRight, Key.D, Key.Right);
        AddAxis(MoveRight, JoyAxis.LeftX, 1f);
        AddButton(MoveRight, JoyButton.DpadRight);

        AddKeys(MoveUp, Key.W, Key.Up);
        AddAxis(MoveUp, JoyAxis.LeftY, -1f);
        AddButton(MoveUp, JoyButton.DpadUp);

        AddKeys(MoveDown, Key.S, Key.Down);
        AddAxis(MoveDown, JoyAxis.LeftY, 1f);
        AddButton(MoveDown, JoyButton.DpadDown);

        AddKeys(Poop, Key.Space, Key.J);
        AddButton(Poop, JoyButton.A);
        AddAxis(Poop, JoyAxis.TriggerRight, 1f);

        AddKeys(Pause, Key.Escape, Key.P);
        AddButton(Pause, JoyButton.Start);
    }

    private static void Ensure(StringName action)
    {
        if (!InputMap.HasAction(action))
            InputMap.AddAction(action, 0.25f);
    }

    private static void AddKeys(StringName action, params Key[] keys)
    {
        Ensure(action);
        foreach (var key in keys)
            InputMap.ActionAddEvent(action, new InputEventKey { PhysicalKeycode = key });
    }

    private static void AddAxis(StringName action, JoyAxis axis, float value)
    {
        Ensure(action);
        InputMap.ActionAddEvent(action, new InputEventJoypadMotion { Axis = axis, AxisValue = value });
    }

    private static void AddButton(StringName action, JoyButton button)
    {
        Ensure(action);
        InputMap.ActionAddEvent(action, new InputEventJoypadButton { ButtonIndex = button });
    }
}
