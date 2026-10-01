#pragma once
#include "state_wire.hpp"
#include "game_control.hpp"
#include "game_ground.hpp"
#include "vehicle.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,PlayerControl>
void state_fields(A& a,V& c){a(c.inputSeq,c.moveTick,c.aimTick,c.yaw,c.pitch,c.vehicle,c.weapon,c.armor);if(a.version>=2)a(c.connected,c.everJoined,c.disconnectTick);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,DriveInput>
void state_fields(A& a,V& c){a(c.sequence,c.tick,c.assemblyRevision,c.throttle,c.brake,c.steer,c.gear);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,GroundAsset>
void state_fields(A& a,V& c){a(c.item,c.owner,c.position,c.velocity,c.omega,c.lifeEpoch,c.spawnDef,c.quantity,c.cycle,c.nextSpawnTick);}
}
