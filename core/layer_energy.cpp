#include "layer_energy.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
std::optional<LayerEnergyPlan> layer_energy(const Vector& from, const Vector& to,
    std::span<const LayerVolume> scene, std::span<const LayerResistance> profiles, std::int64_t incoming) {
    require(incoming >= 0, Error::InvalidRequest);
    std::uint32_t previous = 0;
    for (auto profile : profiles) {
        require(profile.layerId > previous, Error::InvalidRequest);
        previous = profile.layerId;
        penetrate(incoming, profile.material.minPathUm, profile.material);
    }
    auto material = [&](std::uint32_t id) -> const Resistance& {
        auto found = std::lower_bound(profiles.begin(), profiles.end(), id,
            [](const auto& profile, auto key) { return profile.layerId < key; });
        require(found != profiles.end() && found->layerId == id, Error::InvalidRequest);
        return found->material;
    };
    for (auto layer : scene) material(layer.layerId);
    auto paths = layer_paths(from, to, scene);
    if (std::any_of(paths.begin(), paths.end(), [](const auto& path) { return !path.complete; })) return {};
    LayerEnergyPlan result{incoming, {}};
    for (auto path : paths) {
        if (!result.outgoingUj) break;
        auto transfer = penetrate(result.outgoingUj, path.pathUm, material(path.layerId));
        result.deposits.push_back({path, transfer});
        result.outgoingUj = transfer.outgoingUj;
    }
    return result;
}
}
