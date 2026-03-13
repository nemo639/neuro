"""
Speech Feature Extractor
Handles: Story Recall, Sustained Vowel, Picture Description mini-tests.
Produces the 35-feature vector expected by SpeechNeuroNet.

Audio Processing Pipeline:
  1. Flutter records audio → uploads WAV to backend via /api/v1/tests/{id}/audio
  2. raw_data includes 'server_audio_path' pointing to uploads/audio/*.wav
  3. This extractor loads the WAV with librosa and extracts acoustic features
  4. Falls back to metadata-only features when audio file is unavailable
"""

import logging
import os
from typing import Any, Dict, List

import numpy as np

from app.ml.extractors.base_extractor import BaseExtractor

logger = logging.getLogger(__name__)

# The 35 features SpeechNeuroNet expects, in exact order
SPEECH_FEATURE_COLS: List[str] = [
    # Prosodic (7)
    "speech_rate", "pause_count", "mean_pause_duration", "max_pause_duration",
    "pause_rate", "speech_silence_ratio", "total_duration",
    # MFCC (13)
    "mfcc_1_mean", "mfcc_2_mean", "mfcc_3_mean", "mfcc_4_mean", "mfcc_5_mean",
    "mfcc_6_mean", "mfcc_7_mean", "mfcc_8_mean", "mfcc_9_mean", "mfcc_10_mean",
    "mfcc_11_mean", "mfcc_12_mean", "mfcc_13_mean",
    # Voice Quality (5)
    "jitter", "shimmer", "hnr", "f0_mean", "f0_std",
    # Formants (6)
    "f1_mean", "f2_mean", "f3_mean", "f1_std", "f2_std", "f3_std",
    # Temporal (4)
    "zcr_mean", "spectral_centroid_mean", "spectral_rolloff_mean", "energy_std",
]

# Upload directory (matches config.settings.UPLOAD_DIR)
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "uploads")


def _check_librosa():
    """Check if librosa is available."""
    try:
        import librosa  # noqa: F401
        return True
    except ImportError:
        return False


_LIBROSA_AVAILABLE = _check_librosa()


