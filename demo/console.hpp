#pragma once
#include "../samples/scenario.hpp"
#include <string>
void show(const World&);
bool command(Scenario&, const std::string&, Request&, bool&);
