module menu.outcome.single;

/*
 * A full-screen outcome of a singleplayer game.
 *
 * Presents the next level, and the next unsolved level if it differs,
 * and offers to go back to the singleplayer browser.
 */

import std.algorithm;

import optional;

import file.filename;
import file.language;
import file.nextlev;
import file.trophy;
import file.option.allopts;
import gui;
import game.harvest;
import menu.preview.base;
import menu.outcome.trotable;
import menu.preview.fullprev;

struct NextLevel {
    Level level;
    Filename fn;
}

class SinglePlayerOutcome : Window {
private:
    TrophyTable _trophyTable;
    FullPreview _oldLevel;
    NextLevelButton[] _offeredLevels;
    TextButton _gotoBrowser;

    // Singleton, refactor with TrophyCase into some kitchen sink object
    static TreeLevelCache _cache = null;

public:
    enum ExitWith {
        notYet,
        gotoLevel,
        gotoBrowser,
    }

    this(in Harvest harvest)
    {
        super(new Geom(0, 0, gui.screenXlg, gui.screenYlg),
            harvest.level.name);

        _trophyTable = new TrophyTable(new Geom(20, 40,
            xlg - 60f - nextLevelXlg, 160));
        _trophyTable.addJustPlayed(harvest.trophy);
        addChild(_trophyTable);

        _oldLevel = new FullPreview(new Geom(20, 40, nextLevelXlg, 160,
            From.TOP_RIGHT));
        _oldLevel.preview(harvest.level);
        addChild(_oldLevel);
        _gotoBrowser = new TextButton(new Geom(0, 20, 300, 20, From.BOTTOM),
            Lang.outcomeExitToSingleBrowser.transl);
        _gotoBrowser.hotkey = keyMenuExit;
        addChild(_gotoBrowser);

        if (_cache is null) {
            _cache = new TreeLevelCache();
        }
        foreach (oldFn; harvest.replay.levelFilename) {
            foreach (old; _cache.rhinoOf(oldFn)) {
                foreach (tro; old.trophy) {
                    _trophyTable.addOld(tro);
                }
                offerUpToTwoLevels(old);
            }
        }
        // ...and only after above rendering the trophies, improve.
        if (harvest.singleplayerHasWon
            && harvest.replay.wasPlayedBy(file.option.userName)
        ) {
            maybeImprove(harvest.trophyKey, harvest.trophy);
        }
    }

    void dispose()
    {
        _oldLevel.dispose();
        foreach (but; _offeredLevels) {
            but.dispose();
        }
    }

    ExitWith exitWith() const pure nothrow @safe @nogc
    {
        if (_gotoBrowser.execute) {
            return ExitWith.gotoBrowser;
        }
        else if (_offeredLevels.any!(button => button.execute)) {
            return ExitWith.gotoLevel;
        }
        return ExitWith.notYet;
    }

    NextLevel nextLevel()
    in {
        assert (exitWith == ExitWith.gotoLevel,
            "Don't ask for which level if we aren't going to a level");
    }
    do {
        // find will return nonempty array because of the in contract
        auto next = _offeredLevels[].find!(but => but.execute)[0].nextLevel;
        file.option.allopts.singleLastLevel = next.fn;
        return next;
    }

private:
    float nextLevelXlg() const
    {
        return this.xlg/2f - 30f;
    }

    void offerUpToTwoLevels(Rhino old)
    {
        auto next = old.nextLevel();
        auto nextU = nextUnsolvedLevelAfter(old);
        if (next == nextU) {
            offer(From.BOTTOM, Lang.outcomeAttemptNextLevel, next);
        }
        else {
            offer(From.BOT_LEF, Lang.outcomeResolveNextLevel, next);
            offer(From.BOT_RIG, Lang.outcomeAttemptNextUnsolvedLevel, nextU);
        }
    }

    void offer(
        Geom.From from,
        Lang topCaption,
        Optional!Rhino toPreview
    ) {
        foreach (reallyPreview; toPreview) {
            auto but = new NextLevelButton(new Geom(
                from == From.BOTTOM ? 0 : 20, 60, nextLevelXlg, 200, from),
                topCaption.transl, reallyPreview);
            addChild(but);
            _offeredLevels ~= but;
        }
    }

    static Optional!Rhino nextUnsolvedLevelAfter(Rhino oldLevel)
    {
        auto next = oldLevel.nextLevel;
        while (! next.empty && next.front.numCompletedAfterRecaching != 0) {
            next = next.oc.nextLevel;
        }
        return next;
    }
}

private:

class NextLevelButton : Button {
private:
    NextLevel _nextLevel;
    Label _topCaption;
    FullPreview _preview;

public:
    this(Geom g, string topCaption, in Rhino lev)
    {
        super(g);
        _nextLevel = NextLevel(new Level(lev.filename), lev.filename);
        _topCaption = new Label(
            new Geom(0, 10, xlg - 10, 20, From.TOP), topCaption);
        _preview = new FullPreview(
            new Geom(0, 40, xlg - 40, ylg - 50, From.TOP));
        _preview.preview(_nextLevel.level);
        addChildren(_topCaption, _preview);
    }

    inout(NextLevel) nextLevel() inout pure nothrow @safe @nogc
    {
        return _nextLevel;
    }

    void dispose() { _preview.dispose(); }
}