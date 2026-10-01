#include "game_execution.hpp"
#include "mutation.hpp"
#include "chamber.hpp"
#include "magazine.hpp"
#include "beam_scene.hpp"
namespace astra {
void perform_shot(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& peer,GameIds& ids,std::uint64_t event,bool timer) {
    auto& life=s.lives.at(peer.actor);auto& weapon=s.weapons.at(c.targets[0]);auto& control=s.controls.at(peer.actor);
    require(control.weapon==weapon.item,Error::NotAccessible);
    auto& receiver=d.receivers.at(d.items.at(w.items.at(weapon.item).defId).partDefId);auto chamber=chamber_state(w,weapon.item);
    require(weapon.phase==WeaponPhase::Ready&&chamber.round&&s.shots.size()<2048&&(!weapon.shotCounter||s.tick>=weapon.lastFireTick+receiver.firePeriodTicks),Error::Busy);
    auto& ammo=d.ammunition.at(w.items.at(chamber.round).defId);require(ammo.family==receiver.family&&ammo.chamberProfile==receiver.chamberProfile,Error::Incompatible);
    auto stats=weapon_stats(d.items,w,weapon.item,d.parts);FireIntent intent;
    intent.weaponNetId=weapon.netId;intent.generation=weapon.generation;intent.assemblyRevision=weapon.assemblyRevision;
    intent.inputSeq=c.sequence;intent.fireSeq=timer?std::uint32_t(weapon.shotCounter+1):std::uint32_t(c.event?c.event:c.sequence);
    intent.clientFireTick=std::uint32_t(c.tick);intent.aimYaw=c.yaw;intent.aimPitch=c.pitch;intent.buttons=trigger_on;intent.approvedViewDelayFrames=std::uint8_t(c.definition);
    FireAuthority authority;authority.account=peer.account;authority.weaponOwner=weapon.owner;authority.weaponNetId=weapon.netId;
    authority.generation=weapon.generation;authority.assemblyRevision=weapon.assemblyRevision;authority.aimYaw=control.yaw;authority.aimPitch=control.pitch;
    authority.maxYawError=authority.maxPitchError=32;authority.alive=life.status==LifeStatus::Conscious;authority.chambered=true;
    authority.triggerReady=authority.poseAvailable=authority.muzzleClear=true;authority.local=peer.local||timer;authority.clockReady=peer.clockReady;
    authority.clientToServerTicks=peer.clockOffset;authority.approvedViewDelayFrames=peer.viewDelay;authority.nowQ16=s.tick*65536;
    authority.minIntervalQ16=receiver.firePeriodTicks*65536;authority.hasPrevious=!timer&&weapon.fireSeq;
    authority.lastAcceptedQ16=weapon.lastFireTick*65536;authority.lastEffectiveQ16=weapon.lastEffectiveQ16;
    authority.lastFireSeq=weapon.fireSeq;authority.lastInputSeq=weapon.inputSeq;
    auto effective=validate_fire_candidate(intent,authority);auto poses=historical_actors(s,effective);
    auto pose=std::find_if(poses.begin(),poses.end(),[&](auto& a){return a.entity==life.entity&&a.epoch==life.epoch;});require(pose!=poses.end(),Error::NotAccessible);
    auto random=event*0x9e3779b97f4a7c15ULL;random^=random>>30;
    auto radius=std::sqrt(double(random>>11)/9007199254740992.0)*stats.dispersionRad;
    auto angle=double(std::uint32_t(random))*6.283185307179586/4294967296.0;
    auto yaw=c.yaw*(2*3.141592653589793/65536)+weapon.recoilYaw+radius*std::cos(angle);
    auto pitch=c.pitch*(2*3.141592653589793/65536)+weapon.recoilPitch+radius*std::sin(angle);
    Vec3 direction{std::cos(pitch)*std::cos(yaw),std::cos(pitch)*std::sin(yaw),std::sin(pitch)},muzzle=pose->position+Vec3{0,0,1.4}+direction*.4;
    GameShot muzzleQuery;muzzleQuery.shooter=life.entity;auto obstruction=game_layers(d,s,muzzleQuery,effective,0);
    ballistics::Vector handPoint{},muzzlePoint{};double hand[]{pose->position.x,pose->position.y,pose->position.z+1.4},tip[]{muzzle.x,muzzle.y,muzzle.z};
    for(unsigned i=0;i<3;++i){handPoint[i]=std::llround(hand[i]*1e6);muzzlePoint[i]=std::llround(tip[i]*1e6);}
    for(auto& layer:obstruction)if(layer.target.kind==3)require(!ballistics::sweep_box(handPoint,muzzlePoint,layer.volume.box),Error::NotAccessible);
    auto jam=std::clamp(receiver.baseJamProbability+weapon.fouling*.01+std::max(0.0,weapon.heatK-500)*.0001,0.0,1.0);
    if(double(random>>11)/9007199254740992.0<jam){weapon.phase=WeaponPhase::Jammed;weapon.trigger=false;++weapon.revision;return;}
    ShotData shot;shot.intent=intent;shot.effectiveQ16=effective;shot.massMg=ammo.massMg;shot.ammoDef=ammo.id;shot.durabilityCost=receiver.wearPerShot;
    for(unsigned i=0;i<3;++i){double position[]{muzzle.x,muzzle.y,muzzle.z},velocity[]{direction.x,direction.y,direction.z};shot.launch.position[i]=std::llround(position[i]*1e6);shot.launch.velocity[i]=std::llround(velocity[i]*ammo.speedUmS*stats.velocityScale);}
    validate_shot(shot);Request request;request.shot=shot;MoveEntry round,receiverMove;round.item=chamber.round;receiverMove.item=weapon.item;request.moves={round,receiverMove};consume_shot(d.items,w,request);
    GameShot flight;flight.shooter=life.entity;flight.ammoDef=ammo.id;flight.viewDelay=peer.viewDelay;
    flight.flight.effectiveQ16=effective;flight.flight.projectile={shot.launch,s.nextShot++,ammo.massMg,ammo.radiusUm};s.shots.push_back(flight);
    publish_stimulus(s.world,{event,s.tick,life.entity,muzzle,StimulusKind::Gunshot,500,150,0,60});
    weapon.lastFireTick=s.tick;weapon.lastEffectiveQ16=effective;++weapon.shotCounter;weapon.heatK+=receiver.heatPerShotK;weapon.fouling=std::min(1.0,weapon.fouling+.001);
    weapon.recoilPitch+=.005*stats.recoilScale;weapon.recoilYaw+=((random&1)?1:-1)*.002*stats.recoilScale;
    if(!timer){weapon.inputSeq=intent.inputSeq;weapon.fireSeq=intent.fireSeq;}++weapon.revision;
    auto mag=weapon.selectedMagazine;if(mag&&magazine_state(w,mag).nextRound)feed_round(d.items,w,weapon.item,mag,ids.take(),event,d.ammunition,receiver);
}
}
