#include "game_fixture.hpp"
#include "chamber.hpp"
void game_reload_guards(){
    GameFixture f;Id gun{5,10001},spare{5,10011};
    auto mass=weapon_stats(f.defs.items,*f.storage.inventory->snapshot(),gun,f.defs.parts).massKg;
    CHECK(std::abs(mass-2.918)<1e-9);
    auto reload=f.command(GameOperation::Reload);reload.targets={gun,spare,{}};reload.revision=1;CHECK(f.send(reload).applied());
    for(auto item:std::vector<Id>{gun,spare,{5,10005},{5,10013},{5,10010}}){auto drop=f.command(GameOperation::Drop);drop.targets[0]=item;drop.quantity=f.storage.inventory->snapshot()->items.at(item).quantity;auto r=f.send(drop);if(r.code!=Error::Busy)throw std::runtime_error("reload guard item "+std::to_string(item.lo)+" code "+std::to_string(unsigned(r.code)));}
    f.ticks(90);CHECK(f.game.state().weapons.at(gun).phase==WeaponPhase::Ready);
    reload=f.command(GameOperation::Reload);reload.targets={gun,Id{5,10008},{}};reload.revision=1;CHECK(f.send(reload).applied());
    f.ticks(30);auto offline=f.command(GameOperation::Presence);CHECK(f.send(offline).applied());f.ticks(1);
    CHECK(f.game.state().weapons.at(gun).phase==WeaponPhase::Ready);
    auto online=f.command(GameOperation::Presence);online.enabled=true;CHECK(f.send(online).applied());
    auto drop=f.command(GameOperation::Drop);drop.targets[0]=gun;CHECK(f.send(drop).applied());f.ticks(5);
    CHECK(!f.game.state().controls.at(f.player.actor).weapon);
    auto state=f.game.state();state.controls.at(f.player.actor).vehicle={9,9};
    try{(void)encode_game(state);CHECK(false);}catch(const Violation& e){CHECK(e.code==Error::InvalidState);}
    state=f.game.state();state.history.push_back(state.history.back());
    try{(void)encode_game(state);CHECK(false);}catch(const Violation& e){CHECK(e.code==Error::InvalidState);}
}
