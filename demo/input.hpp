#pragma once
#include "console.hpp"
#include <charconv>
#include <istream>

template<class T> T number(std::string_view token) {
    T value{};
    auto [end, error] = std::from_chars(token.data(), token.data() + token.size(), value);
    if (error != std::errc{} || end != token.data() + token.size())
        throw std::runtime_error("Expected an unsigned integer in range.");
    return value;
}
inline std::string token(std::istream& in) {
    std::string value;
    if (!(in >> value)) throw std::runtime_error("Missing command argument.");
    return value;
}
inline Id item_id(std::istream& in) {
    auto value = token(in);
    auto colon = value.find(':');
    auto result = colon == std::string::npos ? id(number<std::uint64_t>(value)) :
        Id{number<std::uint64_t>(std::string_view(value).substr(0, colon)),
           number<std::uint64_t>(std::string_view(value).substr(colon + 1))};
    require(bool(result), Error::InvalidRequest);
    return result;
}
inline void end_command(std::istream& in) {
    std::string extra;
    if (in >> extra) throw std::runtime_error("Unexpected trailing argument.");
}
