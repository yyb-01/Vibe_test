#include "game_state.hpp"
#include "inventory.hpp"
namespace astra {
void record_history(const World& w,GameState& s) {
    HistoryFrame frame;frame.tick=s.tick;
    for(auto& [id,l]:s.lives) {
        if(!active_player(s.controls.at(id),s.tick))continue;
        auto& control=s.controls.at(id);HistoryActor a{id,l.epoch,0,l.position,control.yaw,control.pitch,l.status!=LifeStatus::Dead,{}};
        auto armor=control.armor;
        if(armor&&s.armor.contains(armor)&&w.placements.contains(armor)&&ancestry(w,w.placements.at(armor).container).back()==l.inventory)a.armor=HistoryArmor{armor,s.armor.at(armor)};
        frame.actors.push_back(a);
    }
    for(auto& [id,z]:s.world.zombies)frame.actors.push_back({id,1,1,z.position,0,0,z.health>0,{}});
    for(auto& [id,v]:s.vehicles)frame.actors.push_back({id,1,2,v.position,0,0,true,{}});
    for(auto& [id,b]:s.structures)if(b.definition==14)frame.doors.push_back({id,b.open,b.destroyed});
    require(frame.doors.size()<=512,Error::LimitExceeded);
    if(!s.history.empty()&&s.history.back().tick==s.tick)s.history.back()=std::move(frame);else s.history.push_back(std::move(frame));
    if(s.history.size()>31)s.history.erase(s.history.begin());
}
std::vector<HistoryActor> historical_actors(const GameState& s,std::uint64_t q16) {
    require(!s.history.empty()&&q16<=s.tick*65536&&q16>=s.history.front().tick*65536,Error::NotAccessible);
    auto upper=std::upper_bound(s.history.begin(),s.history.end(),q16,[](auto tick,auto& f){return tick<f.tick*65536;});
    auto lower=std::prev(upper);auto result=lower->actors;
    if(upper==s.history.end()||q16==lower->tick*65536)return result;
    auto alpha=double(q16-lower->tick*65536)/double((upper->tick-lower->tick)*65536);
    for(auto& a:result) {
        auto next=std::find_if(upper->actors.begin(),upper->actors.end(),[&](auto& p){return p.entity==a.entity&&p.epoch==a.epoch&&p.kind==a.kind;});
        if(next!=upper->actors.end())a.position=a.position+(next->position-a.position)*alpha;
    }
    return result;
}
bool historical_door(const GameState& s,Id id,std::uint64_t q16) {
    require(!s.history.empty()&&q16>=s.history.front().tick*65536,Error::NotAccessible);
    auto upper=std::upper_bound(s.history.begin(),s.history.end(),q16,[](auto tick,auto& f){return tick<f.tick*65536;});
    require(upper!=s.history.begin(),Error::NotAccessible);
    for(auto& door:std::prev(upper)->doors)if(door.entity==id)return !door.open&&!door.destroyed;
    return false;
}
}
