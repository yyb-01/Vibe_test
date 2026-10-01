#include "game_execution.hpp"
#include "mutation.hpp"
namespace astra {
bool inventory_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    auto bag=actor_inventory(s,p);auto item=c.targets[0];
    if(c.operation==GameOperation::Equip) {
        require(belongs_to(w,item,bag),Error::NotAccessible);auto& control=s.controls.at(p.actor);
        if(s.weapons.contains(item))control.weapon=c.enabled?item:Id{};
        else {require(s.armor.contains(item),Error::Incompatible);control.armor=c.enabled?item:Id{};}return true;
    }
    if(c.operation<GameOperation::InventoryMove||c.operation>GameOperation::Drop)return false;
    require(w.placements.contains(item)&&accessible_container(d,w,s,p.actor,w.placements.at(item).container),Error::NotAccessible);
    require(c.position.x>=0&&c.position.y>=0&&c.position.x<=65535&&c.position.y<=65535&&
        c.position.x==std::floor(c.position.x)&&c.position.y==std::floor(c.position.y)&&c.definition<=1,Error::InvalidPlacement);
    auto make=[&](Id id,Id target,Placement place) {
        auto source=w.placements.at(id).container;auto& i=w.items.at(id);
        return MoveEntry{id,source,target,i.revision,w.containers.at(source).state.revision,w.containers.at(target).state.revision,
            i.quantity,place.socketId,place.x,place.y,place.rotation};
    };
    Request r;r.id=c.id;r.actionSeq=1;r.interactionLease=1;Id created{};
    if(c.operation==GameOperation::InventorySwap) {
        auto other=c.targets[1];require(w.placements.contains(other)&&accessible_container(d,w,s,p.actor,w.placements.at(other).container),Error::NotAccessible);r.operation=Operation::Swap;
        r.moves={make(item,w.placements.at(other).container,w.placements.at(other)),make(other,w.placements.at(item).container,w.placements.at(item))};
    } else {
        auto target=c.operation==GameOperation::Drop?ground_root:c.targets[1];require(w.containers.contains(target),Error::NotAccessible);
        if(target!=ground_root)require(accessible_container(d,w,s,p.actor,target),Error::NotAccessible);
        else require(c.operation==GameOperation::Drop,Error::NotAccessible);
        Placement place{};place.x=std::uint16_t(c.position.x);place.y=std::uint16_t(c.position.y);place.rotation=std::uint8_t(c.definition);
        r.operation=c.operation==GameOperation::InventorySplit?Operation::Split:c.operation==GameOperation::InventoryMerge?Operation::Merge:c.operation==GameOperation::Drop?Operation::Drop:Operation::Move;
        r.moves.push_back(make(item,target,place));r.moves[0].quantity=c.quantity;
        if(r.operation==Operation::Split)created=ids.take();
    }
    Access access{p.account,1,1,{bag,ground_root,station_root}};check_request(w,r,access);mutate(d.items,w,r,created,event);
    if(c.operation==GameOperation::Drop)s.groundAssets[item]={item,p.account,s.lives.at(p.actor).position+Vec3{0,0,1},{},{}};
    return true;
}
}
