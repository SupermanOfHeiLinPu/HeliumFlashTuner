#pragma once
// ---------------------------------------------------------------------------
// TunerProcessor – JUCE audio input handler
//
// Manages the AudioDeviceManager, applies a simple noise gate, and feeds
// blocks of samples to PitchDetector.  Thread-safe accessors allow the
// Flutter UI (or any other thread) to read the current pitch data.
// ---------------------------------------------------------------------------

#include <juce_audio_devices/juce_audio_devices.h>
#include <juce_dsp/juce_dsp.h>
#include <atomic>
#include <mutex>
#include <vector>

#include "PitchDetector.h"

class TunerProcessor : public juce::AudioIODeviceCallback
{
public:
    explicit TunerProcessor (double sampleRate = 44100.0,
                             int    blockSize  = 4096);
    ~TunerProcessor() override;

    // ---- Lifecycle --------------------------------------------------------
    void start();
    void stop();

    // ---- Settings ---------------------------------------------------------
    void setA4Frequency  (double hz);
    void setNoiseFloor   (double dBFS);   ///< e.g. -60.0 dB

    // ---- Thread-safe results ----------------------------------------------
    double getA4Frequency  () const { return a4Freq.load(); }
    double getFrequency    () const { return detectedFreq.load(); }
    double getCents        () const { return detectedCents.load(); }
    int    getMidiNote     () const { return detectedMidi.load(); }
    double getConfidence   () const { return detectedConf.load(); }

    /// Copies up to [maxSamples] waveform samples into [out].
    /// @return Actual number of samples copied.
    int    getWaveform (float* out, int maxSamples);

    // ---- JUCE AudioIODeviceCallback ---------------------------------------
    void audioDeviceAboutToStart (juce::AudioIODevice* device) override;
    void audioDeviceStopped      ()                            override;
    void audioDeviceIOCallbackWithContext (
        const float* const*                inputChannelData,
        int                                numInputChannels,
        float* const*                      outputChannelData,
        int                                numOutputChannels,
        int                                numSamples,
        const juce::AudioIODeviceCallbackContext& context) override;

private:
    double           sampleRateVal;
    int              blockSizeVal;

    juce::AudioDeviceManager deviceManager;
    PitchDetector            pitchDetector;

    // Noise gate
    std::atomic<double> noiseFloorLinear { 0.0 };   ///< amplitude threshold (linear)

    // Waveform ring buffer (lock-free single-producer single-consumer)
    static constexpr int kWaveformCapacity = 8192;
    std::vector<float>   waveRing;
    std::atomic<int>     writeHead { 0 };
    std::atomic<int>     readHead  { 0 };
    std::mutex           waveMutex;

    // Last analysis buffer (copied from ring for pitch detection)
    std::vector<float> analysisBuf;

    // Atomic results
    std::atomic<double> a4Freq          { 440.0 };
    std::atomic<double> detectedFreq    { 0.0 };
    std::atomic<double> detectedCents   { 0.0 };
    std::atomic<int>    detectedMidi    { -1 };
    std::atomic<double> detectedConf    { 0.0 };

    // Helpers
    void   processBlock (const float* samples, int n);
    double freqToCents  (double freq, int midiNote) const;
    int    freqToMidi   (double freq) const;
    double midiToFreq   (int    midi) const;
};
