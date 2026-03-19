#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both Dart code and calling process.
void CreateAndAttachConsole();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty vector on failure. See
// https://learn.microsoft.com/en-us/windows/win32/api/processenv/nf-processenv-getcommandlinew
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
