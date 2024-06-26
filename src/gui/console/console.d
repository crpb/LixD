module gui.console.console;

/* A console is a box with text lines.
 * There's a LobbyConsole that draws a frame and has lines in medium text.
 * There's an ingame console with transparent bg and has lines in small text.
 */

import std.array;
import std.conv;
import std.math;

import basics.alleg5;
import basics.help;
import graphic.color;
import graphic.internal : getAlcol3DforStyle;
import gui;
import gui.console.line;
import net.style;

abstract class Console : Element {
private:
    Line[] _lines; // defined below in this module

public:
    this(Geom g) { super(g); }

    void add(in string textToPrint) { add(textToPrint, color.guiText); }
    void addWhite(in string textToPrint) { add(textToPrint, color.guiTextOn); }
    void add(in Style peerColor, in string textToPrint)
    {
        add(textToPrint, getAlcol3DforStyle(peerColor).textColor);
    }

    const(Line[]) lines() const { return _lines; }
    void lines(const(Line[]) aLines)
    {
        if (_lines.len) {
            foreach (ref line; _lines)
                rmChild(line.label);
            _lines = [];
        }
        foreach (old; aLines) {
            Line cloned = Line(old.label.text, lineFont,
                               old.label.color, this.xlg, lineYlg);
            cloned.birth = old.birth;
            addChild(cloned.label);
            _lines ~= cloned;
        }
        purgeAndMove();
        onLineChange();
    }

protected:
    abstract Alfont lineFont() const;
    abstract float lineYlg() const;
    abstract long ticksToLive() const;

    int maxLines() const { return ylg.to!int / lineYlg.floor.to!int;}
    int numLines() const { return _lines.len; }

    void onLineChange() { }
    void moveLine(ref Line line, int whichFromTop)
    {
        line.label.move(gui.thickg, whichFromTop * lineYlg);
    }

    override void workSelf() { purgeAndMove(); }

private:
    void add(in string textToPrint, in Alcol col)
    {
        foreach(ref l; LineFactory(textToPrint, lineFont, col, xlg, lineYlg)) {
            _lines ~= l;
            addChild(l.label);
        }
        purgeAndMove();
        onLineChange();
        reqDraw();
    }

    final void purgeAndMove()
    {
        while (_lines.length > 0 && (_lines.length > maxLines
                                || timerTicks > _lines[0].birth + ticksToLive)
        ) {
            rmChild(_lines[0].label);
            _lines = _lines[1 .. $];
            onLineChange();
            reqDraw();
        }
        foreach (const size_t i, ref line; _lines)
            moveLine(line, i.to!int);
    }
}

class LobbyConsole : Console {
private:
    Frame _frame;

public:
    this(Geom g)
    {
        super(g);
        _frame = new Frame(new Geom(0, 0, xlg, ylg));
        addChild(_frame);
    }

protected:
    override Alfont lineFont() const { return djvuM; }
    override float lineYlg() const { return 20; }
    override long ticksToLive() const { return 999_999_999; } // inf

    override void moveLine(ref Line line, int whichFromTop)
    {
        // This y-positioning looks better: Slightly more space at the top
        // and bottom, slightly less space between lines.
        line.label.move(gui.thickg, maxLines / 4f
                                    + (lineYlg - 0.5f) * whichFromTop);
    }

    override void drawSelf()
    {
        _frame.undraw(); // to clear the entire area before drawing text
    }
}

/* A transparent console. If stuff happens, maybe others should redraw.
 * We assume that everybody in the world must redraw! If you want fewer things
 * to redraw, redesign this class.
 *
 * Pass any ylg to this's geometry, doesn't matter.
 */
class TransparentConsole : Console {
public:
    this(Geom g)
    {
        g.yl = 0f;
        super(g);
    }

protected:
    override Alfont lineFont() const { return djvuS; }
    override int maxLines() const { return 8; }
    override float lineYlg() const { return 13; }
    override long ticksToLive() const { return 10 * 60; }

    override void onLineChange()
    {
        resize(xlg, numLines * lineYlg);
        // The global redraw call (or whatever you call here) should only
        // set a flag, not be expensive every time it's called. We might call
        // it several times within loops here.
        gui.requireCompleteRedraw();
    }
}
