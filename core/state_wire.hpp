#pragma once
#include "wire.hpp"
#include <bit>
#include <cmath>
#include <map>
#include <array>
namespace astra {
struct StateSave {
    Writer writer;
    unsigned version{2};
    template<class T> void value(const T& v) {
        if constexpr(std::is_same_v<T,Id>)writer.id(v);
        else if constexpr(std::is_same_v<T,bool>)writer.put(v,1);
        else if constexpr(std::is_integral_v<T>)writer.put(std::uint64_t(v),sizeof(T));
        else if constexpr(std::is_enum_v<T>)value(static_cast<std::underlying_type_t<T>>(v));
        else if constexpr(std::is_floating_point_v<T>) {
            require(std::isfinite(v),Error::InvalidState);
            if constexpr(sizeof(T)==8)writer.put(std::bit_cast<std::uint64_t>(v),8);else writer.put(std::bit_cast<std::uint32_t>(v),4);
        }else if constexpr(requires{std::tuple_size<T>::value;}){for(const auto& item:v)value(item);}
        else state_fields(*this,v);
    }
    template<class... T> void operator()(const T&... v){(value(v),...);}
    template<class T> void sequence(const std::vector<T>& v,std::size_t limit){require(v.size()<=limit,Error::LimitExceeded);writer.put(v.size(),4);for(const auto& row:v)value(row);}
    template<class K,class V> void dictionary(const std::map<K,V>& v,std::size_t limit){require(v.size()<=limit,Error::LimitExceeded);writer.put(v.size(),4);for(const auto& [k,row]:v){value(k);value(row);}}
    template<class T> void optional(const std::optional<T>& v){value(bool(v));if(v)value(*v);}
};
struct StateLoad {
    Reader reader;
    unsigned version{2};
    template<class T> void value(T& v) {
        if constexpr(std::is_same_v<T,Id>)v=reader.id();
        else if constexpr(std::is_same_v<T,bool>){auto n=reader.get(1);require(n<=1,Error::InvalidState);v=n;}
        else if constexpr(std::is_integral_v<T>){auto n=std::make_unsigned_t<T>(reader.get(sizeof(T)));v=std::bit_cast<T>(n);}
        else if constexpr(std::is_enum_v<T>){std::underlying_type_t<T> n{};value(n);v=static_cast<T>(n);}
        else if constexpr(std::is_floating_point_v<T>){if constexpr(sizeof(T)==8)v=std::bit_cast<T>(reader.get(8));else v=std::bit_cast<T>(std::uint32_t(reader.get(4)));require(std::isfinite(v),Error::InvalidState);}
        else if constexpr(requires{std::tuple_size<T>::value;}){for(auto& item:v)value(item);}
        else state_fields(*this,v);
    }
    template<class... T> void operator()(T&... v){(value(v),...);}
    std::size_t count(std::size_t limit){auto n=reader.get(4);require(n<=limit&&n<=reader.bytes.size()-reader.position,Error::LimitExceeded);return n;}
    template<class T> void sequence(std::vector<T>& v,std::size_t limit){auto n=count(limit);v.clear();for(std::size_t i=0;i<n;++i){T row{};value(row);v.push_back(std::move(row));}}
    template<class K,class V> void dictionary(std::map<K,V>& v,std::size_t limit){auto n=count(limit);v.clear();for(std::size_t i=0;i<n;++i){K k{};V row{};value(k);value(row);require(v.emplace(k,std::move(row)).second,Error::InvalidState);}}
    template<class T> void optional(std::optional<T>& v){bool present{};value(present);if(present){v.emplace();value(*v);}else v.reset();}
};
}
