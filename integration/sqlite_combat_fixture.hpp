#pragma once
#include "sqlite_fault_store.hpp"
#include "../tests/fire_clock_fixture.hpp"

inline FireObservation combat_observation(Id account, Id pawn) {
    auto shot = *shot_request(seed()).shot;
    FireObservation result;
    result.pawn = pawn; result.inventoryRoot = id(10); result.weapon = id(104); result.ammo = id(100);
    result.authority = shot_authority(); result.authority.weaponOwner = account;
    result.launch = shot.launch; result.massMg = shot.massMg; result.ammoDef = shot.ammoDef;
    result.visualSeed = shot.visualSeed; result.durabilityCost = shot.durabilityCost;
    return result;
}
