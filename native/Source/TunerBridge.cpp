#include "TunerBridge.h"
#include "TunerProcessor.h"

#include <memory>

// Singleton processor instance owned by the bridge.
static std::unique_ptr<TunerProcessor> g_processor;

extern "C" {

TUNER_EXPORT void tuner_init (int sampleRate)
{
    g_processor = std::make_unique<TunerProcessor> (
        static_cast<double> (sampleRate), 4096);
}

TUNER_EXPORT void tuner_start ()
{
    if (g_processor) g_processor->start();
}

TUNER_EXPORT void tuner_stop ()
{
    if (g_processor) g_processor->stop();
}

TUNER_EXPORT void tuner_cleanup ()
{
    g_processor.reset();
}

TUNER_EXPORT void tuner_set_a4_frequency (double freq)
{
    if (g_processor) g_processor->setA4Frequency (freq);
}

TUNER_EXPORT double tuner_get_a4_frequency ()
{
    if (!g_processor) return 440.0;
    return g_processor->getA4Frequency();
}

TUNER_EXPORT double tuner_get_frequency ()
{
    if (!g_processor) return 0.0;
    return g_processor->getFrequency();
}

TUNER_EXPORT double tuner_get_cents ()
{
    if (!g_processor) return 0.0;
    return g_processor->getCents();
}

TUNER_EXPORT int tuner_get_midi_note ()
{
    if (!g_processor) return -1;
    return g_processor->getMidiNote();
}

TUNER_EXPORT double tuner_get_confidence ()
{
    if (!g_processor) return 0.0;
    return g_processor->getConfidence();
}

TUNER_EXPORT int tuner_get_waveform (float* buffer, int maxSamples)
{
    if (!g_processor || buffer == nullptr || maxSamples <= 0) return 0;
    return g_processor->getWaveform (buffer, maxSamples);
}

TUNER_EXPORT void tuner_set_noise_floor (double dBFS)
{
    if (g_processor) g_processor->setNoiseFloor (dBFS);
}

} // extern "C"
