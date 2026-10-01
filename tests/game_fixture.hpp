#pragma once
#include "async_fixture.hpp"
#include "game_command.hpp"
struct GameFixture {
    GameDefinitions defs=survival_definitions();
    AsyncScenario storage;
    GameRuntime game;
    GamePeer player{{7,1},{5,1000},false,true};
    std::uint64_t nonce{};
    explicit GameFixture(unsigned players=1):storage(survival_seed(defs,players)),game(*storage.inventory,defs){}
    ~GameFixture(){storage.probe->release();eventually([&]{return storage.inventory->close().code!=Error::Pending;});}
    GameCommand command(GameOperation operation){GameCommand c;c.id={0x5445535447414d45ULL,++nonce};c.operation=operation;return c;}
    Result send(GameCommand c,GamePeer p) {
        auto r=game.dispatch(c,p);eventually([&]{if(r.code==Error::Pending)r=storage.inventory->resolve();return r.code!=Error::Pending;});return r;
    }
    Result send(GameCommand c){return send(c,player);}
    void ticks(unsigned count) {
        for(unsigned i=0;i<count;++i){auto c=command(GameOperation::Tick);c.tick=game.state().tick+1;auto r=send(c,{simulation_account,{},true});CHECK(r.applied());}
    }
};
