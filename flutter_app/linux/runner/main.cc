#include "my_application.h"

#include <csignal>
#include <cstdlib>

namespace {

void handleTerminateSignal(int /*signal*/) {
  // Forced shutdown path: avoid complex teardown that can crash in native audio stack.
  std::_Exit(0);
}

void installTerminateHandlers() {
  std::signal(SIGTERM, handleTerminateSignal);
  std::signal(SIGINT, handleTerminateSignal);
}

}  // namespace

int main(int argc, char** argv) {
  installTerminateHandlers();

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
