#pragma once
// ---------------------------------------------------------------------------
// PitchDetector – YIN-based pitch detection
//
// Reference: A. de Cheveigné & H. Kawahara, "YIN, a fundamental frequency
// estimator for speech and music," JASA 111(4), 2002.
// ---------------------------------------------------------------------------

#include <vector>

class PitchDetector
{
public:
    /// @param sampleRate  Audio sample rate in Hz.
    /// @param bufferSize  Number of samples analysed per call.
    explicit PitchDetector (double sampleRate, int bufferSize = 4096);

    /// Analyses [bufferSize] samples from [buffer].
    /// @return Detected fundamental frequency in Hz, or 0 if not confident.
    double detect (const float* buffer, int numSamples);

    /// YIN confidence threshold (0–1).  Lower = more detections but noisier.
    void setThreshold (double t) { threshold = t; }

    /// Minimum detectable frequency (Hz).  Default: 27.5 (A0).
    void setMinFrequency (double f) { minFreq = f; }

    /// Maximum detectable frequency (Hz).  Default: 4200 (above C8).
    void setMaxFrequency (double f) { maxFreq = f; }

    double getLastConfidence () const { return lastConfidence; }

private:
    double sampleRate;
    int    bufferSize;
    double threshold    = 0.15;
    double minFreq      = 27.5;
    double maxFreq      = 4200.0;
    double lastConfidence = 0.0;

    std::vector<double> yinBuffer;

    // YIN stages
    void  computeDifference   (const float* x, int n);
    void  cumulativeMeanNorm  (int n);
    int   absoluteThreshold   (int tauMin, int tauMax);
    double parabolicInterp    (int tau, int n) const;
};
