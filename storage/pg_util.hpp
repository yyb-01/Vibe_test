#pragma once
#include "postgres.hpp"
#include <libpq-fe.h>
#include <charconv>
#include <stdexcept>

namespace astra::pg {
inline std::string uuid(Id id) {
    constexpr char digits[]="0123456789abcdef";
    std::string s(32,'0');
    for(unsigned i=0;i<16;++i) { s[15-i]=digits[(id.hi>>(i*4))&15]; s[31-i]=digits[(id.lo>>(i*4))&15]; }
    return s;
}
inline std::string hex(const std::vector<std::uint8_t>& bytes) {
    constexpr char digits[]="0123456789abcdef";
    std::string result; result.reserve(bytes.size()*2);
    for(auto b:bytes) { result.push_back(digits[b>>4]); result.push_back(digits[b&15]); }
    return result;
}
inline std::vector<std::uint8_t> unhex(std::string_view s) {
    require(s.size()%2==0 && s.size()/2<=checkpoint_byte_limit,Error::InvalidState);
    auto digit=[](char c)->unsigned {
        if(c>='0'&&c<='9') return c-'0';
        require(c>='a'&&c<='f',Error::InvalidState); return c-'a'+10;
    };
    std::vector<std::uint8_t> result; result.reserve(s.size()/2);
    for(std::size_t i=0;i<s.size();i+=2) result.push_back((digit(s[i])<<4)|digit(s[i+1]));
    return result;
}
inline std::uint64_t number(std::string_view s) {
    std::uint64_t n{}; auto parsed=std::from_chars(s.data(),s.data()+s.size(),n);
    require(parsed.ec==std::errc{} && parsed.ptr==s.data()+s.size() && n<=revision_limit,Error::InvalidState);
    return n;
}
struct Failure : std::runtime_error {
    std::string state;
    explicit Failure(std::string code):std::runtime_error("PostgreSQL operation failed: "+code),state(std::move(code)) {}
};
using Rows=std::unique_ptr<PGresult,decltype(&PQclear)>;
inline std::string_view value(const Rows& r,int row,int col) {
    require(row<PQntuples(r.get()) && col<PQnfields(r.get()) && !PQgetisnull(r.get(),row,col),Error::InvalidState);
    return {PQgetvalue(r.get(),row,col),static_cast<std::size_t>(PQgetlength(r.get(),row,col))};
}
class Connection {
    std::unique_ptr<PGconn,decltype(&PQfinish)> connection_;
public:
    explicit Connection(const std::string& text):connection_(PQconnectdb(text.c_str()),PQfinish) {
        if(!connection_ || PQstatus(connection_.get())!=CONNECTION_OK) throw Failure("connection");
    }
    Rows query(const char* sql,const std::vector<std::string>& params={}) {
        std::vector<const char*> pointers;
        for(const auto& p:params) pointers.push_back(p.c_str());
        Rows result(PQexecParams(connection_.get(),sql,static_cast<int>(pointers.size()),nullptr,
                                 pointers.data(),nullptr,nullptr,0),PQclear);
        auto status=PQresultStatus(result.get());
        if(status!=PGRES_COMMAND_OK && status!=PGRES_TUPLES_OK) {
            auto code=result?PQresultErrorField(result.get(),PG_DIAG_SQLSTATE):nullptr;
            throw Failure(code?code:"connection");
        }
        return result;
    }
    void begin() {
        query("BEGIN ISOLATION LEVEL SERIALIZABLE");
        query("SET LOCAL synchronous_commit = on");
        query("SET LOCAL statement_timeout = '5s'");
        query("SET LOCAL lock_timeout = '5s'");
        auto settings=query("SELECT current_setting('fsync'), current_setting('full_page_writes')");
        require(value(settings,0,0)=="on" && value(settings,0,1)=="on",Error::InvalidState);
        auto schema=query("SELECT version FROM astra.schema_version WHERE singleton");
        require(value(schema,0,0)=="1",Error::InvalidState);
    }
    void commit() {
        auto result=query("COMMIT");
        if(std::string_view(PQcmdStatus(result.get()))!="COMMIT") throw Failure("commit");
    }
};
inline StoredWorld locked_world(Connection& db,const std::string& world) {
    auto rows=db.query("SELECT version, epoch, origin, encode(checkpoint,'hex') FROM astra.world WHERE world_id=$1::uuid FOR UPDATE",{world});
    auto c=decode_checkpoint(unhex(value(rows,0,3)));
    require(c.epoch==number(value(rows,0,1)) && c.origin==number(value(rows,0,2)),Error::InvalidState);
    return {std::move(c),number(value(rows,0,0))};
}
}
