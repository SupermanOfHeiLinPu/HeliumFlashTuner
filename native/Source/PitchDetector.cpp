#include "PitchDetector.h"
#include <cmath>
#include <algorithm>

PitchDetector::PitchDetector (double sr, int bufSize)
    : sampleRate (sr), bufferSize (bufSize)
{
    yinBuffer.resize (static_cast<size_t> (bufSize / 2), 0.0);
}

double PitchDetector::detect (const float* buffer, int numSamples)
{
    const int W = std::min (numSamples, bufferSize);
    const int halfW = W / 2;

    if (halfW < 2)
    {
        lastConfidence = 0.0;
        return 0.0;
    }

    if (static_cast<int> (yinBuffer.size()) < halfW)
        yinBuffer.resize (static_cast<size_t> (halfW), 0.0);

    // --- 1. Difference function ---
    computeDifference (buffer, W);

    // --- 2. Cumulative mean normalised difference ---
    cumulativeMeanNorm (halfW);

    // Tau range corresponding to [minFreq .. maxFreq]
    int tauMin = static_cast<int> (std::floor (sampleRate / maxFreq));
    int tauMax = static_cast<int> (std::ceil  (sampleRate / minFreq));
    tauMin = std::max (tauMin, 2);
    tauMax = std::min (tauMax, halfW - 1);

    if (tauMin >= tauMax)
    {
        lastConfidence = 0.0;
        return 0.0;
    }

    // --- 3. Absolute threshold ---
    int tau = absoluteThreshold (tauMin, tauMax);

    if (tau <= 0)
    {
        lastConfidence = 0.0;
        return 0.0;
    }

    // --- 4. Parabolic interpolation for sub-sample accuracy ---
    double tauPrecise = parabolicInterp (tau, halfW);

    lastConfidence = 1.0 - yinBuffer[static_cast<size_t> (tau)];

    return sampleRate / tauPrecise;
}

// ---------------------------------------------------------------------------

void PitchDetector::computeDifference (const float* x, int W)
{
    const int halfW = W / 2;
    for (int tau = 0; tau < halfW; ++tau)
    {
        double sum = 0.0;
        for (int j = 0; j < halfW; ++j)
        {
            const double delta = static_cast<double> (x[j]) -
                                 static_cast<double> (x[j + tau]);
            sum += delta * delta;
        }
        yinBuffer[static_cast<size_t> (tau)] = sum;
    }
}

void PitchDetector::cumulativeMeanNorm (int halfW)
{
    yinBuffer[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < halfW; ++tau)
    {
        runningSum += yinBuffer[static_cast<size_t> (tau)];
        if (runningSum < 1e-12)
            yinBuffer[static_cast<size_t> (tau)] = 1.0;
        else
            yinBuffer[static_cast<size_t> (tau)] *= static_cast<double> (tau) / runningSum;
    }
}

int PitchDetector::absoluteThreshold (int tauMin, int tauMax)
{
    for (int tau = tauMin; tau <= tauMax; ++tau)
    {
        if (yinBuffer[static_cast<size_t> (tau)] < threshold)
        {
            // Find local minimum beyond this point
            while (tau + 1 <= tauMax &&
                   yinBuffer[static_cast<size_t> (tau + 1)] <
                   yinBuffer[static_cast<size_t> (tau)])
            {
                ++tau;
            }
            return tau;
        }
    }

    // No tau below threshold – return the minimum value tau as a fallback
    int best = tauMin;
    for (int tau = tauMin + 1; tau <= tauMax; ++tau)
    {
        if (yinBuffer[static_cast<size_t> (tau)] <
            yinBuffer[static_cast<size_t> (best)])
        {
            best = tau;
        }
    }

    // Only return if confidence is reasonably high
    if (yinBuffer[static_cast<size_t> (best)] < 0.5)
        return best;

    return -1;
}

double PitchDetector::parabolicInterp (int tau, int halfW) const
{
    if (tau <= 0 || tau >= halfW - 1)
        return static_cast<double> (tau);

    const double s0 = yinBuffer[static_cast<size_t> (tau - 1)];
    const double s1 = yinBuffer[static_cast<size_t> (tau)];
    const double s2 = yinBuffer[static_cast<size_t> (tau + 1)];

    const double denom = 2.0 * (s0 - 2.0 * s1 + s2);
    if (std::abs (denom) < 1e-12)
        return static_cast<double> (tau);

    return static_cast<double> (tau) + (s0 - s2) / denom;
}
