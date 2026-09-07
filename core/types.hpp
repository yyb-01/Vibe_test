#pragma once
#include <compare>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <type_traits>

namespace astra {
struct Id {
    std::uint64_t hi{}, lo{};
    auto operator<=>(const Id&) const = default;
    explicit operator bool() const { return hi || lo; }
};
inline constexpr auto revision_limit = std::uint64_t(INT64_MAX);
struct ItemDef {
    std::uint32_t id{}, massG{}, outerVolumeMl{}, maxStack{1};
    std::uint16_t gridW{1}, gridH{1}, classId{}, materialId{};
    std::uint32_t containerDefId{}, partDefId{}, assetId{}, flags{};
    bool operator==(const ItemDef&) const = default;
};
inline constexpr std::uint32_t deleted = 1;
struct alignas(8) ItemState {
    Id id;
    std::uint64_t revision{1};
    std::uint32_t defId{}, quantity{1};
    std::uint32_t extraIndex{UINT32_MAX}, flags{};
    std::uint16_t durability{UINT16_MAX}, contamination{};
    std::uint16_t wetness{}, temperatureOffset{12000};
    std::uint64_t birthEvent{}, reservedBy{};
    bool operator==(const ItemState&) const = default;
};
enum class PlaceKind : std::uint8_t { Grid, Slot, Socket, Escrow, World };
struct alignas(8) ContainerState {
    Id id, ownerItem;
    std::uint64_t revision{1}, subtreeMassG{};
    std::uint32_t usedVolumeMl{}, capacityMl{};
    std::uint16_t width{}, height{}, entryCount{};
    std::uint8_t depth{}, flags{};
    bool operator==(const ContainerState&) const = default;
};
struct Placement {
    Id item, container;
    std::uint32_t socketId{};
    std::uint16_t x{}, y{};
    std::uint8_t rotation{};
    PlaceKind kind{PlaceKind::Grid};
    std::uint16_t reserved{};
    std::uint32_t ordinal{};
    bool operator==(const Placement&) const = default;
};
static_assert(sizeof(Id) == 16);
static_assert(sizeof(ItemDef) == 40);
static_assert(sizeof(ItemState) == 64);
static_assert(offsetof(ItemState, revision) == 16);
static_assert(sizeof(ContainerState) == 64);
static_assert(sizeof(Placement) == 48);
static_assert(std::is_trivially_copyable_v<ItemState>);
}
