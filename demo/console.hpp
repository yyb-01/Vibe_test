#pragma once
#include "session.hpp"
#include <string>
std::string label(Id);
void restore(const std::filesystem::path&, const std::filesystem::path&);
Request parse_command(Session&, const std::string&);
void show(const World&);
bool command(Session&, const std::string&, Request&, bool&);
