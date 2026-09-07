#include "pg_util.hpp"
#include <algorithm>

namespace astra {
PostgresStore::PostgresStore(std::string connection,Id world)
    :connection_(std::move(connection)),world_(pg::uuid(world)) { require(bool(world),Error::InvalidState); }
StoredWorld PostgresStore::acquire(const Checkpoint& seed) {
    auto initial=pg::hex(encode_checkpoint(seed));
    pg::Connection db(connection_); db.begin();
    db.query("INSERT INTO astra.world(world_id,epoch,origin,version,checkpoint) VALUES($1::uuid,$2::bigint,$3::bigint,0,decode($4,'hex')) ON CONFLICT DO NOTHING",
             {world_,std::to_string(seed.epoch),std::to_string(seed.origin),initial});
    auto loaded=pg::locked_world(db,world_);
    require(loaded.checkpoint.catalog==seed.catalog,Error::Incompatible);
    require(loaded.checkpoint.epoch<revision_limit,Error::LimitExceeded);
    auto origin=db.query("SELECT nextval('astra.origin_seq')");
    auto& c=loaded.checkpoint;
    ++c.epoch; c.origin=pg::number(pg::value(origin,0,0)); c.nextId=1; c.nextEvent=1;
    for(const auto& [id,item]:c.world.items) {
        if(id.hi==c.origin) {
            require(id.lo<revision_limit && item.birthEvent<revision_limit,Error::LimitExceeded);
            c.nextId=std::max(c.nextId,id.lo+1); c.nextEvent=std::max(c.nextEvent,item.birthEvent+1);
        }
    }
    for(const auto& [id,container]:c.world.containers) {
        (void)container;
        if(id.hi==c.origin) { require(id.lo<revision_limit,Error::LimitExceeded); c.nextId=std::max(c.nextId,id.lo+1); }
    }
    db.query("UPDATE astra.world SET epoch=$2::bigint,origin=$3::bigint,checkpoint=decode($4,'hex') WHERE world_id=$1::uuid",
             {world_,std::to_string(c.epoch),std::to_string(c.origin),pg::hex(encode_checkpoint(c))});
    db.commit(); epoch_=c.epoch;
    return loaded;
}
StoredWorld PostgresStore::inspect() {
    pg::Connection db(connection_); db.begin();
    auto loaded=pg::locked_world(db,world_);
    db.commit();
    return loaded;
}
SaveOutcome PostgresStore::save(std::uint64_t version,const Checkpoint& target,const SavedRequest& record) {
    require(target.epoch==epoch_ && version<revision_limit && !target.requests.empty(),Error::InvalidState);
    const auto& last=target.requests.back();
    require(last.account==record.account && last.requestId==record.requestId && last.actionSeq==record.actionSeq &&
            last.payload==record.payload && last.result.code==record.result.code &&
            last.result.sequence==record.result.sequence && last.result.created==record.result.created,Error::InvalidState);
    auto bytes=encode_checkpoint(target);
    auto encoded=pg::hex(bytes);
    for(unsigned attempt=0;attempt<3;++attempt) {
        bool committing=false;
        try {
            pg::Connection db(connection_); db.begin();
            auto current=pg::locked_world(db,world_);
            if(current.checkpoint.epoch!=epoch_) return SaveOutcome::Fenced;
            if(current.version!=version) {
                if(current.version==version+1 && encode_checkpoint(current.checkpoint)==bytes) return SaveOutcome::Committed;
                return SaveOutcome::Fenced;
            }
            require(current.checkpoint.origin==target.origin && current.checkpoint.catalog==target.catalog &&
                    target.requests.size()==current.checkpoint.requests.size()+1,Error::InvalidState);
            auto newVersion=std::to_string(version+1);
            db.query("INSERT INTO astra.request_result(world_id,account_id,request_id,action_seq,payload,result_code,state_sequence,created_id,world_version) VALUES($1::uuid,$2::uuid,$3::uuid,$4::bigint,decode($5,'hex'),$6::integer,$7::bigint,$8::uuid,$9::bigint)",
                     {world_,pg::uuid(record.account),pg::uuid(record.requestId),std::to_string(record.actionSeq),
                      pg::hex(record.payload),std::to_string(static_cast<unsigned>(record.result.code)),
                      std::to_string(record.result.sequence),pg::uuid(record.result.created),newVersion});
            db.query("UPDATE astra.world SET checkpoint=decode($2,'hex'),version=$3::bigint WHERE world_id=$1::uuid",
                     {world_,encoded,newVersion});
            db.query("INSERT INTO astra.outbox(world_id,world_version) VALUES($1::uuid,$2::bigint)",
                     {world_,newVersion});
            committing=true;
            db.commit();
            return SaveOutcome::Committed;
        } catch(const pg::Failure& error) {
            if(committing) return SaveOutcome::Unknown;
            if((error.state=="40001" || error.state=="40P01") && attempt+1<3) continue;
            return SaveOutcome::Aborted;
        } catch(...) {
            return committing?SaveOutcome::Unknown:SaveOutcome::Aborted;
        }
    }
    return SaveOutcome::Aborted;
}
}
