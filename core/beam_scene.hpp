#pragma once
#include "beam.hpp"
#include "game_state.hpp"
namespace astra {
std::vector<BeamLayer> game_layers(const GameDefinitions&,const GameState&,const GameShot&,std::uint64_t queryQ16,std::int64_t margin);
std::optional<std::pair<std::size_t,ballistics::BoxHit>> first_layer(ballistics::Vector from,ballistics::Vector to,std::span<const BeamLayer>);
ballistics::Atmosphere ammunition_air(const AmmoProfile&,const ballistics::Vector&);
void apply_beam_damage(GameState&,GameShot&,std::span<const BeamDeposit>,World* world=nullptr);
}
