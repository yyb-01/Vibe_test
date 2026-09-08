#pragma once
#include "durable.hpp"
#include <sqlite3.h>
#include <filesystem>
#include <string>

namespace astra::sq {
inline void check(int code) {
    require(code == SQLITE_OK, Error::StorageUnavailable);
}
class Connection {
    std::unique_ptr<sqlite3, decltype(&sqlite3_close)> db_{nullptr, sqlite3_close};
public:
    explicit Connection(const std::filesystem::path& path, bool readOnly = false) {
        auto text = path.u8string();
        sqlite3* raw{};
        auto code = sqlite3_open_v2(reinterpret_cast<const char*>(text.c_str()), &raw,
            (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) |
            SQLITE_OPEN_FULLMUTEX, nullptr);
        db_.reset(raw); check(code);
        sqlite3_limit(raw, SQLITE_LIMIT_LENGTH, static_cast<int>(checkpoint_byte_limit + 4096));
        check(sqlite3_busy_timeout(raw, 1000));
        exec("PRAGMA foreign_keys=ON; PRAGMA trusted_schema=OFF");
    }
    sqlite3* get() const { return db_.get(); }
    void exec(const char* sql) { check(sqlite3_exec(get(), sql, nullptr, nullptr, nullptr)); }
};
class Statement {
    std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)> stmt_{nullptr, sqlite3_finalize};
public:
    Statement(Connection& db, const char* sql) {
        sqlite3_stmt* raw{};
        auto code = sqlite3_prepare_v2(db.get(), sql, -1, &raw, nullptr);
        stmt_.reset(raw); check(code);
    }
    sqlite3_stmt* get() const { return stmt_.get(); }
    void number(int index, std::uint64_t n) {
        require(n <= revision_limit, Error::LimitExceeded);
        check(sqlite3_bind_int64(get(), index, static_cast<sqlite3_int64>(n)));
    }
    void blob(int index, const std::vector<std::uint8_t>& bytes) {
        check(sqlite3_bind_blob64(get(), index, bytes.data(), bytes.size(), SQLITE_TRANSIENT));
    }
    bool row() {
        auto code = sqlite3_step(get());
        require(code == SQLITE_ROW || code == SQLITE_DONE, Error::StorageUnavailable);
        return code == SQLITE_ROW;
    }
    std::uint64_t number(int column) const {
        auto n = sqlite3_column_int64(get(), column);
        require(sqlite3_column_type(get(), column) == SQLITE_INTEGER && n >= 0, Error::InvalidState);
        return static_cast<std::uint64_t>(n);
    }
};
inline bool value(Connection& db, const char* sql, const char* expected) {
    Statement query(db, sql);
    return query.row() && sqlite3_column_type(query.get(), 0) != SQLITE_NULL &&
        std::string(reinterpret_cast<const char*>(sqlite3_column_text(query.get(), 0))) == expected;
}
void configure(Connection&);
StoredWorld load(Connection&);
void write(Connection&, std::uint64_t, const std::vector<std::uint8_t>&);
}
