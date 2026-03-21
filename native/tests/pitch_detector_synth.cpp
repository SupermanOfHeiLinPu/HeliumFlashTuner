#include <cmath>
#include <iomanip>
#include <iostream>
#include <vector>

#include "../Source/PitchDetector.h"

namespace
{
constexpr double kSampleRate = 44100.0;
constexpr int kBufferSize = 16384;
constexpr double kPi = 3.14159265358979323846;

double runSineTest (double frequency)
{
    std::vector<float> samples (static_cast<size_t> (kBufferSize), 0.0f);
    for (int i = 0; i < kBufferSize; ++i)
    {
        const double phase = 2.0 * kPi * frequency * static_cast<double> (i) / kSampleRate;
        samples[static_cast<size_t> (i)] = static_cast<float> (0.8 * std::sin (phase));
    }

    PitchDetector detector (kSampleRate, kBufferSize);
    detector.setThreshold (0.10);
    detector.setMinFrequency (27.5);
    detector.setMaxFrequency (4200.0);
    return detector.detect (samples.data(), static_cast<int> (samples.size()));
}
}

int main ()
{
    const std::vector<double> frequencies { 110.0, 220.0, 440.0, 880.0, 1760.0 };

    std::cout << std::fixed << std::setprecision (3);
    for (double frequency : frequencies)
    {
        const double detected = runSineTest (frequency);
        const double errorHz = detected - frequency;
        const double errorPercent = (errorHz / frequency) * 100.0;

        std::cout
            << "target=" << frequency
            << " detected=" << detected
            << " errorHz=" << errorHz
            << " errorPercent=" << errorPercent
            << '\n';
    }

    return 0;
}