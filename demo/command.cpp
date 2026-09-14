#include "input.hpp"
#include <iostream>
#include <sstream>

bool command(Session& s, const std::string& line, Request& previous, bool& hasPrevious) {
    std::istringstream in(line);
    std::string verb; in >> verb;
    if (verb.empty()) return true;
    if (verb == "show") { end_command(in); show(*s.snapshot()); return true; }
    Result result;
    if (verb == "resolve") { end_command(in); result = s.resolve(); }
    else {
        Request r;
        if (verb == "replay") {
            end_command(in);
            if (!hasPrevious) throw std::runtime_error("No previous request.");
            r = previous;
        } else r = parse_command(s, line);
        // Keep the original request available even if storage returns an error.
        previous = r; hasPrevious = true;
        result = s.apply(decode(encode(r)));
    }
    std::cout << (result.applied() ? (s.persistent() ? "Committed to SQLite" : "Applied in memory") : name(result.code))
              << " sequence=" << result.sequence << " created=" << label(result.created) << '\n';
    if (result.code == Error::Pending) std::cout << "Save pending. Use resolve or replay; quit settles storage first.\n";
    return result.applied();
}
