#include "world_simulation.hpp"
#include <queue>
#include <set>
namespace astra {
std::vector<Vec3> find_path(Vec3 from,Vec3 target,const std::map<Id,Structure>& world,const std::map<std::uint32_t,StructureDef>& defs,unsigned maxNodes) {
    cell_of(from);cell_of(target);require(maxNodes&&maxNodes<=65536,Error::InvalidRequest);
    if(line_of_sight(from,target,world,defs))return {target};
    using Tile=std::pair<int,int>;
    auto tile=[](Vec3 p){return Tile{int(std::floor((p.x+2000)/2.5)),int(std::floor((p.y+2000)/2.5))};};
    auto position=[&](Tile t){return Vec3{t.first*2.5-1998.75,t.second*2.5-1998.75,from.z};};
    auto start=tile(from),goal=tile(target);
    using Entry=std::pair<unsigned,Tile>;std::priority_queue<Entry,std::vector<Entry>,std::greater<Entry>> queue;
    std::map<Tile,unsigned> cost;std::map<Tile,Tile> parent;std::set<Tile> closed;
    auto heuristic=[&](Tile t){return unsigned(std::abs(t.first-goal.first)+std::abs(t.second-goal.second));};
    cost[start]=0;queue.push({heuristic(start),start});
    constexpr Tile steps[]{{-1,0},{0,-1},{0,1},{1,0}};
    while(!queue.empty()&&closed.size()<maxNodes) {
        auto current=queue.top().second;queue.pop();if(!closed.insert(current).second)continue;
        if(current==goal) {
            std::vector<Vec3> path{target};for(auto p=current;p!=start;p=parent.at(p))path.push_back(position(p));
            std::reverse(path.begin(),path.end());return path;
        }
        for(auto step:steps) {
            Tile next{current.first+step.first,current.second+step.second};
            if(next.first<0||next.first>=1600||next.second<0||next.second>=1600||closed.contains(next))continue;
            if(!line_of_sight(position(current),position(next),world,defs))continue;
            auto proposed=cost.at(current)+1;if(cost.contains(next)&&cost.at(next)<=proposed)continue;
            cost[next]=proposed;parent[next]=current;queue.push({proposed+heuristic(next),next});
        }
    }return {};
}
}
