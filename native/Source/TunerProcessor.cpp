#include "TunerProcessor.h"

#include <cmath>
#include <algorithm>

// ---------------------------------------------------------------------------

static constexpr double kPi    = 3.14159265358979323846;
static constexpr double kLn2   = 0.69314718055994530942;

TunerProcessor::TunerProcessor (double sampleRate, int blockSize)
    : sampleRateVal (sampleRate),
      blockSizeVal  (blockSize),
      pitchDetector (sampleRate, blockSize)
{
    waveRing.resize (static_cast<size_t> (kWaveformCapacity), 0.0f);
    analysisBuf.resize (static_cast<size_t> (blockSize), 0.0f);

    // Detect piano range (A0 = 27.5 Hz … C8 ≈ 4186 Hz)
    pitchDetector.setMinFrequency (27.5);
    pitchDetector.setMaxFrequency (4200.0);
}

TunerProcessor::~TunerProcessor()
{
    stop();
}

void TunerProcessor::start()
{
    juce::AudioDeviceManager::AudioDeviceSetup setup;
    deviceManager.initialiseWithDefaultDevices (1, 0);   // 1 input, 0 output
    deviceManager.getAudioDeviceSetup (setup);
    setup.sampleRate  = sampleRateVal;
    setup.bufferSize  = blockSizeVal;
    deviceManager.setAudioDeviceSetup (setup, true);
    deviceManager.addAudioCallback (this);
}

void TunerProcessor::stop()
{
    deviceManager.removeAudioCallback (this);
    deviceManager.closeAudioDevice();
}

void TunerProcessor::setA4Frequency (double hz)
{
    a4Freq.store (hz);
}

void TunerProcessor::setNoiseFloor (double dBFS)
{
    noiseFloorLinear.store (std::pow (10.0, dBFS / 20.0), std::memory_order_release);
}

int TunerProcessor::getWaveform (float* out, int maxSamples)
{
    std::lock_guard<std::mutex> lock (waveMutex);

    const int capacity  = kWaveformCapacity;
    const int wh        = writeHead.load (std::memory_order_acquire);
    const int rh        = readHead.load  (std::memory_order_relaxed);
    const int available = (wh - rh + capacity) % capacity;

    const int n = std::min (available, maxSamples);
    for (int i = 0; i < n; ++i)
    {
        out[i] = waveRing[static_cast<size_t> ((rh + i) % capacity)];
    }
    readHead.store ((rh + n) % capacity, std::memory_order_release);
    return n;
}

// ---------------------------------------------------------------------------
// AudioIODeviceCallback
// ---------------------------------------------------------------------------

void TunerProcessor::audioDeviceAboutToStart (juce::AudioIODevice* device)
{
    sampleRateVal = device->getCurrentSampleRate();
    blockSizeVal  = device->getCurrentBufferSizeSamples();

    analysisBuf.resize (static_cast<size_t> (blockSizeVal * 4), 0.0f);
    pitchDetector = PitchDetector (sampleRateVal,
                                   static_cast<int> (analysisBuf.size()));
    pitchDetector.setMinFrequency (27.5);
    pitchDetector.setMaxFrequency (4200.0);
}

void TunerProcessor::audioDeviceStopped() {}

void TunerProcessor::audioDeviceIOCallbackWithContext (
    const float* const*  inputChannelData,
    int                  numInputChannels,
    float* const*        /*outputChannelData*/,
    int                  /*numOutputChannels*/,
    int                  numSamples,
    const juce::AudioIODeviceCallbackContext& /*context*/)
{
    if (numSamples <= 0 || numInputChannels == 0 || inputChannelData == nullptr) return;

    const float* src = inputChannelData[0];
    if (src == nullptr) return;

    // Compute RMS to check against noise floor
    double rms = 0.0;
    for (int i = 0; i < numSamples; ++i)
        rms += static_cast<double> (src[i]) * static_cast<double> (src[i]);
    rms = std::sqrt (rms / static_cast<double> (numSamples));

    // Write samples into waveform ring buffer
    {
    std::lock_guard<std::mutex> lock (waveMutex);
    const int cap = kWaveformCapacity;
    int wh = writeHead.load (std::memory_order_relaxed);
    for (int i = 0; i < numSamples; ++i)
    {
        waveRing[static_cast<size_t> (wh)] = src[i];
        wh = (wh + 1) % cap;
    }
    writeHead.store (wh, std::memory_order_release);
    }

    if (rms < noiseFloorLinear.load (std::memory_order_acquire))
    {
        detectedFreq.store (0.0);
        detectedCents.store (0.0);
        detectedMidi.store (-1);
        detectedConf.store (0.0);
        return;
    }

    processBlock (src, numSamples);
}

// ---------------------------------------------------------------------------

void TunerProcessor::processBlock (const float* samples, int n)
{
    // Append new samples to analysis buffer (sliding window)
    const int abSize = static_cast<int> (analysisBuf.size());
    const int keep   = abSize - n;
    if (keep > 0)
        std::move (analysisBuf.begin() + n, analysisBuf.end(),
                   analysisBuf.begin());
    const int copyStart = std::max (0, abSize - n);
    const int copyN     = std::min (n, abSize);
    std::copy (samples + (n - copyN), samples + n,
               analysisBuf.begin() + copyStart);

    const double freq = pitchDetector.detect (
        analysisBuf.data(), abSize);
    const double conf = pitchDetector.getLastConfidence();

    if (freq > 0.0 && conf > 0.4)
    {
        const int    midi  = freqToMidi (freq);
        const double cents = freqToCents (freq, midi);
        detectedFreq.store  (freq);
        detectedCents.store (cents);
        detectedMidi.store  (midi);
        detectedConf.store  (conf);
    }
    else
    {
        detectedFreq.store  (0.0);
        detectedCents.store (0.0);
        detectedMidi.store  (-1);
        detectedConf.store  (0.0);
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double TunerProcessor::midiToFreq (int midi) const
{
    return a4Freq.load() * std::pow (2.0, (midi - 69) / 12.0);
}

int TunerProcessor::freqToMidi (double freq) const
{
    if (freq <= 0.0) return -1;
    const double exactMidi = 69.0 + 12.0 * std::log (freq / a4Freq.load()) / kLn2;
    return static_cast<int> (std::round (exactMidi));
}

double TunerProcessor::freqToCents (double freq, int midi) const
{
    if (freq <= 0.0) return 0.0;
    const double targetFreq = midiToFreq (midi);
    return 1200.0 * std::log (freq / targetFreq) / kLn2;
}
