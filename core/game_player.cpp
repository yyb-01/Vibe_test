#include "game_execution.hpp"
#include "mutation.hpp"
#include "game_flags.hpp"
#include "packet.hpp"
namespace astra {
bool player_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds&,std::uint64_t event) {
    auto& life=s.lives.at(p.actor);auto bag=life.inventory;auto& control=s.controls.at(p.actor);
    switch(c.operation) {
    case GameOperation::Presence:
        if(c.enabled){control.connected=true;control.everJoined=true;life.tick=s.tick;control.moveTick=control.aimTick=s.tick;}
        else {control.connected=false;control.disconnectTick=s.tick;}
        return true;
    case GameOperation::Move: {
        require(!control.vehicle&&serial_newer(c.sequence,control.inputSeq)&&s.tick>control.moveTick,Error::SequenceMismatch);
        auto dt=std::min(1.0,(s.tick-control.moveTick)/60.0);auto distance=length(c.position-life.position);
        require(c.position==normalize_build(c.position)&&distance<=6*dt&&std::abs(c.position.z)<=.01&&
            line_of_sight(life.position+Vec3{0,0,1},c.position+Vec3{0,0,1},s.structures,d.structures),Error::NotAccessible);
        require(life.staminaJ>=distance*20,Error::CapacityExceeded);life.staminaJ-=distance*20;life.position=c.position;
        control.moveTick=s.tick;control.inputSeq=c.sequence;++life.revision;return true;
    }
    case GameOperation::Aim: {
        require(serial_newer(c.sequence,control.inputSeq)&&s.tick>control.aimTick,Error::SequenceMismatch);
        auto dt=std::min(1.0,(s.tick-control.aimTick)/60.0);auto yaw=std::int32_t(c.yaw)-control.yaw;
        if(yaw>32767)yaw-=65536;if(yaw<-32768)yaw+=65536;
        require(std::abs(yaw)<=dt*65536&&std::abs(std::int32_t(c.pitch)-control.pitch)<=dt*65536,Error::NotAccessible);
        control.yaw=c.yaw;control.pitch=c.pitch;control.aimTick=s.tick;control.inputSeq=c.sequence;return true;
    }
    case GameOperation::Consume: {
        auto item=c.targets[0];require(belongs_to(w,item,bag)&&d.foods.contains(w.items.at(item).defId)&&c.quantity==1&&!(w.items.at(item).flags&leased_tool),Error::NotAccessible);
        auto& f=d.foods.at(w.items.at(item).defId);ingest(life,f.waterMl,f.energyKcal,f.pathogens,event);consume_item(w,item,1);return true;
    }
    case GameOperation::Treat: {
        require(belongs_to(w,c.targets[0],bag)&&(d.items.at(w.items.at(c.targets[0]).defId).flags&256)&&s.lives.contains(c.targets[1]),Error::NotAccessible);
        auto& patient=s.lives.at(c.targets[1]);require(length(life.position-patient.position)<=2,Error::NotAccessible);
        treat_wound(patient,c.event,.2,true);consume_item(w,c.targets[0],1);return true;
    }
    case GameOperation::Respawn: {
        require(life.status==LifeStatus::Dead&&life.corpse&&life.epoch<UINT32_MAX,Error::NotAccessible);
        Life fresh;fresh.entity=life.entity;fresh.account=life.account;fresh.inventory=bag;fresh.epoch=life.epoch+1;
        fresh.revision=life.revision+1;fresh.tick=s.tick;fresh.position={};life=std::move(fresh);control={};control.moveTick=control.aimTick=s.tick;return true;
    }
    default:return false;
    }
}
}
