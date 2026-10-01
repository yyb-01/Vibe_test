#include "game_command.hpp"
#include "chamber.hpp"
#include "magazine.hpp"
namespace astra {
void seed_player(const GameDefinitions& d,World& w,GameState& s,unsigned index) {
    auto id=[&](unsigned n){return Id{5,10000+index*100+n};};auto bag=Id{5,2000+index};
    Container root;root.state.id=bag;root.state.width=root.state.height=16;root.state.capacityMl=500000;root.maxMassG=150000;w.containers.emplace(bag,root);
    auto item=[&](unsigned n,unsigned def,unsigned count=1,Id target={}) {
        ItemState i;i.id=id(n);i.defId=def;i.quantity=count;w.items.emplace(i.id,i);place_item(d.items,w,i.id,target?target:bag);return i.id;
    };
    auto owned=[&](unsigned n,Id owner,unsigned width,PlaceKind kind,unsigned flags=0) {
        Container c;c.state.id=id(n);c.state.ownerItem=owner;c.state.width=width;c.state.height=32;c.state.capacityMl=UINT32_MAX;c.kind=kind;c.state.flags=flags;
        if(flags&chamber_container)c.state.height=1;w.containers.emplace(c.state.id,c);return c.state.id;
    };
    auto rifle=item(1,100),socket=owned(2,rifle,2,PlaceKind::Socket),chamber=owned(3,rifle,1,PlaceKind::Slot,chamber_container);
    auto mount=owned(4,rifle,1,PlaceKind::Slot);auto barrel=item(5,101);attach_part(d.items,w,barrel,socket,1,d.parts);
    owned(6,barrel,1,PlaceKind::Socket);item(7,105,1,chamber);
    auto magazine=item(8,104,1,mount),rounds=owned(9,magazine,32,PlaceKind::Slot,magazine_container);item(10,105,20,rounds);
    auto spare=item(11,104),spareRounds=owned(12,spare,32,PlaceKind::Slot,magazine_container);item(13,106,20,spareRounds);
    item(14,108,100);item(15,109,100);item(16,110,100);item(17,114);item(18,112,3);item(19,113,3);item(20,116,100);
    auto armor=item(21,117);s.armor.emplace(armor,ArmorMap{});
    item(22,124,3);
    Life life;life.entity={5,1000+index};life.account={7,index+1};life.inventory=bag;life.position={double(index)*3,0,0};s.lives.emplace(life.entity,life);s.controls.emplace(life.entity,PlayerControl{});
    s.controls.at(life.entity).weapon=rifle;s.controls.at(life.entity).armor=armor;
    WeaponRuntime weapon;weapon.item=rifle;weapon.owner=life.account;weapon.netId=100+index;weapon.selectedMagazine=magazine;s.weapons.emplace(rifle,weapon);
}
}
