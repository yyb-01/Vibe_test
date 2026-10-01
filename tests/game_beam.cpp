#include "check.hpp"
#include "beam.hpp"
#include "velocity_response.hpp"
#include "game_command.hpp"
#include "beam_scene.hpp"
using namespace astra;
void game_beam() {
    using namespace ballistics;
    Flight flight{{0,0,0},{10000000,0,0}};
    BeamTarget a;a.entity={1,1};a.kind=3;a.material={1000,1,1,64000000};
    BeamTarget b=a;b.entity={1,2};b.material={2000,2,1,64000000};
    std::vector<BeamLayer> scene{{{{1,1,1},1,0,{{0,-100,-100},{10000,100,100}}},a},{{{1,2,1},2,0,{{5000,-100,-100},{15000,100,100}}},b}};
    std::uint16_t contacts=0;auto transit=start_beam(flight,scene,contacts);auto single=transit,split=transit;auto left=flight,right=flight;
    auto incoming=velocity_energy(flight.velocity,1000000);std::int64_t absorbedA=0,absorbedB=0;
    auto step=advance_beam(single,left,1000000,1u<<24);for(auto& d:step.deposits)absorbedA+=d.energyUj;
    for(unsigned i=0;i<8&&split.index<split.slices.size();++i){auto part=advance_beam(split,right,1000000,1u<<21);for(auto& d:part.deposits)absorbedB+=d.energyUj;}
    CHECK(step.exited&&contacts==2&&left==right&&absorbedA==absorbedB&&absorbedA+velocity_energy(left.velocity,1000000)==incoming);
    auto stopped=transit;auto slow=flight;slow.velocity={100000,0,0};BeamStep result;
    for(unsigned i=0;i<40&&!result.stopped;++i)result=advance_beam(stopped,slow,1000000,1u<<24);
    CHECK(result.stopped&&slow.position[0]<15000);
    auto definitions=survival_definitions();auto seed=survival_seed(definitions);
    auto state=decode_game(seed.world.containers.at(game_root).gameplay);
    for(auto& frame:state.history)for(auto& actor:frame.actors)actor.armor.reset();
    GameShot shot;auto anatomy=game_layers(definitions,state,shot,0,0);
    constexpr Vec3 points[]={{0,0,1.7},{0,.1,1.3},{0,0,1.0},{0,0,.75},{0,.38,1.24},{0,-.38,1.24},{0,.12,.3},{0,-.12,.3}};
    for(unsigned region=0;region<8;++region){auto p=points[region];auto y=std::llround(p.y*1e6),z=std::llround(p.z*1e6);
        auto hit=first_layer({-1000000,y,z},{1000000,y,z},anatomy);CHECK(hit&&anatomy[hit->first].target.entity==Id(5,1000)&&anatomy[hit->first].target.region==region);
    }
}
