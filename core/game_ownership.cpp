#include "game_execution.hpp"
namespace astra {
void synchronize_ownership(const World& w,GameState& s) {
    for(auto& [actor,control]:s.controls) {
        auto bag=s.lives.at(actor).inventory;
        if(control.weapon&&!belongs_to(w,control.weapon,bag))control.weapon={};
        if(control.armor&&!belongs_to(w,control.armor,bag))control.armor={};
    }
    for(auto& [id,weapon]:s.weapons) {
        Id owner{};for(auto& [actor,l]:s.lives){(void)actor;if(belongs_to(w,id,l.inventory)){owner=l.account;break;}}
        if(owner==weapon.owner)continue;
        require(weapon.generation<UINT16_MAX,Error::LimitExceeded);weapon.owner=owner;++weapon.generation;++weapon.revision;
        weapon.trigger=false;weapon.inputSeq=weapon.fireSeq=0;
    }
}
}
