module menu.browbase;

/*  class BrowserBase
 *
 *      Guarantee for all inherited classes: onFileHighlight will be called
 *      for every file on which possibly on_file_select could be called later.
 *      Whenever on_file_select is called, onFileHighlight has been called
 *      on the same filename before, and no other onFileHighlight calls have
 *      been made in the meantime. (Impl. by private BrowserBase._fileRecent.)
 */

import std.conv;
static import std.file;

import basics.user; // hotkeys
import file.filename;
import file.language;
import file.log;
import gui;
import gui.picker;
import hardware.mouse;
import hardware.sound;
import level.level;
import menu.preview;

class BrowserBase : Window {
private:
    bool _gotoMainMenu;
    MutFilename _fileRecent; // only used for highlighting, not selecting

    Picker _picker;
    UpOneDirButton _upOneDir;

    TextButton buttonPlay;
    TextButton buttonExit;
    Preview    preview;

public:
    enum  float pickerXl = 320;
    final float infoX()  const { return pickerXl + 40;       }
    final float infoXl() const { return xlg - pickerXl - 60; }

    // after calling this(), it's a good idea to call
    // highlight(file) with whatever is deemed the correct current file
    this(
        in string title,
        Filename  baseDir
    ) {
        super(new Geom(0, 0, Geom.screenXlg, Geom.screenYlg), title);
        _picker = Picker.newPicker!LevelTiler(
            new Geom(20,  40, pickerXl, 420),
            new OrderFileLs);
        _picker.basedir = baseDir;
        _upOneDir = new UpOneDirButton(new Geom(infoX, 20,
            infoXl/2, 40, From.BOTTOM_LEFT), _picker);
        buttonExit = new TextButton(new Geom(infoX + infoXl/2, 20,
            infoXl/2, 40, From.BOTTOM_LEFT), Lang.commonBack.transl);
        buttonPlay = new TextButton(new Geom(infoX, 80,
            infoXl/3, 40, From.BOTTOM_LEFT), Lang.browserPlay.transl);
        preview    = new Preview(new Geom(20, 60, infoXl, 160, From.TOP_RIG));
        buttonPlay.hotkey = basics.user.keyMenuOkay;
        buttonExit.hotkey = basics.user.keyMenuExit;
        buttonExit.onExecute = () { _gotoMainMenu = true; };
        addChildren(preview, _picker, _upOneDir, buttonPlay, buttonExit);
        updateWindowSubtitle();
    }

    ~this() { if (preview) destroy(preview); preview = null; }

    void setButtonPlayText(in string s) { buttonPlay.text = s; }

    @property bool gotoMainMenu() const { return _gotoMainMenu; }
    @property auto fileRecent()   inout { return _fileRecent;   }

    void previewLevel(Level l) { preview.level = l;    }
    void clearPreview()        { preview.level = null; }

    final void highlight(Filename fn)
    {
        if (fn && _picker.highlightFile(fn)) {
            buttonPlay.show();
            _fileRecent = fn;
            onFileHighlight(fn);
        }
        else {
            buttonPlay.hide();
            // keep _fileRecent as it is, we might highlight that again later
            onFileHighlight(null);
        }
        updateWindowSubtitle();
    }

protected:
    // override these
    void onFileHighlight(Filename) {}
    void onFileSelect   (Filename) {}

    final void deleteFileRecentHighlightNeighbor()
    {
        /+
        assert (fileRecent);
        try std.file.remove(fileRecent.rootful);
        catch (Exception e)
            logf(e.msg);
        auto number = levList.currentNumber;
        levList.load_dir(levList.currentDir);
        levList.highlightNumber(-1);
        levList.highlightNumber(number);
        _fileRecent = null;
        highlight(levList.currentFile);
        +/
        playLoud(Sound.SCISSORS);
    }

    override void calcSelf()
    {
        if (_picker.executeFile) {
            MutFilename clicked = _picker.executeFileFilename;
            assert (clicked !is null);
            if (clicked != _fileRecent)
                highlight(clicked);
            else
                onFileSelect(_fileRecent);
        }
        else if (_picker.executeDir || _upOneDir.execute)
            // A better design of the picker would get rid of checking
            // _upOneDir here. See header comment in gui.picker.uponedir.
            highlight(currentDirContainsFileRecent ? _fileRecent : null);
        else if (buttonPlay.execute) {
            assert (_fileRecent !is null);
            assert (currentDirContainsFileRecent);
            onFileSelect(_fileRecent);
        }
        else if (hardware.mouse.mouseClickRight)
            _gotoMainMenu = true;
    }

private:
    void updateWindowSubtitle()
    {
        assert (_picker.basedir   .rootless.length
            <=  _picker.currentDir.rootless.length);
        windowSubtitle = _picker.currentDir.rootless[
                         _picker.basedir   .rootless.length .. $];
    }

    @property bool currentDirContainsFileRecent() const
    {
        return _fileRecent
            && _fileRecent.dirRootless == _picker.currentDir.dirRootless;
    }
}
