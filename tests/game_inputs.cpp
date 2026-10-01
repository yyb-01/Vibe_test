#include "game_fixture.hpp"
#include "simulation_journal.hpp"
#include "checkpoint_delta.hpp"
void game_input_retention(){
    auto definitions=survival_definitions();Inventory memory(survival_seed(definitions));
    auto durable=memory.checkpoint();Access access{{7,1},1,1,{game_root}};
    auto command=[](unsigned n){GameCommand c;c.id={9,n};c.operation=GameOperation::Aim;c.sequence=n;return c;};
    Request original;
    for(unsigned n=1;n<=100;++n){
        Request r;r.id={9,n};r.actionSeq=n;r.operation=Operation::System;r.systemRoots={game_root};r.command=encode_command(command(n));r.interactionLease=1;
        r.mutation=[](World& w,Id,std::uint64_t){auto s=decode_game(w.containers.at(game_root).gameplay);++s.revision;w.containers.at(game_root).gameplay=encode_game(s);};
        access.approvedSystem=encode(r);auto prepared=memory.prepare(r,access);CHECK(prepared.changes);
        auto projected=memory.checkpoint_after(prepared.changes);auto delta=memory.checkpoint_delta(prepared.changes);
        apply_checkpoint_delta(durable,delta);CHECK(encode_checkpoint(projected)==encode_checkpoint(durable));
        CHECK(memory.commit(prepared.changes).applied());if(n==1)original=r;
    }
    auto c=memory.checkpoint();CHECK(c.requests.size()==32&&c.retiredInputs.at(access.account).retired==68&&c.retiredCommits==68);
    CHECK(request_count(c)==100&&memory.expired_input(access.account,original.id)&&!memory.expired_input(access.account,{9,100}));
    Inventory restored(decode_checkpoint(encode_checkpoint(c)));CHECK(restored.next_action_sequence(access.account)==101);
    CHECK(restored.expired_input(access.account,{9,1}));
    GameFixture game;
    GameCommand first;
    for(unsigned i=0;i<35;++i){game.ticks(1);auto aim=game.command(GameOperation::Aim);aim.tick=game.game.state().tick;aim.sequence=i+1;CHECK(game.send(aim).applied());if(i==0)first=aim;}
    auto before=game.game.state();CHECK(game.send(first).code==Error::SequenceMismatch);CHECK(game.game.state().revision==before.revision);
    auto leave=game.command(GameOperation::Presence);CHECK(game.send(leave).applied());
    auto move=game.command(GameOperation::Move);move.sequence=36;CHECK(game.send(move).code==Error::NotAccessible);
    auto join=game.command(GameOperation::Presence);join.enabled=true;CHECK(game.send(join).applied());
    auto state=game.game.state();CHECK(state.controls.at(game.player.actor).connected);
    auto control=state.controls.at(game.player.actor);control.connected=false;control.disconnectTick=state.tick;
    CHECK(active_player(control,state.tick+600)&&!active_player(control,state.tick+601));
    CHECK(!active_player(PlayerControl{0,0,0,0,0,{},{},{},false,false,0},0));
}
