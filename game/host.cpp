#include "host.hpp"
#include <charconv>
#include <thread>
namespace astra::native {
Id parse_id(const std::string& value) {
    auto n=value.find(':');require(n!=std::string::npos,Error::InvalidRequest);Id id;
    auto number=[](std::string_view v,std::uint64_t& out){auto [p,e]=std::from_chars(v.data(),v.data()+v.size(),out);require(e==std::errc{}&&p==v.data()+v.size()&&!v.empty(),Error::InvalidRequest);};
    number(std::string_view(value).substr(0,n),id.hi);number(std::string_view(value).substr(n+1),id.lo);require(bool(id),Error::InvalidRequest);return id;
}
std::string id_text(Id id){return std::to_string(id.hi)+":"+std::to_string(id.lo);}
Host::Host(const std::filesystem::path& path) {
    auto seed=survival_seed(definitions,20);
    auto initial=decode_game(seed.world.containers.at(game_root).gameplay);
    for(auto& [id,c]:initial.controls)if(id!=Id{5,1000}){c.connected=false;c.everJoined=false;}
    initial.history.clear();record_history(seed.world,initial);seed.world.containers.at(game_root).gameplay=encode_game(initial);
    auto store=std::make_unique<AsyncStore>([path]{return std::make_unique<SQLiteStore>(path);},seed);
    auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(10);
    while(!store->ready()){require(std::chrono::steady_clock::now()<deadline,Error::StorageUnavailable);std::this_thread::sleep_for(std::chrono::milliseconds(1));}
    inventory=std::make_unique<DurableInventory>(std::move(store),seed);game=std::make_unique<GameRuntime>(*inventory,definitions);
    auto recovered=game->state();
    for(unsigned slot=2;slot<=20;++slot)if(recovered.controls.at({5,999+slot}).connected){
        auto reply=execute(std::to_string(slot)+" "+id_text({0x50524553454e4345ULL^inventory->epoch(),slot})+" online 0");
        require(reply.find("\"code\":0,")==1,Error::StorageUnavailable);
    }
}
std::string Host::execute(const std::string& line) {
    try {
        require(line.size()<=2048,Error::InvalidRequest);std::istringstream input(line);unsigned slot;std::string id,verb;
        require(bool(input>>slot>>id>>verb)&&slot<=20,Error::InvalidRequest);
        if(verb=="show"){std::string extra;require(slot&&!(input>>extra),Error::InvalidRequest);return view(slot);}
        if(verb=="sync"){
            std::int32_t offset;std::string extra;require(slot>=2&&bool(input>>offset)&&!(input>>extra),Error::InvalidRequest);
            fireClocks[slot]={offset,game->state().tick+600};return "{\"code\":0}";
        }
        auto admitted=game->state();
        GamePeer peer{slot?Id{7,slot}:simulation_account,slot?Id{5,999+slot}:Id{},slot==0};
        peer.local=slot<=1;peer.clockOffset=fireClocks[slot].first;peer.clockReady=fireClocks[slot].second>admitted.tick;
        require(verb!="fire"||peer.local,Error::NotAccessible);
        auto requestId=parse_id(id);std::optional<GameCommand> old;
        if(auto saved=inventory->recorded_request(peer.account,requestId))old=decode_command(saved->command);
        auto remaining=std::string(std::istreambuf_iterator<char>(input),{});input.clear();input.str(verb+" "+remaining);
        auto c=verb=="r-fire"?remote_fire(input,requestId,inventory->epoch(),bool(old)):command(input,admitted,peer,requestId,old);
        require(verb!="r-fire"||slot>=2,Error::NotAccessible);
        auto result=game->dispatch(c,peer);auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2);
        while(result.code==Error::Pending&&std::chrono::steady_clock::now()<deadline){std::this_thread::sleep_for(std::chrono::milliseconds(1));result=inventory->resolve();}
        return "{\"code\":"+std::to_string(unsigned(result.code))+",\"sequence\":"+std::to_string(result.sequence)+",\"request\":\""+id_text(requestId)+"\",\"tick\":"+std::to_string(game->state().tick)+"}";
    } catch(const Violation& e){return "{\"code\":"+std::to_string(unsigned(e.code))+"}";}
}
bool Host::close(){
    auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2);
    do {
        auto result=inventory->close();if(result.code==Error::Ok)return true;
        if(result.code!=Error::Pending&&result.code!=Error::Busy)return false;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }while(std::chrono::steady_clock::now()<deadline);return false;
}
}
