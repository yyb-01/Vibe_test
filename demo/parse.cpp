#include "input.hpp"
#include <sstream>

Request parse_command(Session& s, const std::string& line) {
    std::istringstream in(line);
    auto verb = token(in);
    auto item = item_id(in);
    auto state = s.snapshot();
    Operation op = Operation::Move;
    std::vector<MoveEntry> moves;
    if (verb == "swap") {
        auto target = item_id(in);
        auto a = state->placements.at(item), b = state->placements.at(target);
        auto ma = move(*state, item, b.container, b.x, b.y);
        auto mb = move(*state, target, a.container, a.x, a.y);
        ma.rotation = b.rotation; ma.socketId = b.socketId;
        mb.rotation = a.rotation; mb.socketId = a.socketId;
        moves = {ma, mb}; op = Operation::Swap;
    } else {
        Id target;
        std::uint32_t quantity{};
        std::uint16_t x{}, y{};
        if (verb == "take") target = id(20);
        else if (verb == "drop") { target = id(30); op = Operation::Drop; }
        else if (verb == "move" || verb == "merge" || verb == "split") {
            if (verb == "split") { quantity = number<std::uint32_t>(token(in)); op = Operation::Split; }
            if (verb == "merge") op = Operation::Merge;
            target = item_id(in);
        } else throw std::runtime_error("Unknown command.");
        if (verb != "drop") {
            x = number<std::uint16_t>(token(in)); y = number<std::uint16_t>(token(in));
        }
        auto m = move(*state, item, target, x, y);
        if (op == Operation::Split) m.quantity = quantity;
        if (verb == "take" && m.source == id(30)) op = Operation::Pickup;
        moves.push_back(m);
    }
    end_command(in);
    return s.request(op, std::move(moves));
}
