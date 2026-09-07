#include "pg_util.hpp"
#include "../tests/scenario.hpp"
#include <cstdlib>
#include <iostream>

namespace {
std::string connection;
Checkpoint seed_checkpoint() { Inventory i(catalog(),seed(),1,1); return i.checkpoint(); }
Access access(const DurableInventory& i) { return {{77,1},i.epoch(),99,{id(10),id(20),id(30)}}; }
Request split_request() {
    Inventory initial(catalog(),seed(),1,1);
    auto part=move(*initial.snapshot(),id(100),id(20)); part.quantity=7;
    return {{88,1},1,Operation::Split,{part},0,99};
}
std::uint64_t count(const char* table,Id world) {
    pg::Connection db(connection);
    std::string sql="SELECT count(*) FROM astra."; sql+=table; sql+=" WHERE world_id=$1::uuid";
    auto r=db.query(sql.c_str(),{pg::uuid(world)}); return pg::number(pg::value(r,0,0));
}
enum class Fault { None, Abort, LostBefore, LostAfter, CrashAfter };
class FaultStore : public DurableStore {
    PostgresStore real_;
public:
    Fault fault{};
    bool inspectFails{};
    explicit FaultStore(Id world):real_(connection,world) {}
    StoredWorld acquire(const Checkpoint& seed) override { return real_.acquire(seed); }
    SaveOutcome save(std::uint64_t v,const Checkpoint& c,const SavedRequest& r) override {
        if(fault==Fault::Abort) return SaveOutcome::Aborted;
        if(fault==Fault::LostBefore) return SaveOutcome::Unknown;
        auto result=real_.save(v,c,r);
        if(result==SaveOutcome::Committed && fault==Fault::CrashAfter) std::_Exit(73);
        if(result==SaveOutcome::Committed && fault==Fault::LostAfter) return SaveOutcome::Unknown;
        return result;
    }
    StoredWorld inspect() override {
        if(inspectFails) throw std::runtime_error("Injected unavailable result lookup");
        return real_.inspect();
    }
};
void restart_and_fencing() {
    Id world{900,1}; auto seed=seed_checkpoint();
    DurableInventory first(std::make_unique<PostgresStore>(connection,world),seed);
    auto request=split_request();
    auto saved=first.apply(request,access(first));
    CHECK(saved.applied() && saved.sequence==1);
    DurableInventory second(std::make_unique<PostgresStore>(connection,world),seed);
    CHECK(second.epoch()>first.epoch());
    auto replay=second.apply(request,access(second));
    CHECK(replay.applied() && replay.created==saved.created && replay.sequence==saved.sequence);
    auto altered=request; altered.moves[0].quantity=6;
    CHECK(second.apply(altered,access(second)).code==Error::IdempotencyMismatch);
    auto part=move(*second.snapshot(),id(100),id(20),5); part.quantity=1;
    Request next{{88,2},2,Operation::Split,{part},1,99};
    CHECK(first.apply(next,access(first)).code==Error::EpochMismatch);
    CHECK(first.snapshot()->items.at(id(100)).quantity==13);
    auto made=second.apply(next,access(second));
    CHECK(made.applied() && made.created.hi!=saved.created.hi);
    Request invalid{{88,3},3,Operation::Move,{move(*second.snapshot(),id(100),id(20),UINT16_MAX)},2,99};
    CHECK(second.apply(invalid,access(second)).code==Error::InvalidPlacement);
    DurableInventory third(std::make_unique<PostgresStore>(connection,world),seed);
    CHECK(third.apply(invalid,access(third)).code==Error::InvalidPlacement);
    CHECK(count("request_result",world)==3 && count("outbox",world)==3);
}
void uncertain_results() {
    Id world{900,2}; auto driver=std::make_unique<FaultStore>(world); auto* fault=driver.get();
    DurableInventory inventory(std::move(driver),seed_checkpoint());
    auto request=split_request(); auto old=inventory.snapshot();
    fault->fault=Fault::Abort;
    CHECK(inventory.apply(request,access(inventory)).code==Error::StorageUnavailable);
    CHECK(inventory.snapshot()==old && count("request_result",world)==0);
    fault->fault=Fault::LostBefore;
    CHECK(inventory.apply(request,access(inventory)).code==Error::Pending);
    CHECK(inventory.resolve().code==Error::StorageUnavailable);
    fault->fault=Fault::LostAfter;
    CHECK(inventory.apply(request,access(inventory)).code==Error::Pending);
    CHECK(inventory.snapshot()==old && count("request_result",world)==1);
    auto other=request; other.id={88,2};
    CHECK(inventory.apply(other,access(inventory)).code==Error::Busy);
    auto changed=request; changed.moves[0].quantity=6;
    CHECK(inventory.apply(changed,access(inventory)).code==Error::IdempotencyMismatch);
    fault->inspectFails=true;
    CHECK(inventory.resolve().code==Error::Pending);
    fault->inspectFails=false;
    auto recovered=inventory.apply(request,access(inventory));
    CHECK(recovered.applied() && recovered.sequence==1);
    CHECK(inventory.snapshot()->items.at(id(100)).quantity==13);
    CHECK(inventory.apply(request,access(inventory)).created==recovered.created);
    CHECK(count("request_result",world)==1 && count("outbox",world)==1);
    auto settled=inventory.snapshot();
    Request rejected{{88,2},2,Operation::Move,{move(*settled,id(100),id(20),UINT16_MAX)},1,99};
    CHECK(inventory.apply(rejected,access(inventory)).code==Error::Pending);
    CHECK(inventory.resolve().code==Error::InvalidPlacement);
    CHECK(inventory.snapshot()==settled);
    DurableInventory restart(std::make_unique<PostgresStore>(connection,world),seed_checkpoint());
    CHECK(restart.apply(rejected,access(restart)).code==Error::InvalidPlacement);
    CHECK(count("request_result",world)==2 && count("outbox",world)==2);

    Id fencedWorld{900,4}; auto lost=std::make_unique<FaultStore>(fencedWorld); lost->fault=Fault::LostAfter;
    DurableInventory previous(std::move(lost),seed_checkpoint());
    auto previousState=previous.snapshot();
    CHECK(previous.apply(request,access(previous)).code==Error::Pending);
    DurableInventory owner(std::make_unique<PostgresStore>(connection,fencedWorld),seed_checkpoint());
    CHECK(previous.resolve().code==Error::EpochMismatch);
    CHECK(previous.snapshot()==previousState);
    CHECK(owner.apply(request,access(owner)).applied());
    CHECK(owner.snapshot()->items.at(id(100)).quantity==13 && count("request_result",fencedWorld)==1);
}
void transaction_rollback_and_retry() {
    Id world{900,3}; DurableInventory inventory(std::make_unique<PostgresStore>(connection,world),seed_checkpoint());
    pg::Connection db(connection);
    db.query("CREATE FUNCTION astra.test_outbox_failure() RETURNS trigger LANGUAGE plpgsql AS 'BEGIN RAISE EXCEPTION ''injected outbox failure''; END'");
    db.query("CREATE TRIGGER test_outbox_failure BEFORE INSERT ON astra.outbox FOR EACH ROW EXECUTE FUNCTION astra.test_outbox_failure()");
    auto old=inventory.snapshot(); auto request=split_request();
    CHECK(inventory.apply(request,access(inventory)).code==Error::StorageUnavailable);
    CHECK(inventory.snapshot()==old);
    CHECK(count("request_result",world)==0 && count("outbox",world)==0);
    db.query("DROP TRIGGER test_outbox_failure ON astra.outbox");
    db.query("CREATE SEQUENCE astra.test_retry");
    db.query("CREATE FUNCTION astra.test_serialization() RETURNS trigger LANGUAGE plpgsql AS 'BEGIN IF nextval(''astra.test_retry'') < 3 THEN RAISE EXCEPTION ''injected serialization failure'' USING ERRCODE = ''40001''; END IF; RETURN NEW; END'");
    db.query("CREATE TRIGGER test_serialization BEFORE INSERT ON astra.outbox FOR EACH ROW EXECUTE FUNCTION astra.test_serialization()");
    CHECK(inventory.apply(request,access(inventory)).applied());
    auto retries=db.query("SELECT last_value FROM astra.test_retry");
    CHECK(pg::number(pg::value(retries,0,0))==3);
    CHECK(count("request_result",world)==1 && count("outbox",world)==1);
    db.query("ALTER SEQUENCE astra.test_retry RESTART WITH 1");
    db.query("CREATE OR REPLACE FUNCTION astra.test_serialization() RETURNS trigger LANGUAGE plpgsql AS 'BEGIN PERFORM nextval(''astra.test_retry''); RAISE EXCEPTION ''injected repeated serialization failure'' USING ERRCODE = ''40001''; END'");
    auto settled=inventory.snapshot();
    Request next{{88,2},2,Operation::Move,{move(*settled,id(100),id(10),4)},1,99};
    CHECK(inventory.apply(next,access(inventory)).code==Error::StorageUnavailable);
    CHECK(inventory.snapshot()==settled && count("request_result",world)==1);
    retries=db.query("SELECT last_value FROM astra.test_retry");
    CHECK(pg::number(pg::value(retries,0,0))==3);
    db.query("DROP TRIGGER test_serialization ON astra.outbox");
    CHECK(inventory.apply(next,access(inventory)).sequence==2);
    CHECK(count("request_result",world)==2 && count("outbox",world)==2);
}
void crash_after_commit() {
    auto store=std::make_unique<FaultStore>(Id{900,99}); store->fault=Fault::CrashAfter;
    DurableInventory inventory(std::move(store),seed_checkpoint());
    (void)inventory.apply(split_request(),access(inventory));
    throw std::runtime_error("Expected crash after durable commit");
}
void recover_after_crash() {
    Id world{900,99}; auto seed=seed_checkpoint();
    DurableInventory inventory(std::make_unique<PostgresStore>(connection,world),seed);
    auto replay=inventory.apply(split_request(),access(inventory));
    CHECK(replay.applied() && replay.sequence==1);
    CHECK(inventory.snapshot()->items.at(id(100)).quantity==13);
    CHECK(inventory.snapshot()->items.at(replay.created).quantity==7);
    CHECK(count("request_result",world)==1 && count("outbox",world)==1);
    Request merge{{88,2},2,Operation::Merge,{move(*inventory.snapshot(),replay.created,id(10),0)},1,99};
    CHECK(inventory.apply(merge,access(inventory)).applied());
    DurableInventory again(std::make_unique<PostgresStore>(connection,world),seed);
    CHECK(again.snapshot()->items.at(replay.created).flags & deleted);
    CHECK(again.snapshot()->items.at(id(100)).quantity==20);
    CHECK(again.apply(merge,access(again)).sequence==2);
    CHECK(count("request_result",world)==2 && count("outbox",world)==2);
}
}
int main(int argc,char** argv) {
    try {
        auto text=std::getenv("ASTRA_TEST_CONNINFO");
        if(!text || argc!=2) throw std::runtime_error("Set ASTRA_TEST_CONNINFO and select functional/crash/recover");
        connection=text;
        std::string_view mode=argv[1];
        if(mode=="functional") {
            restart_and_fencing(); std::cout<<"PASS PostgreSQL restart, replay, epoch fencing\n";
            uncertain_results(); std::cout<<"PASS PostgreSQL uncertain result reconciliation\n";
            transaction_rollback_and_retry(); std::cout<<"PASS PostgreSQL atomic rollback and serialization retries\n";
        } else if(mode=="crash") crash_after_commit();
        else if(mode=="recover") { recover_after_crash(); std::cout<<"PASS PostgreSQL recovery after process crash and server restart\n"; }
        else throw std::runtime_error("Unknown test phase");
        return 0;
    } catch(const Violation& e) { std::cerr<<"FAIL PostgreSQL: "<<name(e.code)<<'\n'; }
    catch(const std::exception& e) { std::cerr<<"FAIL PostgreSQL: "<<e.what()<<'\n'; }
    return 1;
}
