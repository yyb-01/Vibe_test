#include "console.hpp"
#include <iostream>
#include <sstream>

bool command(Scenario& s, const std::string& line, Request& previous, bool& hasPrevious) {
    std::istringstream in(line);
    std::string verb; in >> verb;
    if (verb.empty()) return true;
    if (verb == "show") { show(*s.inventory.snapshot()); return true; }
    Request r;
    if (verb == "replay") {
        if (!hasPrevious) throw std::runtime_error("No previous request.");
        r = previous;
    } else {
        std::uint64_t item{}, target{};
        std::uint32_t quantity{};
        std::uint16_t x{}, y{};
        if (!(in >> item)) throw std::runtime_error("Expected item ID.");
        auto state = s.inventory.snapshot();
        Operation op = Operation::Move;
        std::vector<MoveEntry> moves;
        if (verb == "swap") {
            if (!(in >> target)) throw std::runtime_error("Expected second item ID.");
            auto a = state->placements.at(id(item)), b = state->placements.at(id(target));
            auto ma = move(*state, id(item), b.container, b.x, b.y);
            auto mb = move(*state, id(target), a.container, a.x, a.y);
            ma.rotation = b.rotation; ma.socketId = b.socketId;
            mb.rotation = a.rotation; mb.socketId = a.socketId;
            moves = {ma, mb}; op = Operation::Swap;
        } else {
            if (verb == "take") { target = 20; in >> x >> y; }
            else if (verb == "drop") { target = 30; op = Operation::Drop; }
            else if (verb == "move" || verb == "merge" || verb == "split") {
                if (verb == "split") { in >> quantity; op = Operation::Split; }
                if (verb == "merge") op = Operation::Merge;
                in >> target >> x >> y;
            } else throw std::runtime_error("Unknown command.");
            if (!in) throw std::runtime_error("Invalid command arguments.");
            auto m = move(*state, id(item), id(target), x, y);
            if (op == Operation::Split) m.quantity = quantity;
            if (verb == "take" && m.source == id(30)) op = Operation::Pickup;
            moves.push_back(m);
        }
        std::string extra;
        if (in >> extra) throw std::runtime_error("Unexpected trailing argument.");
        r = s.request(op, std::move(moves));
        previous = r; hasPrevious = true;
    }
    auto result = s.inventory.apply(decode(encode(r)), s.access);
    std::cout << (result.applied() ? "Applied in memory" : name(result.code))
              << " sequence=" << result.sequence << " created=" << result.created.lo << '\n';
    return result.applied();
}
