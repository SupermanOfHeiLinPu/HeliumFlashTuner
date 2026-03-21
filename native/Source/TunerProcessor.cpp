#include "TunerProcessor.h"

#include <cmath>
#include <algorithm>
#include <numeric>

// ---------------------------------------------------------------------------

static constexpr double kPi    = 3.14159265358979323846;
static constexpr double kLn2   = 0.69314718055994530942;
static constexpr double kDefaultNoiseFloorLinear = 0.0005623413251903491; // -65 dBFS
static constexpr double kYinThreshold           = 0.10;
static constexpr double kMinConfidenceToTrack    = 0.45;
static constexpr int    kDetectionHoldFrames     = 10;
static constexpr double kLockedMidiHysteresisCents = 55.0;
static constexpr double kOvertoneRejectRatio     = 1.5;
static constexpr double kOvertoneMatchToleranceCents = 160.0;
static constexpr double kSubharmonicScoreTolerance = 0.94;
static constexpr double kRefineTauWindowFraction = 0.08;
static constexpr int    kRefineTauWindowMinimum  = 4;
static constexpr double kLagPreferenceTolerance  = 0.985;
static constexpr int    kLargeJumpSemitoneThreshold = 19;
static constexpr int    kLargeJumpConfirmFrames = 6;

TunerProcessor::TunerProcessor (double sampleRate, int blockSize)
    : sampleRateVal (sampleRate),
      blockSizeVal  (blockSize),
      pitchDetector (sampleRate, blockSize)
{
    waveRing.resize (static_cast<size_t> (kWaveformCapacity), 0.0f);
    analysisBuf.resize (static_cast<size_t> (blockSize), 0.0f);
    analysisWork.resize (static_cast<size_t> (blockSize), 0.0f);
    noiseFloorLinear.store (kDefaultNoiseFloorLinear);

    // Detect piano range (A0 = 27.5 Hz … C8 ≈ 4186 Hz)
    pitchDetector.setThreshold (kYinThreshold);
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
    const int available = std::min (
        availableSamples.load (std::memory_order_acquire), capacity);

    const int n = std::min (available, maxSamples);
    const int start = (wh - n + capacity) % capacity;

    for (int i = 0; i < n; ++i)
    {
        out[i] = waveRing[static_cast<size_t> ((start + i) % capacity)];
    }

    return n;
}

// ---------------------------------------------------------------------------
// AudioIODeviceCallback
// ---------------------------------------------------------------------------

