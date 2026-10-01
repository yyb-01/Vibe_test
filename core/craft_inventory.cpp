#include "crafting.hpp"
#include "grid.hpp"
#include "mutation.hpp"
namespace astra {
void consume_item(World& w,Id id,std::uint32_t quantity) {
    require(w.items.contains(id)&&w.placements.contains(id),Error::NotAccessible);auto& i=w.items.at(id);
    require(quantity&&quantity<=i.quantity&&!(i.flags&deleted),Error::InvalidQuantity);i.quantity-=quantity;bump(i.revision);
    if(!i.quantity){i.flags|=deleted;w.placements.erase(id);}
}
void place_item(const Catalog& cat,World& w,Id id,Id target) {
    require(w.items.contains(id)&&w.containers.contains(target),Error::NotAccessible);
    const auto& c=w.containers.at(target);auto p=Placement{id,target};p.kind=c.kind;
    if(c.kind==PlaceKind::World||c.kind==PlaceKind::Escrow){w.placements.insert_or_assign(id,p);return;}
    Grid occupied{};
    for(const auto& [other,place]:w.placements)if(other!=id&&place.container==target)occupy(occupied,c,cat.at(w.items.at(other).defId),place);
    for(unsigned rotation=0;rotation<2;++rotation)for(unsigned y=0;y<c.state.height;++y)for(unsigned x=0;x<c.state.width;++x) {
        auto scratch=occupied;p.x=x;p.y=y;p.rotation=rotation;p.socketId=c.kind==PlaceKind::Slot||c.kind==PlaceKind::Socket?x+1:0;
        if(p.socketId)p.x=p.y=p.rotation=0;
        try {occupy(scratch,c,cat.at(w.items.at(id).defId),p);w.placements.insert_or_assign(id,p);return;}
        catch(const Violation& e){if(e.code!=Error::InvalidPlacement)throw;}
    }
    throw Violation{Error::CapacityExceeded};
}
}
