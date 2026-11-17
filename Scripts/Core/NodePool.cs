using System;
using System.Collections.Generic;
using Godot;

namespace PigeonRush.Core;

/// <summary>
/// Pool di nodi riutilizzabili: niente Instantiate/QueueFree durante la partita.
/// I nodi restano nel tree, nascosti quando liberi.
/// </summary>
public sealed class NodePool<T> where T : Node3D
{
    private readonly List<T> _free = new();
    private readonly Func<T> _factory;
    private readonly Node _parent;

    public NodePool(Node parent, Func<T> factory, int prewarm)
    {
        _parent = parent;
        _factory = factory;
        for (var i = 0; i < prewarm; i++)
            _free.Add(Create());
    }

    public T Get()
    {
        T item;
        if (_free.Count > 0)
        {
            item = _free[^1];
            _free.RemoveAt(_free.Count - 1);
        }
        else
        {
            item = Create();
        }

        item.Visible = true;
        return item;
    }

    public void Release(T item)
    {
        item.Visible = false;
        _free.Add(item);
    }

    private T Create()
    {
        var item = _factory();
        item.Visible = false;
        _parent.AddChild(item);
        return item;
    }
}
