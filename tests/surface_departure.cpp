#include "check.hpp"
#include "barrier_scene.hpp"
#include <array>

void surface_departure_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    const SurfaceKey previous{1, 1, 0};
    std::array scene{Barrier{previous, {{0, -10, -10}, {10, 10, 10}}}};
    CHECK(first_barrier({}, {-100, 0, 0}, scene, 0));
    CHECK(!first_barrier({}, {-100, 0, 0}, scene, 0, previous));
    CHECK(first_barrier({}, {100, 0, 0}, scene, 0, previous)); // Inward.
    CHECK(first_barrier({}, {0, 100, 0}, scene, 0, previous)); // Tangent.
    CHECK(first_barrier({}, {}, scene, 0, previous)); // Stationary.
    CHECK(first_barrier({1, 0, 0}, {-100, 0, 0}, scene, 0, previous)); // Interior is not a departure.
    CHECK(first_barrier({-100, 0, 0}, {100, 0, 0}, scene, 0, previous)); // Return later.
    CHECK(!first_barrier({-5, 0, 0}, {-105, 0, 0}, scene, 5, previous));
    CHECK(!first_barrier({10, 0, 0}, {110, 0, 0}, scene, 0, previous));
    std::array adjacent{scene[0], Barrier{{2, 1, 0}, {{-50, -10, -10}, {-49, 10, 10}}}};
    auto hit = first_barrier({}, {-100, 0, 0}, adjacent, 0, previous);
    CHECK(hit && hit->key.surface == 2); // Same collider, another 1um wall within 0.1mm offset.
    adjacent[1].key = {1, 1, 1};
    hit = first_barrier({}, {-100, 0, 0}, adjacent, 0, previous);
    CHECK(hit && hit->key.triangle == 1);
    adjacent[1].box.max[0] = adjacent[1].box.min[0];
    rejects([&] { first_barrier({}, {-100, 0, 0}, adjacent, 0, previous); }, Error::InvalidRequest);
    rejects([&] { first_barrier({}, {}, {}, 0, {0, 1, 0}); }, Error::InvalidRequest);
}
