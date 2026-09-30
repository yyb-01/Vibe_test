#include "check.hpp"
#include "layer_paths.hpp"
#include "layer_energy.hpp"
#include <algorithm>

void layer_path_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    auto layer = [](std::uint64_t key, std::uint32_t id, std::uint64_t body, std::int64_t lo, std::int64_t hi) {
        return LayerVolume{{key, 1, 0}, id, body, {{lo, -10, -10}, {hi, 10, 10}}};
    };
    std::array scene{layer(1, 20, 0, 10, 30), layer(2, 30, 9, 20, 50), layer(3, 30, 9, 40, 70),
        layer(4, 10, 0, 10, 20), layer(5, 30, 9, 80, 90), layer(6, 30, 10, 20, 70)};
    auto paths = layer_paths({}, {100, 0, 0}, scene);
    CHECK(paths.size() == 5 && paths[0].layerId == 10 && paths[1].layerId == 20);
    CHECK(paths[2].bodyId == 9 && paths[2].pathUm == 50 && paths[2].exit[0] == 70);
    CHECK(paths[3].bodyId == 10 && paths[3].pathUm == 50);
    CHECK(paths[4].bodyId == 9 && paths[4].pathUm == 10);
    for (auto path : paths) CHECK(path.complete);
    std::array profiles{LayerResistance{10, {0, 1, 1, 100}}, LayerResistance{20, {0, 1, 1, 100}},
        LayerResistance{30, {0, 1, 1, 100}}};
    auto energy = layer_energy({}, {100, 0, 0}, scene, profiles, 1000);
    CHECK(energy && energy->deposits.size() == 5 && energy->outgoingUj == 860);
    std::int64_t sum = energy->outgoingUj;
    for (auto deposit : energy->deposits) sum += deposit.energy.depositedUj;
    CHECK(sum == 1000);
    energy = layer_energy({}, {100, 0, 0}, scene, profiles, 5);
    CHECK(energy && energy->deposits.size() == 1 && energy->outgoingUj == 0);
    CHECK(energy->deposits[0].path.layerId == 10 && energy->deposits[0].energy.depositedUj == 5);
    CHECK(!layer_energy({}, {45, 0, 0}, scene, profiles, 1000));
    rejects([&] { layer_energy({}, {100, 0, 0}, scene, {}, 1000); }, Error::InvalidRequest);
    auto reverse = layer_paths({100, 0, 0}, {}, scene);
    CHECK(reverse.size() == 5 && reverse[0].pathUm == 10);
    CHECK(reverse[1].entry[0] == 70 && reverse[1].exit[0] == 20 && reverse[1].pathUm == 50);
    auto partial = layer_paths({25, 0, 0}, {45, 0, 0}, scene);
    for (auto path : partial) CHECK(!path.complete);
    std::array tiny{layer(1, 1, 9, 0, 1), layer(2, 1, 9, 2, 3)};
    auto narrow = layer_paths({-8000000000LL, 0, 0}, {8000000000LL, 0, 0}, tiny);
    CHECK(narrow.size() == 2 && narrow[0].pathUm == 1 && narrow[1].pathUm == 1);
    CHECK(narrow[0].contact.fraction == narrow[1].contact.fraction);
    tiny[1].box.min[0] = 1;
    narrow = layer_paths({-1, 0, 0}, {4, 0, 0}, tiny);
    CHECK(narrow.size() == 1 && narrow[0].pathUm == 3);
    tiny = {layer(1, 1, 9, 20, 40), layer(2, 1, 9, 10, 30)};
    narrow = layer_paths({20, 0, 0}, {50, 0, 0}, tiny);
    CHECK(narrow.size() == 1 && !narrow[0].complete && narrow[0].pathUm == 20);
    CHECK(layer_paths({0, 10, 0}, {100, 10, 0}, scene).empty());
    CHECK(layer_paths({25, 0, 0}, {25, 0, 0}, scene).empty());
    auto invalid = scene; invalid[2].layerId = 99;
    rejects([&] { layer_paths({0, 99, 0}, {100, 99, 0}, invalid); }, Error::InvalidRequest);
    invalid = scene; std::swap(invalid[0], invalid[1]);
    rejects([&] { layer_paths({}, {100, 0, 0}, invalid); }, Error::InvalidRequest);
    rejects([&] { layer_paths({INT64_MAX, 0, 0}, {}, {}); }, Error::InvalidRequest);
}