class SpeechExtractor(BaseExtractor):
    category = "speech"

    async def _extract_item(self, item_name: str, raw: Dict[str, Any]) -> Dict[str, Any]:
        dispatch = {
            "story_recall": self._story_recall,
            "sustained_vowel": self._sustained_vowel,
            "picture_description": self._picture_description,
        }
        handler = dispatch.get(item_name)
        if handler is None:
            return {}
        return handler(raw)

    # ------------------------------------------------------------------ #
    # Story Recall                                                        #
    # ------------------------------------------------------------------ #
    def _story_recall(self, raw: dict) -> dict:
        # Flutter sends: story_duration_ms, recording_duration_ms, audio_path,
        #                server_audio_path (after upload), completed
        story_ms = self.safe_get(raw, "story_duration_ms", 0)
        recording_ms = self.safe_get(raw, "recording_duration_ms", 0)
        story_sec = story_ms / 1000.0 if story_ms else 0.0
        recording_sec = recording_ms / 1000.0 if recording_ms else 0.0

        features: dict = {
            "story_duration": story_sec,
            "story_recall_accuracy": min(recording_sec / max(story_sec, 1.0), 1.0),
            "story_coherence": 0.5,  # requires transcription; default neutral
        }

        # Process uploaded audio if available
        audio_features = self._try_process_audio(raw)
        if audio_features:
            features.update(audio_features)

        return features

    # ------------------------------------------------------------------ #
    # Sustained Vowel (/aah/)                                             #
    # ------------------------------------------------------------------ #
    def _sustained_vowel(self, raw: dict) -> dict:
        # Flutter sends: trials=[{duration_ms, target_duration_ms, audio_path,
        #                server_audio_path}], total_duration_ms, completed
        total_ms = self.safe_get(raw, "total_duration_ms", 0)
        trials = raw.get("trials", [])

        best_ms = 0
        target_ms = 5000
        if isinstance(trials, list) and trials:
            best_ms = max((t.get("duration_ms", 0) for t in trials), default=0)
            target_ms = trials[0].get("target_duration_ms", 5000)

        vowel_dur = best_ms / 1000.0
        target_dur = target_ms / 1000.0

        features: dict = {
            "vowel_duration": vowel_dur,
            "vowel_stability": min(vowel_dur / max(target_dur, 1.0), 1.0),
            "vowel_amplitude_var": 0.0,
        }

        # Try each trial's audio for the best acoustic features
        audio_features = self._try_process_audio(raw)
        if not audio_features and isinstance(trials, list):
            for trial in trials:
                audio_features = self._try_process_audio(trial)
                if audio_features:
                    break

        if audio_features:
            features.update(audio_features)

        # Also accept pre-computed audio_features dict
        if "audio_features" in raw:
            features.update(self._extract_acoustic_features(raw["audio_features"]))

        return features

    # ------------------------------------------------------------------ #
    # Picture Description                                                 #
    # ------------------------------------------------------------------ #
    def _picture_description(self, raw: dict) -> dict:
        # Flutter sends: trials=[{recording_duration_ms, audio_path,
        #                server_audio_path}], total_duration_ms, completed
        total_ms = self.safe_get(raw, "total_duration_ms", 0)
        trials = raw.get("trials", [])

        duration_sec = total_ms / 1000.0 if total_ms else 0.0
        if not duration_sec and isinstance(trials, list) and trials:
            duration_sec = trials[0].get("recording_duration_ms", 0) / 1000.0

        features: dict = {
            "speech_duration": duration_sec,
            "word_count": 0,
            "unique_words": 0,
            "pause_count": 0,
        }

        # Try top-level audio, then first trial audio
        audio_features = self._try_process_audio(raw)
        if not audio_features and isinstance(trials, list):
            for trial in trials:
                audio_features = self._try_process_audio(trial)
                if audio_features:
                    break

        if audio_features:
            features.update(audio_features)

        if "audio_features" in raw:
            features.update(self._extract_acoustic_features(raw["audio_features"]))

        return features

    # ------------------------------------------------------------------ #
    # Audio file processing (librosa)                                     #
    # ------------------------------------------------------------------ #
    def _try_process_audio(self, raw: dict) -> dict:
        """
        Try to load and process an audio file from the server upload path.

        Looks for 'server_audio_path' in raw (set after Flutter uploads
        the file via POST /api/v1/tests/{id}/audio).
        """
        server_path = raw.get("server_audio_path", "")
        if not server_path:
            return {}

        full_path = os.path.join(UPLOAD_DIR, server_path)
        if not os.path.isfile(full_path):
            logger.debug("Audio file not found: %s", full_path)
            return {}

        if _LIBROSA_AVAILABLE:
            return self._process_audio_librosa(full_path)

        logger.info("librosa not installed; skipping audio feature extraction for %s", full_path)
        return {}

    def _process_audio_librosa(self, filepath: str) -> dict:
        """
        Extract acoustic features from a WAV file using librosa.

        Returns a dict matching SPEECH_FEATURE_COLS keys where possible.
        """
        try:
            import librosa
            import librosa.feature

            # Load at 16 kHz mono
            y, sr = librosa.load(filepath, sr=16000, mono=True)

            if len(y) < sr * 0.5:
                logger.warning("Audio too short (< 0.5s): %s", filepath)
                return {}

            features: dict = {}

            # ---- MFCC (13 coefficients) ----
            mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
            for i in range(13):
                features[f"mfcc_{i+1}_mean"] = float(mfccs[i].mean())

            # ---- F0 / Pitch ----
            f0, voiced_flag, voiced_prob = librosa.pyin(
                y, fmin=50, fmax=500, sr=sr
            )
            f0_valid = f0[~np.isnan(f0)] if f0 is not None else np.array([])
            if len(f0_valid) > 0:
                features["f0_mean"] = float(f0_valid.mean())
                features["f0_std"] = float(f0_valid.std())
            else:
                features["f0_mean"] = 0.0
                features["f0_std"] = 0.0

            # ---- Jitter (F0 perturbation) ----
            if len(f0_valid) > 2:
                periods = 1.0 / np.maximum(f0_valid, 1.0)
                jitter_abs = np.mean(np.abs(np.diff(periods)))
                features["jitter"] = float(jitter_abs / np.mean(periods)) if np.mean(periods) > 0 else 0.0
            else:
                features["jitter"] = 0.0

            # ---- Shimmer (amplitude perturbation) ----
            hop = 512
            rms = librosa.feature.rms(y=y, hop_length=hop)[0]
            if len(rms) > 2:
                shimmer_abs = np.mean(np.abs(np.diff(rms)))
                features["shimmer"] = float(shimmer_abs / np.mean(rms)) if np.mean(rms) > 0 else 0.0
            else:
                features["shimmer"] = 0.0

            # ---- HNR (Harmonics-to-Noise Ratio approximation) ----
            # Use autocorrelation-based estimate
            autocorr = np.correlate(y, y, mode="full")
            autocorr = autocorr[len(autocorr) // 2:]
            if len(autocorr) > sr // 50:
                peak_range = autocorr[sr // 500: sr // 50]
                if len(peak_range) > 0 and autocorr[0] > 0:
                    r_max = float(np.max(peak_range))
                    hnr = 10 * np.log10(r_max / max(autocorr[0] - r_max, 1e-10))
                    features["hnr"] = float(np.clip(hnr, 0, 40))
                else:
                    features["hnr"] = 0.0
            else:
                features["hnr"] = 0.0

            # ---- Formants (approximation via LPC) ----
            try:
                from scipy.signal import lfilter
                # LPC-based formant estimation
                pre_emph = np.append(y[0], y[1:] - 0.97 * y[:-1])
                # Use a windowed segment from the middle
                mid = len(pre_emph) // 2
                seg_len = min(len(pre_emph), sr // 4)
                segment = pre_emph[mid - seg_len // 2: mid + seg_len // 2]
                if len(segment) > 20:
                    segment = segment * np.hamming(len(segment))
                    # LPC order
                    order = 2 + sr // 1000
                    a = librosa.lpc(segment, order=order)
                    roots = np.roots(a)
                    roots = roots[np.imag(roots) >= 0]
                    angles = np.arctan2(np.imag(roots), np.real(roots))
                    freqs = np.sort(angles * (sr / (2 * np.pi)))
                    freqs = freqs[(freqs > 90) & (freqs < 5000)]

                    for idx, key in enumerate(["f1_mean", "f2_mean", "f3_mean"]):
                        features[key] = float(freqs[idx]) if idx < len(freqs) else 0.0
                    # Std approximation (variability over time not computed; use 0)
                    for key in ["f1_std", "f2_std", "f3_std"]:
                        features[key] = 0.0
            except Exception:
                for key in ["f1_mean", "f2_mean", "f3_mean", "f1_std", "f2_std", "f3_std"]:
                    features[key] = 0.0

            # ---- Temporal features ----
            zcr = librosa.feature.zero_crossing_rate(y)[0]
            features["zcr_mean"] = float(zcr.mean())

            spec_cent = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
            features["spectral_centroid_mean"] = float(spec_cent.mean())

            spec_roll = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
            features["spectral_rolloff_mean"] = float(spec_roll.mean())

            features["energy_std"] = float(rms.std())

            # ---- Prosodic: pause detection ----
            # Detect pauses as segments below energy threshold
            energy_threshold = np.mean(rms) * 0.3
            is_silence = rms < energy_threshold
            # Count contiguous silence segments (pauses)
            pause_starts = np.diff(is_silence.astype(int))
            pause_count = int(np.sum(pause_starts == 1))
            features["pause_count"] = pause_count

            # Pause durations
            frame_duration = hop / sr
            silence_frames = np.sum(is_silence)
            speech_frames = np.sum(~is_silence)
            total_frames = len(rms)

            features["total_duration"] = float(len(y) / sr)

            if pause_count > 0:
                total_silence_dur = silence_frames * frame_duration
                features["mean_pause_duration"] = float(total_silence_dur / pause_count)
                # Max pause duration
                max_pause = 0
                current_pause = 0
                for s in is_silence:
                    if s:
                        current_pause += 1
                        max_pause = max(max_pause, current_pause)
                    else:
                        current_pause = 0
                features["max_pause_duration"] = float(max_pause * frame_duration)
                features["pause_rate"] = float(pause_count / max(features["total_duration"], 0.1))
            else:
                features["mean_pause_duration"] = 0.0
                features["max_pause_duration"] = 0.0
                features["pause_rate"] = 0.0

            if total_frames > 0:
                features["speech_silence_ratio"] = float(speech_frames / total_frames)
            else:
                features["speech_silence_ratio"] = 0.5

            logger.info(
                "Extracted %d acoustic features from %s (duration=%.1fs)",
                len(features), filepath, features.get("total_duration", 0),
            )
            return features

        except Exception as exc:
            logger.warning("Audio processing failed for %s: %s", filepath, exc)
            return {}

    # ------------------------------------------------------------------ #
    # Derived features                                                    #
    # ------------------------------------------------------------------ #
    async def _derive_features(self, features: Dict[str, Any]) -> Dict[str, Any]:
        derived: dict = {}

        # Speech rate (words per minute)
        wc = features.get("word_count", 0)
        dur = features.get("speech_duration", 0)
        if wc and dur:
            derived["speech_rate"] = float(wc) / max(dur / 60.0, 0.1)

        # Total duration across items
        total_dur = 0.0
        for key in ("story_duration", "vowel_duration", "speech_duration"):
            total_dur += features.get(key, 0)
        if total_dur > 0:
            derived.setdefault("total_duration", total_dur)

        # Pause metrics from picture description
        if features.get("pause_count") and features.get("speech_duration"):
            pc = features["pause_count"]
            sd = features["speech_duration"]
            derived.setdefault("pause_rate", pc / max(sd, 0.1))
            derived.setdefault("mean_pause_duration", 0.0)
            derived.setdefault("max_pause_duration", 0.0)
            derived.setdefault("speech_silence_ratio", 0.5)

        return derived

    # ------------------------------------------------------------------ #
    # Pre-computed acoustic features (from Flutter or external)           #
    # ------------------------------------------------------------------ #
    def _extract_acoustic_features(self, af: dict) -> dict:
        """Extract acoustic features from a pre-computed audio_features dict."""
        features: dict = {}

        # MFCC
        mfccs = af.get("mfcc_means", [])
        if isinstance(mfccs, list):
            for i, val in enumerate(mfccs[:13], start=1):
                features[f"mfcc_{i}_mean"] = float(val)

        # Voice quality
        for key in ("jitter", "shimmer", "hnr", "f0_mean", "f0_std"):
            if key in af:
                features[key] = float(af[key])

        # Formants
        for key in ("f1_mean", "f2_mean", "f3_mean", "f1_std", "f2_std", "f3_std"):
            if key in af:
                features[key] = float(af[key])

        # Temporal
        for key in ("zcr_mean", "spectral_centroid_mean", "spectral_rolloff_mean", "energy_std"):
            if key in af:
                features[key] = float(af[key])

        # Prosodic
        for key in ("mean_pause_duration", "max_pause_duration",
                     "speech_silence_ratio", "pause_rate"):
            if key in af:
                features[key] = float(af[key])

        return features

    # ------------------------------------------------------------------ #
    # Build the 35-d vector for SpeechNeuroNet                            #
    # ------------------------------------------------------------------ #
    @staticmethod
    def build_feature_vector(features: Dict[str, Any]) -> np.ndarray:
        """
        Assemble the 35-element feature vector in the exact order
        expected by SpeechNeuroNet.  Missing features default to 0.
        """
        vec = np.zeros(len(SPEECH_FEATURE_COLS), dtype=np.float32)
        for i, col in enumerate(SPEECH_FEATURE_COLS):
            vec[i] = float(features.get(col, 0.0))
        return vec
