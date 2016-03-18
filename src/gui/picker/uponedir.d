module gui.picker.uponedir;

/* This is not part of Picker. Yet it controls a picker.
 * When you use a picker, you should make a separate UpOneDirButton
 * and link it to the Picker. Reason: It's not inside the Picker's geom.
 *
 * This doesn't feel right. Without a mediator for both the Picker and the
 * UpOneDirButton, the button must unhide itself, thus override work().
 *
 * Another problem: The picker doesn't know about the UpOneDirButton,
 * thus needs a bool variable to store that its dir has been changed this.
 * Reason: The picker's public interface allows querying whether its dir
 * has been changed this tick. That public function should return
 * UpOneDir.execute instead.
 */

import basics.user;
import file.filename;
import file.language;
import gui;
import gui.picker.picker;

class UpOneDirButton : TextButton {
private:
    Picker _picker;

public:
    this(Geom g, Picker pi)
    {
        assert (pi);
        super(g);
        _picker = pi;
        text    = Lang.commonDirParent.transl;
        hotkey  = basics.user.keyMenuUpDir;
        hideOrShow();
    }

protected:
    override void calcSelf()
    {
        super.calcSelf();
        if (execute) {
            assert (_picker.currentDir.file == "");
            string s = _picker.currentDir.dirRootless[0 .. $-1];
            while (s.length > 0 && s[$-1] != '/')
                s = s[0 .. $-1];
            _picker.currentDir = new Filename(s);
            assert (_picker.currentDir.file == "");
            hideOrShow();
        }
    }

    override void workSelf() { hideOrShow(); }

private:
    void hideOrShow() { hidden = (_picker.currentDir == _picker.basedir); }
}