void TunerProcessor::audioDeviceAboutToStart (juce::AudioIODevice* device)
{
    sampleRateVal = device->getCurrentSampleRate();
    blockSizeVal  = device->getCurrentBufferSizeSamples();
    resetTrackingState();

    analysisBuf.resize (static_cast<size_t> (blockSizeVal * 4), 0.0f);
    analysisWork.resize (analysisBuf.size(), 0.0f);
    pitchDetector = PitchDetector (sampleRateVal,
                                   static_cast<int> (analysisBuf.size()));
    pitchDetector.setThreshold (kYinThreshold);
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

    if (rms < noiseFloorLinear.load (std::memory_order_acquire))
    {
        ++missedDetectionFrames;
        if (missedDetectionFrames > kDetectionHoldFrames)
            resetTrackingState();
        return;
    }

    // Only refresh the displayed waveform when input is above the noise floor.
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

        const int currentAvailable = availableSamples.load (std::memory_order_relaxed);
        availableSamples.store (
            std::min (cap, currentAvailable + numSamples),
            std::memory_order_release);
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

    std::copy (analysisBuf.begin(), analysisBuf.end(), analysisWork.begin());
    const float mean = std::accumulate (analysisWork.begin(),
                                        analysisWork.end(),
                                        0.0f) /
                       static_cast<float> (analysisWork.size());
    for (float& sample : analysisWork)
        sample -= mean;

    const double freq = pitchDetector.detect (
        analysisWork.data(), abSize);
    const double conf = pitchDetector.getLastConfidence();

    if (freq > 0.0 && conf >= kMinConfidenceToTrack)
    {
        const double candidateFreq =
            refineFrequencyCandidate (normalizeFrequencyCandidate (freq));
        pushFrequencySample (candidateFreq);

        const double medianFreq = medianFrequency();
        const double targetLogFrequency = std::log (medianFreq);

        if (! hasSmoothedFrequency)
        {
            smoothedLogFrequency = targetLogFrequency;
            hasSmoothedFrequency = true;
        }
        else
        {
            const double alpha = std::max (0.12,
                                           std::min (0.40,
                                                     0.12 + conf * 0.28));
            smoothedLogFrequency +=
                (targetLogFrequency - smoothedLogFrequency) * alpha;
        }

        const double stableFreq = std::exp (smoothedLogFrequency);
        const int    midi       = updateLockedMidi (stableFreq);
        const double cents      = freqToCents (stableFreq, midi);

        detectedFreq.store  (stableFreq);
        detectedCents.store (cents);
        detectedMidi.store  (midi);
        detectedConf.store  (conf);
        missedDetectionFrames = 0;
    }
    else
    {
        ++missedDetectionFrames;
        if (missedDetectionFrames > kDetectionHoldFrames)
            resetTrackingState();
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void TunerProcessor::resetTrackingState ()
{
    recentFreqs.fill (0.0);
    recentFreqIndex = 0;
    recentFreqCount = 0;
    missedDetectionFrames = 0;
    hasSmoothedFrequency = false;
    smoothedLogFrequency = 0.0;
    lockedMidiNote = -1;
    pendingHighJumpMidi = -1;
    pendingHighJumpFrames = 0;

    detectedFreq.store  (0.0);
    detectedCents.store (0.0);
    detectedMidi.store  (-1);
    detectedConf.store  (0.0);
}

void TunerProcessor::pushFrequencySample (double freq)
{
    recentFreqs[static_cast<size_t> (recentFreqIndex)] = freq;
    recentFreqIndex = (recentFreqIndex + 1) % kFreqHistorySize;
    recentFreqCount = std::min (recentFreqCount + 1, kFreqHistorySize);
}

double TunerProcessor::medianFrequency () const
{
    if (recentFreqCount <= 0)
        return 0.0;

    std::array<double, kFreqHistorySize> sorted = recentFreqs;
    std::sort (sorted.begin(), sorted.begin() + recentFreqCount);

    const int medianIndex = recentFreqCount / 2;
    if ((recentFreqCount % 2) != 0)
        return sorted[static_cast<size_t> (medianIndex)];

    return 0.5 * (sorted[static_cast<size_t> (medianIndex - 1)] +
                  sorted[static_cast<size_t> (medianIndex)]);
}

double TunerProcessor::normalizedAutocorrelationAtLag (int lag) const
{
    const int size = static_cast<int> (analysisWork.size());
    if (lag <= 0 || lag >= size - 1)
        return -1.0;

    double numerator = 0.0;
    double energyA = 0.0;
    double energyB = 0.0;

    for (int i = 0; i < size - lag; ++i)
    {
        const double a = analysisWork[static_cast<size_t> (i)];
        const double b = analysisWork[static_cast<size_t> (i + lag)];
        numerator += a * b;
        energyA += a * a;
        energyB += b * b;
    }

    if (energyA <= 1e-12 || energyB <= 1e-12)
        return -1.0;

    return numerator / std::sqrt (energyA * energyB);
}

double TunerProcessor::refineFrequencyCandidate (double freq) const
{
    if (freq <= 0.0)
        return freq;

    const double approxTau = sampleRateVal / freq;
    const int centerTau = static_cast<int> (std::round (approxTau));
    if (centerTau <= 1)
        return freq;

    const int tauWindow = std::max (
        kRefineTauWindowMinimum,
        static_cast<int> (std::round (approxTau * kRefineTauWindowFraction)));
    int bestTau = centerTau;
    double bestScore = -1.0;
    for (int tau = std::max (2, centerTau - tauWindow);
         tau <= centerTau + tauWindow;
         ++tau)
    {
        const double score = normalizedAutocorrelationAtLag (tau);
        if (score > bestScore)
        {
            bestScore = score;
            bestTau = tau;
        }
        else if (score >= bestScore * kLagPreferenceTolerance && tau > bestTau)
        {
            bestTau = tau;
        }
    }

    const double s0 = normalizedAutocorrelationAtLag (bestTau - 1);
    const double s1 = normalizedAutocorrelationAtLag (bestTau);
    const double s2 = normalizedAutocorrelationAtLag (bestTau + 1);

    double tauPrecise = static_cast<double> (bestTau);
    if (s0 >= 0.0 && s1 >= 0.0 && s2 >= 0.0)
    {
        const double denom = 2.0 * (s0 - 2.0 * s1 + s2);
        if (std::abs (denom) >= 1e-12)
            tauPrecise += (s0 - s2) / denom;
    }

    if (tauPrecise <= 1.0)
        return freq;

    return sampleRateVal / tauPrecise;
}

double TunerProcessor::normalizeFrequencyCandidate (double freq) const
{
    if (! hasSmoothedFrequency)
        return freq;

    const double referenceFreq = std::exp (smoothedLogFrequency);
    if (referenceFreq <= 0.0 || freq <= referenceFreq * kOvertoneRejectRatio)
        return freq;

    double bestFreq = freq;
    double bestDistance = std::abs (1200.0 * std::log (freq / referenceFreq) / kLn2);
    const int rawLag = static_cast<int> (std::round (sampleRateVal / freq));
    const double rawScore = normalizedAutocorrelationAtLag (rawLag);

    for (int divisor = 2; divisor <= 8; ++divisor)
    {
        const double foldedFreq = freq / static_cast<double> (divisor);
        if (foldedFreq <= 0.0)
            continue;

        const int lag = static_cast<int> (std::round (sampleRateVal / foldedFreq));
        const double score = normalizedAutocorrelationAtLag (lag);
        if (rawScore > 0.0 && score < rawScore * kSubharmonicScoreTolerance)
            continue;

        const double centsDistance =
            std::abs (1200.0 * std::log (foldedFreq / referenceFreq) / kLn2);

        if (centsDistance < bestDistance)
        {
            bestDistance = centsDistance;
            bestFreq = foldedFreq;
        }
    }

    if (bestFreq != freq && bestDistance <= kOvertoneMatchToleranceCents)
        return bestFreq;

    return freq;
}

int TunerProcessor::updateLockedMidi (double freq)
{
    const int candidateMidi = freqToMidi (freq);
    if (candidateMidi < 0)
        return -1;

    if (lockedMidiNote < 0)
    {
        lockedMidiNote = candidateMidi;
        return lockedMidiNote;
    }

    const double lockedCents = freqToCents (freq, lockedMidiNote);
    if (std::abs (lockedCents) <= kLockedMidiHysteresisCents)
    {
        pendingHighJumpMidi = -1;
        pendingHighJumpFrames = 0;
        return lockedMidiNote;
    }

    if (candidateMidi - lockedMidiNote >= kLargeJumpSemitoneThreshold)
    {
        if (pendingHighJumpMidi == candidateMidi)
            ++pendingHighJumpFrames;
        else
        {
            pendingHighJumpMidi = candidateMidi;
            pendingHighJumpFrames = 1;
        }

        if (pendingHighJumpFrames < kLargeJumpConfirmFrames)
            return lockedMidiNote;
    }

    pendingHighJumpMidi = -1;
    pendingHighJumpFrames = 0;

    lockedMidiNote = candidateMidi;
    return lockedMidiNote;
}

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
