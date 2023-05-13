module game.core.active;

/* calcActive evals the input and queues things to be sent through the net.
 * Game.calc() should afterwards calc the network, that flushes the network.
 */

import optional;

import net.repdata;
static import file.option; // unpause on assign
import file.replay;
import game.core.assignee;
import game.core.game;
import hardware.sound;
import hardware.mouse;
import hardware.semantic;
import lix;

package:

void calcNukeButton(Game game)
in {
    assert (!game.modalWindow);
    assert (game.view.canAssignSkills);
}
do { with (game)
{
    if (! pan.nukeDoubleclicked)
        return;
    pan.pause = false;
    game.cutGlobalFutureFromReplay();
    auto data = game.newPlyForNextPhyu();
    data.isNuke = true;
    game.includeOurNew(data);
    assert (_effect);
    _effect.addSound(Phyu(nurse.now + 1), Passport(localStyle, 0), Sound.NUKE);
}}

void calcClicksIntoMap(Game game, Optional!Assignee potAss)
in {
    assert (!game.modalWindow);
    assert (game.view.canAssignSkills);
}
do {
    if (! hardware.mouse.mouseClickLeft || ! game.isMouseOnLand) {
        return;
    }
    else if (game.canAssignTo(potAss)) {
        game.cutReplayAccordingToOptions(potAss.front.passport);
        game.assignTo(potAss.front);
        if (file.option.unpauseOnAssign.value == true) {
            game.pan.pause = false;
        }
    }
    else if (potAss.empty) {
        game.cutGlobalFutureFromReplay(); // We've clicked air, not a lix.
    }
    else if (game.view.canAssignSkills && game.pan.chosenSkill == Ac.nothing) {
        hardware.sound.playLoud(Sound.PANEL_EMPTY);
    }
}

void cutReplayAccordingToOptions(Game game, in Passport ofWhom)
{
    if (! game.view.canInterruptReplays) {
        return;
    }
    if (file.option.replayAlwaysInsert.value) {
        game.cutSingleLixFutureFromReplay(ofWhom);
    }
    else {
        game.nurse.cutGlobalFutureFromReplay();
    }
}

void cutGlobalFutureFromReplay(Game game)
{
    if (game.view.canInterruptReplays) {
        game.nurse.cutGlobalFutureFromReplay();
    }
}

void cutSingleLixFutureFromReplay(Game game, in Passport ofWhom)
{
    assert (game.view == View.solveAlone,
        "We're adding PlNr(0) to the ply. This will fail View.solveTogether."
        ~ " If we ever implement solveTogether, add more logic here and"
        ~ " also support that in the replay's ChangeRequest.");
    game.nurse.tweakReplayRecomputePhysics(ChangeRequest(
        Ply(PlNr(0), game.nurse.now, false, Ac.nothing, ofWhom.id),
        ChangeVerb.cutFutureOfOneLix));
}

// ############################################################################

private:

bool canAssignTo(Game game, in Optional!Assignee potAss)
{
    return game.view.canAssignSkills
        && game.pan.chosenSkill != Ac.nothing
        && ! potAss.empty
        && potAss.front.priority >= 2;
}

Ply newPlyForNextPhyu(Game game)
{
    Ply data;
    data.by = game._netClient ? game._netClient.ourPlNr : PlNr(0);
    data.when = game.nurse.now + 1;
    return data;
}

bool alwaysForceWhenAssigning(in Ac ac) pure nothrow @safe @nogc
{
    return ac == Ac.walker
        || ac == Ac.jumper
        || ac == Ac.batter
        || ac == Ac.builder
        || ac == Ac.platformer
        || ac == Ac.basher
        || ac == Ac.miner;
}

void assignTo(Game game, in Assignee assignee)
in {
    assert (game.pan.chosenSkillButtonOrNull !is null,
    "Don't call assignTo() then.");
}
do { with (game)
{
    Ply i = game.newPlyForNextPhyu();
    i.skill = game.pan.chosenSkill;
    i.toWhichLix = assignee.id;
    i.isDirectionallyForced
        = alwaysForceWhenAssigning(i.skill) || forcingLeft || forcingRight;
    i.lixShouldFace = assignee.lixxie.facingLeft
        ? Ply.LixShouldFace.left : Ply.LixShouldFace.right;

    if (game.pan.chosenSkillButtonOrNull.number != skillInfinity) {
        // Decrease the visible number on the panel. This is mostly eye candy.
        // It doesn't affect physics, including judging what's coming in over
        // the network, but it affects the assignment user interface.
        game.pan.chosenSkillButtonOrNull.number
            = game.pan.chosenSkillButtonOrNull.number - 1;
    }
    game.includeOurNew(i);

    // React faster to the new assignment than during its evaluation next
    // update. The evaluation could be several ticks ticks later.
    assert (game._effect);
    game._effect.addArrowDontShow(i.when, assignee.passport);
    game._effect.addSound(i.when, assignee.passport, Sound.ASSIGN);
}}

void includeOurNew(Game game, in Ply data) { with (game)
{
    undispatchedAssignments ~= data;
    if (_netClient)
        _netClient.sendPly(data);
}}
