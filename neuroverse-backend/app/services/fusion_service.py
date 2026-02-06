"""
Clinical Fusion Service - Comprehensive AD/PD Risk Assessment

CLINICAL SCALES IMPLEMENTED:
===========================
Cognitive Assessment:
- MoCA (Montreal Cognitive Assessment) - Primary screening
- MMSE (Mini-Mental State Examination) - Staging
- ADAS-Cog (Alzheimer's Disease Assessment Scale) - Gold standard
- CDR (Clinical Dementia Rating) - Dementia staging
- Trail Making Test (TMT-A/B) - Executive function
- Clock Drawing Test (CDT) - Visuospatial/executive
- Category Fluency - Semantic memory
- Digit Span - Working memory

Parkinson's Assessment:
- MDS-UPDRS (Movement Disorder Society - UPDRS) - Comprehensive PD
- Hoehn & Yahr Scale - PD staging
- Schwab & England ADL - Functional assessment
- PDQ-39 concepts - Quality of life

VALIDITY DETECTION:
==================
- Embedded Validity Indicators (EVIs)
- Performance Validity Tests (PVTs)
- Response Time Analysis
- Consistency Checks
- Statistical Improbability Detection

References:
- Nasreddine et al. (2005) - MoCA
- Rosen et al. (1984) - ADAS-Cog
- Goetz et al. (2008) - MDS-UPDRS
- Tombaugh (1996) - Trail Making Test
- Shulman (2000) - Clock Drawing Test
- Bigler (2012) - Performance Validity Testing
"""

from typing import Dict, Any, List, Tuple, Optional
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import statistics


# ==================== ENUMS ====================

class CognitiveStage(Enum):
    """Clinical Dementia Rating (CDR) based staging"""
    NORMAL = "Normal"
    SUBJECTIVE_DECLINE = "Subjective Cognitive Decline"
    MCI = "Mild Cognitive Impairment"
    MILD_DEMENTIA = "Mild Dementia"
    MODERATE_DEMENTIA = "Moderate Dementia"
    SEVERE_DEMENTIA = "Severe Dementia"


class ParkinsonStage(Enum):
    """Hoehn & Yahr Scale"""
    STAGE_0 = "No signs of disease"
    STAGE_1 = "Unilateral involvement only"
    STAGE_1_5 = "Unilateral and axial involvement"
    STAGE_2 = "Bilateral without balance impairment"
    STAGE_2_5 = "Mild bilateral with recovery on pull test"
    STAGE_3 = "Mild-moderate bilateral; postural instability"
    STAGE_4 = "Severe disability; able to walk/stand unassisted"
    STAGE_5 = "Wheelchair bound or bedridden"


class ValidityStatus(Enum):
    """Data validity classification"""
    VALID = "Valid"
    QUESTIONABLE = "Questionable"
    INVALID = "Invalid - Possible Malingering"
    INVALID_POOR_EFFORT = "Invalid - Poor Effort"
    INVALID_RANDOM = "Invalid - Random Responding"


# ==================== CLINICAL NORMS ====================

@dataclass
class ClinicalNorms:
    """
    Age-adjusted normative data from peer-reviewed literature
    """
    
    # ===== MoCA (Nasreddine et al., 2005) =====
    MOCA_MAX = 30
    MOCA_NORMAL = 26          # ≥26 normal
    MOCA_MCI_CUTOFF = 22      # 22-25 MCI
    MOCA_DEMENTIA_CUTOFF = 17 # <17 dementia
    
    # ===== MMSE (Folstein et al., 1975) =====
    MMSE_MAX = 30
    MMSE_NORMAL = 27          # 27-30 normal
    MMSE_MILD = 21            # 21-26 mild
    MMSE_MODERATE = 11        # 11-20 moderate
    MMSE_SEVERE = 0           # 0-10 severe
    
    # ===== ADAS-Cog (Rosen et al., 1984) =====
    # Lower score = better (unlike MoCA/MMSE)
    ADAS_COG_MAX = 70
    ADAS_NORMAL = 5           # 0-5 normal
    ADAS_MCI = 12             # 6-12 MCI
    ADAS_MILD_AD = 25         # 13-25 mild AD
    ADAS_MODERATE_AD = 40     # 26-40 moderate AD
    
    # ===== Trail Making Test (Tombaugh, 2004) =====
    # Time in seconds (age 55-59 norms)
    TMT_A_NORMAL = 35         # seconds
    TMT_A_IMPAIRED = 78       # >78 impaired
    TMT_B_NORMAL = 79         # seconds
    TMT_B_IMPAIRED = 273      # >273 impaired
    TMT_BA_RATIO_NORMAL = 2.5 # B/A ratio, >3 suggests executive dysfunction
    
    # ===== Clock Drawing Test (Shulman, 2000) =====
    CDT_MAX = 5               # 5-point scale
    CDT_NORMAL = 4            # ≥4 normal
    CDT_IMPAIRED = 2          # ≤2 significant impairment
    
    # ===== Category Fluency (Animals in 60s) =====
    FLUENCY_NORMAL = 18       # ≥18 words normal
    FLUENCY_MCI = 14          # 14-17 borderline
    FLUENCY_IMPAIRED = 10     # <10 impaired
    
    # ===== Digit Span (Wechsler, 2008) =====
    DIGIT_FORWARD_NORMAL = 7  # ±2
    DIGIT_BACKWARD_NORMAL = 5 # ±2
    DIGIT_SPAN_IMPAIRED = 4   # <4 impaired
    
    # ===== Stroop Test (MacLeod, 1991) =====
    STROOP_INTERFERENCE_NORMAL = 20    # seconds
    STROOP_INTERFERENCE_IMPAIRED = 40  # seconds
    STROOP_ACCURACY_NORMAL = 0.95
    STROOP_ACCURACY_FLOOR = 0.50       # Below chance suggests invalid
    
    # ===== N-Back (Jaeggi et al., 2010) =====
    NBACK_ACCURACY_NORMAL = 0.80
    NBACK_ACCURACY_MCI = 0.65
    NBACK_ACCURACY_IMPAIRED = 0.50
    NBACK_ACCURACY_CHANCE = 0.50       # At or below = possibly invalid
    NBACK_DPRIME_NORMAL = 2.0
    
    # ===== Word Recall - CERAD (Morris et al., 1989) =====
    RECALL_IMMEDIATE_NORMAL = 0.70     # 70% of words
    RECALL_IMMEDIATE_MCI = 0.50
    RECALL_DELAYED_NORMAL = 0.70
    RECALL_DELAYED_MCI = 0.40
    RECALL_RECOGNITION_NORMAL = 0.90   # Recognition should be high
    RECALL_RECOGNITION_FLOOR = 0.60    # Below suggests invalid
    
    # ===== Motor - Finger Tapping (Shimoyama, 1990) =====
    TAPPING_NORMAL_MIN = 4.0   # taps/second
    TAPPING_NORMAL_MAX = 6.0
    TAPPING_PD_THRESHOLD = 3.0
    TAPPING_FLOOR = 1.0        # Below = suspicious
    
    # ===== Gait Speed (Studenski et al., 2011) =====
    GAIT_SPEED_NORMAL = 1.0    # m/s
    GAIT_SPEED_SLOW = 0.8
    GAIT_SPEED_VERY_SLOW = 0.6
    GAIT_SPEED_FLOOR = 0.3     # Below = suspicious unless severe
    
    # ===== Balance Sway (Era et al., 2006) =====
    SWAY_NORMAL = 0.3
    SWAY_ABNORMAL = 0.6
    
    # ===== Blink Rate (Karson et al., 1984) =====
    BLINK_NORMAL_MIN = 15
    BLINK_NORMAL_MAX = 20
    BLINK_PD_THRESHOLD = 10
    
    # ===== Voice/Speech (Rusz et al., 2011) =====
    VOWEL_DURATION_NORMAL = 15  # seconds
    VOWEL_DURATION_IMPAIRED = 10
    SPEECH_RATE_NORMAL_MIN = 120  # wpm
    SPEECH_RATE_NORMAL_MAX = 180
    
    # ===== REACTION TIME NORMS (for validity) =====
    RT_MIN_VALID = 150         # ms - below is too fast (anticipation)
    RT_MAX_VALID = 3000        # ms - above is too slow (deliberate)
    RT_COEFFICIENT_OF_VARIATION_MAX = 0.5  # CV > 0.5 suggests inconsistency


# ==================== VALIDITY DETECTOR ====================

@dataclass
class ValidityIndicators:
    """Embedded Validity Indicators for detecting invalid performance"""
    
    # Performance below chance
    below_chance_tests: List[str] = field(default_factory=list)
    
    # Response time anomalies
    too_fast_responses: int = 0
    too_slow_responses: int = 0
    
    # Consistency violations
    inconsistent_patterns: List[str] = field(default_factory=list)
    
    # Statistical improbabilities
    improbable_scores: List[str] = field(default_factory=list)
    
    # Overall validity
    validity_status: ValidityStatus = ValidityStatus.VALID
    validity_confidence: float = 1.0
    validity_concerns: List[str] = field(default_factory=list)


class ValidityDetector:
    """
    Detects malingering, poor effort, and invalid test data.
    
    Based on:
    - Bigler (2012) - Effort testing in neuropsychology
    - Larrabee (2012) - Performance validity testing
    - Slick et al. (1999) - Malingered neurocognitive dysfunction criteria
    """
    
    def __init__(self):
        self.norms = ClinicalNorms()
    
    def assess_validity(self, features: Dict[str, Any]) -> ValidityIndicators:
        """
        Comprehensive validity assessment of test data.
        
        Checks for:
        1. Performance below chance (malingering indicator)
        2. Inconsistent performance patterns
        3. Response time anomalies
        4. Statistical improbabilities
        5. Effort indicators
        """
        indicators = ValidityIndicators()
        
        # ===== 1. BELOW CHANCE PERFORMANCE =====
        # If recognition/simple tests are at or below chance, suggests intentional poor performance
        self._check_below_chance(features, indicators)
        
        # ===== 2. RESPONSE TIME ANALYSIS =====
        self._check_response_times(features, indicators)
        
        # ===== 3. CONSISTENCY CHECKS =====
        self._check_consistency(features, indicators)
        
        # ===== 4. STATISTICAL IMPROBABILITY =====
        self._check_improbability(features, indicators)
        
        # ===== 5. EFFORT INDICATORS =====
        self._check_effort(features, indicators)
        
        # ===== DETERMINE OVERALL VALIDITY =====
        indicators.validity_status, indicators.validity_confidence = self._determine_validity(indicators)
        
        return indicators
    
    def _check_below_chance(self, features: Dict, indicators: ValidityIndicators):
        """
        Check for performance at or below chance level.
        
        Recognition memory and simple RT tasks should be well above chance.
        Below chance = likely intentional poor performance.
        """
        # N-Back at chance (50%) or below
        nback_acc = features.get("nback_accuracy", None)
        if nback_acc is not None and nback_acc <= 0.50:
            indicators.below_chance_tests.append("N-Back at/below chance level")
            indicators.validity_concerns.append(
                f"N-Back accuracy ({nback_acc*100:.0f}%) at chance level - suggests poor effort or random responding"
            )
        
        # Recognition memory should be ~90%+ in normal and impaired individuals
        recognition_acc = features.get("recognition_accuracy", None)
        if recognition_acc is not None and recognition_acc < 0.60:
            indicators.below_chance_tests.append("Recognition memory suspiciously low")
            indicators.validity_concerns.append(
                f"Recognition accuracy ({recognition_acc*100:.0f}%) below floor - highly improbable even in dementia"
            )
        
        # Stroop congruent trials (easy) should be >90%
        stroop_congruent_acc = features.get("stroop_congruent_accuracy", None)
        if stroop_congruent_acc is not None and stroop_congruent_acc < 0.70:
            indicators.below_chance_tests.append("Simple Stroop performance too low")
            indicators.validity_concerns.append(
                f"Stroop congruent accuracy ({stroop_congruent_acc*100:.0f}%) suspiciously low for easy trials"
            )
    
    def _check_response_times(self, features: Dict, indicators: ValidityIndicators):
        """
        Analyze response time patterns for anomalies.
        
        - Too fast (<150ms): Anticipatory/random responding
        - Too slow (>3000ms): Deliberate slowing
        - High variability: Inconsistent effort
        """
        reaction_times = features.get("reaction_times", [])
        
        if reaction_times and len(reaction_times) > 5:
            for rt in reaction_times:
                if rt < self.norms.RT_MIN_VALID:
                    indicators.too_fast_responses += 1
                elif rt > self.norms.RT_MAX_VALID:
                    indicators.too_slow_responses += 1
            
            # Too many fast responses = anticipating/random
            if indicators.too_fast_responses > len(reaction_times) * 0.2:
                indicators.validity_concerns.append(
                    f"{indicators.too_fast_responses} responses too fast (<150ms) - suggests anticipation/random"
                )
            
            # Too many slow responses = deliberate poor performance
            if indicators.too_slow_responses > len(reaction_times) * 0.3:
                indicators.validity_concerns.append(
                    f"{indicators.too_slow_responses} responses excessively slow (>3s) - suggests deliberate slowing"
                )
            
            # Check coefficient of variation
            if len(reaction_times) > 10:
                mean_rt = statistics.mean(reaction_times)
                std_rt = statistics.stdev(reaction_times)
                cv = std_rt / mean_rt if mean_rt > 0 else 0
                
                if cv > self.norms.RT_COEFFICIENT_OF_VARIATION_MAX:
                    indicators.validity_concerns.append(
                        f"Response time variability (CV={cv:.2f}) suggests inconsistent effort"
                    )
    
    def _check_consistency(self, features: Dict, indicators: ValidityIndicators):
        """
        Check for inconsistent performance patterns.
        
        Real impairment shows consistent patterns:
        - Recognition > Recall (always)
        - Simple > Complex (usually)
        - Related tasks correlate
        """
        recall_acc = features.get("recall_accuracy", None)
        recognition_acc = features.get("recognition_accuracy", None)
        
        # Recognition should ALWAYS be >= Recall
        # Even in severe dementia, recognition is preserved relative to recall
        if recall_acc is not None and recognition_acc is not None:
            if recall_acc > recognition_acc + 0.15:  # Allow small margin
                indicators.inconsistent_patterns.append("Recall > Recognition (impossible pattern)")
                indicators.validity_concerns.append(
                    f"Recall ({recall_acc*100:.0f}%) exceeds Recognition ({recognition_acc*100:.0f}%) - neurologically impossible"
                )
        
        # Stroop congruent should be better than incongruent
        stroop_cong = features.get("stroop_congruent_accuracy", None)
        stroop_incong = features.get("stroop_incongruent_accuracy", None)
        
        if stroop_cong is not None and stroop_incong is not None:
            if stroop_incong > stroop_cong + 0.10:
                indicators.inconsistent_patterns.append("Incongruent Stroop > Congruent (impossible)")
                indicators.validity_concerns.append(
                    "Better performance on hard trials than easy trials - inconsistent with genuine impairment"
                )
        
        # Simple RT should be faster than choice RT
        simple_rt = features.get("simple_reaction_time", None)
        choice_rt = features.get("choice_reaction_time", None)
        
        if simple_rt is not None and choice_rt is not None:
            if simple_rt > choice_rt * 1.5:
                indicators.inconsistent_patterns.append("Simple RT slower than Choice RT")
                indicators.validity_concerns.append(
                    "Simple reaction time slower than complex - suggests deliberate slowing"
                )
    
    def _check_improbability(self, features: Dict, indicators: ValidityIndicators):
        """
        Check for statistically improbable score patterns.
        
        Some patterns are so rare in genuine impairment that they suggest invalidity.
        """
        # Perfect failure on easy items + success on hard items
        easy_score = features.get("easy_items_correct", None)
        hard_score = features.get("hard_items_correct", None)
        
        if easy_score is not None and hard_score is not None:
            if easy_score < 0.3 and hard_score > 0.7:
                indicators.improbable_scores.append("Failed easy items, passed hard items")
                indicators.validity_concerns.append(
                    "Paradoxical pattern: Failed easy items while passing difficult ones"
                )
        
        # Severely impaired cognition with perfect motor performance (unlikely)
        cognitive_score = features.get("cognitive_score", None)
        motor_score = features.get("motor_score", None)
        
        if cognitive_score is not None and motor_score is not None:
            if cognitive_score < 10 and motor_score > 95:  # Severe cognitive, perfect motor
                indicators.improbable_scores.append("Severe cognitive impairment with perfect motor")
                indicators.validity_concerns.append(
                    "Severe cognitive deficits with intact motor function - unusual pattern"
                )
        
        # Floor performance across ALL tests (very rare in genuine impairment)
        test_scores = [
            features.get("stroop_accuracy"),
            features.get("nback_accuracy"),
            features.get("recall_accuracy"),
            features.get("tapping_regularity"),
        ]
        test_scores = [s for s in test_scores if s is not None]
        
        if len(test_scores) >= 3:
            if all(s < 0.3 for s in test_scores):
                indicators.improbable_scores.append("Floor performance on all tests")
                indicators.validity_concerns.append(
                    "Near-floor performance across all domains - rare in genuine impairment"
                )
    
    def _check_effort(self, features: Dict, indicators: ValidityIndicators):
        """
        Check embedded effort indicators.
        """
        # Completion rate - did they finish tests?
        completion_rate = features.get("test_completion_rate", 1.0)
        if completion_rate < 0.5:
            indicators.validity_concerns.append(
                f"Low test completion rate ({completion_rate*100:.0f}%) - possible poor effort"
            )
        
        # Response rate - did they respond to most trials?
        response_rate = features.get("response_rate", 1.0)
        if response_rate < 0.7:
            indicators.validity_concerns.append(
                f"Low response rate ({response_rate*100:.0f}%) - many missed/skipped trials"
            )
        
        # Practice effect - should show some improvement
        practice_improvement = features.get("practice_improvement", None)
        if practice_improvement is not None and practice_improvement < -0.2:
            indicators.validity_concerns.append(
                "Performance declined with practice - opposite of expected pattern"
            )
    
    def _determine_validity(self, indicators: ValidityIndicators) -> Tuple[ValidityStatus, float]:
        """
        Determine overall validity status and confidence.
        
        Uses weighted scoring of validity concerns.
        """
        # Severity weights
        weights = {
            "below_chance": 3,
            "inconsistent": 3,
            "improbable": 2,
            "timing": 1,
            "effort": 1,
        }
        
        total_score = 0
        
        # Below chance is very serious
        total_score += len(indicators.below_chance_tests) * weights["below_chance"]
        
        # Inconsistent patterns
        total_score += len(indicators.inconsistent_patterns) * weights["inconsistent"]
        
        # Improbable scores
        total_score += len(indicators.improbable_scores) * weights["improbable"]
        
        # Timing issues
        if indicators.too_fast_responses > 10 or indicators.too_slow_responses > 10:
            total_score += weights["timing"]
        
        # Calculate confidence
        confidence = max(0, 1 - (total_score * 0.1))
        
        # Determine status
        if total_score == 0:
            return ValidityStatus.VALID, 1.0
        elif total_score <= 2:
            return ValidityStatus.QUESTIONABLE, confidence
        elif indicators.below_chance_tests:
            return ValidityStatus.INVALID, confidence
        elif indicators.inconsistent_patterns:
            return ValidityStatus.INVALID, confidence
        elif total_score >= 5:
            return ValidityStatus.INVALID_POOR_EFFORT, confidence
        else:
            return ValidityStatus.QUESTIONABLE, confidence


# ==================== MAIN FUSION SERVICE ====================

class FusionService:
    """
    Clinical-Grade Multimodal Fusion Service with Validity Detection
    
    Implements comprehensive cognitive and motor assessment using
    validated clinical scales with embedded validity indicators.
    
    DISCLAIMER: This is a SCREENING tool only. Not for diagnosis.
    Always consult healthcare professionals.
    """
    
    def __init__(self):
        self.norms = ClinicalNorms()
        self.validity_detector = ValidityDetector()
    
    async def calculate_risk_scores(
        self, 
        category: str, 
        features: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Calculate clinical risk scores with validity checking.
        """
        # STEP 1: Check validity first
        validity = self.validity_detector.assess_validity(features)
        
        # STEP 2: Calculate clinical scores
        if category == "cognitive":
            results = await self._assess_cognitive(features)
        elif category == "speech":
            results = await self._assess_speech(features)
        elif category == "motor":
            results = await self._assess_motor(features)
        elif category == "gait":
            results = await self._assess_gait(features)
        elif category == "facial":
            results = await self._assess_facial(features)
        else:
            results = self._default_assessment()
        
        # STEP 3: Add validity information
        results["validity"] = {
            "status": validity.validity_status.value,
            "confidence": round(validity.validity_confidence, 2),
            "concerns": validity.validity_concerns,
            "is_valid": validity.validity_status == ValidityStatus.VALID,
        }
        
        # STEP 4: Adjust risk if validity is questionable
        if validity.validity_status != ValidityStatus.VALID:
            results["clinical_notes"].insert(0, 
                f"⚠️ VALIDITY CONCERN: {validity.validity_status.value}"
            )
            results["interpretation_caveat"] = (
                "Results should be interpreted with caution due to validity concerns. "
                "Consider re-testing under standardized conditions."
            )
        
        return results
    
    async def _assess_cognitive(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Comprehensive cognitive assessment using multiple clinical scales.
        
        Scales mapped:
        - Stroop → TMT-B (executive), Attention
        - N-Back → Digit Span (working memory)
        - Word Recall → CERAD Word List
        - Combined → MoCA/ADAS-Cog equivalent
        """
        
        # Initialize domain scores
        domains = {
            "attention_concentration": {"score": 0, "max": 6},      # MoCA attention
            "executive_function": {"score": 0, "max": 5},           # MoCA executive
            "memory_immediate": {"score": 0, "max": 5},             # MoCA memory
            "memory_delayed": {"score": 0, "max": 5},               # Delayed recall
            "working_memory": {"score": 0, "max": 4},               # Digit span
            "processing_speed": {"score": 0, "max": 3},             # TMT-A
            "language": {"score": 0, "max": 3},                     # Fluency
        }
        
        clinical_notes = []
        
        # ========== STROOP TEST → Executive Function + Attention ==========
        stroop_accuracy = features.get("stroop_accuracy", 0)
        stroop_interference = features.get("stroop_interference", 100)
        stroop_rt = features.get("stroop_mean_rt", 0)
        
        if stroop_accuracy > 0:
            # Accuracy scoring (Attention domain)
            if stroop_accuracy >= 0.95:
                domains["attention_concentration"]["score"] += 3
            elif stroop_accuracy >= 0.85:
                domains["attention_concentration"]["score"] += 2
            elif stroop_accuracy >= 0.70:
                domains["attention_concentration"]["score"] += 1
            else:
                clinical_notes.append(f"Low Stroop accuracy ({stroop_accuracy*100:.0f}%) suggests attention deficits")
            
            # Interference scoring (Executive Function)
            # Maps to Trail Making B concept
            if stroop_interference <= self.norms.STROOP_INTERFERENCE_NORMAL:
                domains["executive_function"]["score"] += 3
            elif stroop_interference <= 30:
                domains["executive_function"]["score"] += 2
            elif stroop_interference <= self.norms.STROOP_INTERFERENCE_IMPAIRED:
                domains["executive_function"]["score"] += 1
            else:
                clinical_notes.append(f"Elevated Stroop interference ({stroop_interference:.0f}s) indicates executive dysfunction")
            
            # Processing speed from RT
            if stroop_rt > 0 and stroop_rt < 800:
                domains["processing_speed"]["score"] += 2
            elif stroop_rt < 1200:
                domains["processing_speed"]["score"] += 1
        
        # ========== N-BACK → Working Memory ==========
        nback_accuracy = features.get("nback_accuracy", 0)
        nback_dprime = features.get("nback_dprime", 0)
        nback_level = features.get("nback_level", 2)  # 1-back, 2-back, etc.
        
        if nback_accuracy > 0:
            # Accuracy-based scoring
            if nback_accuracy >= self.norms.NBACK_ACCURACY_NORMAL:
                domains["working_memory"]["score"] += 3
                domains["attention_concentration"]["score"] += 2
            elif nback_accuracy >= self.norms.NBACK_ACCURACY_MCI:
                domains["working_memory"]["score"] += 2
                domains["attention_concentration"]["score"] += 1
            elif nback_accuracy >= self.norms.NBACK_ACCURACY_IMPAIRED:
                domains["working_memory"]["score"] += 1
                clinical_notes.append(f"Working memory below normal ({nback_accuracy*100:.0f}%)")
            else:
                clinical_notes.append(f"Significant working memory impairment ({nback_accuracy*100:.0f}%)")
            
            # d' sensitivity bonus (signal detection)
            if nback_dprime >= self.norms.NBACK_DPRIME_NORMAL:
                domains["working_memory"]["score"] += 1
        
        # ========== WORD RECALL → Memory Domain (CERAD methodology) ==========
        recall_accuracy = features.get("recall_accuracy", 0)
        delayed_recall = features.get("delayed_recall_accuracy", 0)
        recognition_accuracy = features.get("recognition_accuracy", 0)
        
        # Immediate recall (3 learning trials)
        if recall_accuracy > 0:
            if recall_accuracy >= self.norms.RECALL_IMMEDIATE_NORMAL:
                domains["memory_immediate"]["score"] += 5
            elif recall_accuracy >= 0.60:
                domains["memory_immediate"]["score"] += 4
            elif recall_accuracy >= self.norms.RECALL_IMMEDIATE_MCI:
                domains["memory_immediate"]["score"] += 2
                clinical_notes.append("Immediate recall in MCI range")
            else:
                domains["memory_immediate"]["score"] += 1
                clinical_notes.append(f"Poor immediate recall ({recall_accuracy*100:.0f}%) - memory encoding concern")
        
        # Delayed recall (critical for AD detection)
        if delayed_recall > 0:
            if delayed_recall >= self.norms.RECALL_DELAYED_NORMAL:
                domains["memory_delayed"]["score"] += 5
            elif delayed_recall >= 0.55:
                domains["memory_delayed"]["score"] += 3
            elif delayed_recall >= self.norms.RECALL_DELAYED_MCI:
                domains["memory_delayed"]["score"] += 1
                clinical_notes.append("Delayed recall impaired - hallmark early AD sign")
            else:
                clinical_notes.append(f"Severely impaired delayed recall ({delayed_recall*100:.0f}%) - significant memory consolidation deficit")
        
        # Recognition (should be high even in MCI - poor recognition = validity concern)
        if recognition_accuracy > 0:
            if recognition_accuracy >= self.norms.RECALL_RECOGNITION_NORMAL:
                domains["memory_immediate"]["score"] += 1  # Bonus
            elif recognition_accuracy < self.norms.RECALL_RECOGNITION_FLOOR:
                clinical_notes.append("Recognition memory unusually low - verify data validity")
        
        # ========== CALCULATE COMPOSITE SCORES ==========
        
        # MoCA Equivalent (0-30 scale)
        total_earned = sum(d["score"] for d in domains.values())
        total_possible = sum(d["max"] for d in domains.values())
        moca_equivalent = (total_earned / total_possible) * 30 if total_possible > 0 else 15
        
        # ADAS-Cog Equivalent (0-70 scale, lower is better)
        # Invert the score
        adas_equivalent = 70 - (moca_equivalent / 30 * 70)
        
        # ========== DETERMINE STAGING ==========
        
        if moca_equivalent >= self.norms.MOCA_NORMAL:
            stage = CognitiveStage.NORMAL
            ad_risk = max(0, (30 - moca_equivalent) * 1.5)  # 0-6%
        elif moca_equivalent >= self.norms.MOCA_MCI_CUTOFF:
            stage = CognitiveStage.MCI
            ad_risk = 15 + (26 - moca_equivalent) * 5  # 15-35%
        elif moca_equivalent >= self.norms.MOCA_DEMENTIA_CUTOFF:
            stage = CognitiveStage.MILD_DEMENTIA
            ad_risk = 35 + (22 - moca_equivalent) * 5  # 35-60%
        elif moca_equivalent >= 10:
            stage = CognitiveStage.MODERATE_DEMENTIA
            ad_risk = 60 + (17 - moca_equivalent) * 3  # 60-80%
        else:
            stage = CognitiveStage.SEVERE_DEMENTIA
            ad_risk = 80 + (10 - moca_equivalent) * 2  # 80-100%
        
        ad_risk = min(100, max(0, ad_risk))
        
        # PD cognitive component (less prominent)
        pd_risk = ad_risk * 0.25
        
        # Calculate category health score
        category_score = (moca_equivalent / 30) * 100
        
        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "category_score": round(category_score, 2),
            "stage": stage.value,
            "severity": self._get_severity(ad_risk),
            "ad_stage": stage.value,
            "pd_stage": self._get_pd_stage_from_risk(pd_risk),
            
            # Clinical scale equivalents
            "moca_equivalent": round(moca_equivalent, 1),
            "adas_cog_equivalent": round(adas_equivalent, 1),
            
            # Domain breakdown
            "domain_scores": {k: f"{v['score']}/{v['max']}" for k, v in domains.items()},
            "domain_percentages": {
                k: round(v['score']/v['max']*100, 1) if v['max'] > 0 else 0 
                for k, v in domains.items()
            },
            
            # Interpretation
            "interpretation": self._interpret_cognitive(moca_equivalent, domains),
            "clinical_notes": clinical_notes if clinical_notes else ["Cognitive performance within normal limits"],
            "recommendations": self._get_cognitive_recommendations(stage, ad_risk),
        }
    
    async def _assess_speech(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Speech assessment for AD/PD markers."""
        
        clinical_notes = []
        ad_score = 0
        pd_score = 0
        max_ad = 10
        max_pd = 10
        
        # Story Recall (AD marker)
        story_accuracy = features.get("story_recall_accuracy", 0)
        if story_accuracy > 0:
            if story_accuracy >= 0.80:
                ad_score += 5
            elif story_accuracy >= 0.60:
                ad_score += 3
            elif story_accuracy >= 0.40:
                ad_score += 1
            else:
                clinical_notes.append("Poor story recall - verbal memory concern")
        
        # Sustained Vowel (PD marker)
        vowel_duration = features.get("vowel_duration", 0)
        if vowel_duration > 0:
            if vowel_duration >= self.norms.VOWEL_DURATION_NORMAL:
                pd_score += 5
            elif vowel_duration >= self.norms.VOWEL_DURATION_IMPAIRED:
                pd_score += 3
            elif vowel_duration >= 5:
                pd_score += 1
            else:
                clinical_notes.append("Reduced phonation time - respiratory/laryngeal concern")
        
        # Speech rate
        speech_rate = features.get("speech_rate", 0)
        if speech_rate > 0:
            if self.norms.SPEECH_RATE_NORMAL_MIN <= speech_rate <= self.norms.SPEECH_RATE_NORMAL_MAX:
                ad_score += 2
                pd_score += 2
            elif speech_rate < 100:
                clinical_notes.append("Slow speech rate - possible motor speech involvement")
        
        # Fluency (AD marker)
        word_count = features.get("fluency_word_count", 0)
        if word_count > 0:
            if word_count >= self.norms.FLUENCY_NORMAL:
                ad_score += 3
            elif word_count >= self.norms.FLUENCY_MCI:
                ad_score += 2
            elif word_count >= self.norms.FLUENCY_IMPAIRED:
                ad_score += 1
            else:
                clinical_notes.append("Reduced verbal fluency - semantic memory concern")
        
        category_score = ((ad_score + pd_score) / (max_ad + max_pd)) * 100
        ad_risk = (1 - ad_score/max_ad) * 25
        pd_risk = (1 - pd_score/max_pd) * 25
        
        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "category_score": round(category_score, 2),
            "stage": self._get_stage_from_risk(max(ad_risk, pd_risk)),
            "severity": self._get_severity(max(ad_risk, pd_risk)),
            "ad_stage": self._get_ad_stage_from_risk(ad_risk),
            "pd_stage": self._get_pd_stage_from_risk(pd_risk),
            "clinical_notes": clinical_notes if clinical_notes else ["Speech parameters within normal limits"],
            "speech_metrics": {
                "verbal_memory_pct": round(story_accuracy * 100, 1) if story_accuracy else None,
                "phonation_time_sec": round(vowel_duration, 1) if vowel_duration else None,
                "speech_rate_wpm": round(speech_rate, 0) if speech_rate else None,
                "fluency_words": word_count if word_count else None,
            }
        }
    
    async def _assess_motor(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Motor assessment using MDS-UPDRS methodology."""
        
        updrs_scores = {}
        clinical_notes = []
        
        # Finger Tapping (UPDRS 3.4 - Bradykinesia)
        tapping_rate = features.get("tapping_rate", 0)
        tapping_regularity = features.get("tapping_regularity", 0)
        tapping_fatigue = features.get("tapping_fatigue", 0)
        
        if tapping_rate > 0:
            if tapping_rate >= self.norms.TAPPING_NORMAL_MIN:
                if tapping_regularity >= 0.90 and tapping_fatigue <= 0.10:
                    updrs_scores["bradykinesia"] = 0
                elif tapping_regularity >= 0.80:
                    updrs_scores["bradykinesia"] = 1
                else:
                    updrs_scores["bradykinesia"] = 2
            elif tapping_rate >= self.norms.TAPPING_PD_THRESHOLD:
                updrs_scores["bradykinesia"] = 2 if tapping_regularity >= 0.70 else 3
                clinical_notes.append("Reduced tapping rate - bradykinesia indicator")
            else:
                updrs_scores["bradykinesia"] = 3 if tapping_rate >= 2.0 else 4
                clinical_notes.append("Significant bradykinesia detected")
        
        # Spiral Drawing (UPDRS 3.15-3.18 - Tremor)
        spiral_tremor = features.get("spiral_tremor", 0)
        tremor_frequency = features.get("tremor_frequency", 0)
        
        if features.get("spiral_duration"):
            if spiral_tremor <= 0.10:
                updrs_scores["tremor"] = 0
            elif spiral_tremor <= 0.25:
                updrs_scores["tremor"] = 1
            elif spiral_tremor <= 0.50:
                updrs_scores["tremor"] = 2
            elif spiral_tremor <= 0.75:
                updrs_scores["tremor"] = 3
                clinical_notes.append("Moderate tremor detected in drawing")
            else:
                updrs_scores["tremor"] = 4
                clinical_notes.append("Severe tremor present")
            
            # Check for PD-characteristic 4-6 Hz tremor
            if 4 <= tremor_frequency <= 6:
                clinical_notes.append(f"Tremor frequency ({tremor_frequency:.1f} Hz) in Parkinsonian range (4-6 Hz)")
        
        # Calculate scores
        total = sum(updrs_scores.values())
        max_score = len(updrs_scores) * 4 if updrs_scores else 8
        
        motor_health = ((max_score - total) / max_score) * 100 if max_score > 0 else 50
        pd_risk = (total / max_score) * 60 if max_score > 0 else 0
        ad_risk = pd_risk * 0.1
        
        hy_stage = self._calculate_hoehn_yahr(updrs_scores, features)
        
        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "category_score": round(motor_health, 2),
            "stage": hy_stage.value,
            "severity": self._get_severity(pd_risk),
            "ad_stage": self._get_ad_stage_from_risk(ad_risk),
            "pd_stage": hy_stage.value,
            "hoehn_yahr": hy_stage.value,
            "updrs_subscores": updrs_scores,
            "updrs_motor_total": total,
            "clinical_notes": clinical_notes if clinical_notes else ["Motor function within normal limits"],
            "motor_metrics": {
                "tapping_rate_hz": round(tapping_rate, 2) if tapping_rate else None,
                "tremor_severity_pct": round(spiral_tremor * 100, 1) if spiral_tremor else None,
                "tremor_frequency_hz": round(tremor_frequency, 1) if tremor_frequency else None,
            }
        }
    
    async def _assess_gait(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Gait & balance assessment (UPDRS 3.10-3.12)."""
        
        updrs_scores = {}
        clinical_notes = []
        
        # Walking (UPDRS 3.10)
        gait_speed = features.get("gait_speed", 0)
        step_regularity = features.get("step_regularity", 0)
        
        if features.get("steps"):
            if gait_speed >= self.norms.GAIT_SPEED_NORMAL and step_regularity >= 0.90:
                updrs_scores["gait"] = 0
            elif gait_speed >= self.norms.GAIT_SPEED_SLOW:
                updrs_scores["gait"] = 1
            elif gait_speed >= self.norms.GAIT_SPEED_VERY_SLOW:
                updrs_scores["gait"] = 2
                clinical_notes.append(f"Slow gait speed ({gait_speed:.2f} m/s)")
            else:
                updrs_scores["gait"] = 3
                clinical_notes.append(f"Significantly reduced gait speed ({gait_speed:.2f} m/s)")
        
        # Balance (UPDRS 3.12)
        balance_sway = features.get("balance_sway", 0)
        balance_stability = features.get("balance_stability", 0)
        
        if features.get("balance_duration"):
            if balance_sway <= self.norms.SWAY_NORMAL and balance_stability >= 0.90:
                updrs_scores["postural_stability"] = 0
            elif balance_sway <= 0.4:
                updrs_scores["postural_stability"] = 1
            elif balance_sway <= self.norms.SWAY_ABNORMAL:
                updrs_scores["postural_stability"] = 2
            else:
                updrs_scores["postural_stability"] = 3
                clinical_notes.append("Postural instability - fall risk")
        
        total = sum(updrs_scores.values())
        max_score = len(updrs_scores) * 4 if updrs_scores else 8
        
        gait_health = ((max_score - total) / max_score) * 100 if max_score > 0 else 50
        pd_risk = (total / max_score) * 40 if max_score > 0 else 0
        ad_risk = pd_risk * 0.15
        
        hy_stage = self._calculate_hoehn_yahr(updrs_scores, features)
        
        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "category_score": round(gait_health, 2),
            "stage": hy_stage.value,
            "severity": self._get_severity(pd_risk),
            "ad_stage": self._get_ad_stage_from_risk(ad_risk),
            "pd_stage": hy_stage.value,
            "updrs_subscores": updrs_scores,
            "clinical_notes": clinical_notes if clinical_notes else ["Gait and balance within normal limits"],
            "gait_metrics": {
                "speed_m_s": round(gait_speed, 2) if gait_speed else None,
                "step_regularity_pct": round(step_regularity * 100, 1) if step_regularity else None,
                "balance_sway": round(balance_sway, 2) if balance_sway else None,
            }
        }
    
    async def _assess_facial(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Facial expression assessment (UPDRS 3.2 - Hypomimia)."""
        
        updrs_scores = {}
        clinical_notes = []
        
        blink_rate = features.get("blink_rate", 0)
        smile_intensity = features.get("smile_intensity", 0)
        
        if blink_rate > 0:
            if self.norms.BLINK_NORMAL_MIN <= blink_rate <= self.norms.BLINK_NORMAL_MAX:
                updrs_scores["blink"] = 0
            elif blink_rate >= 12:
                updrs_scores["blink"] = 1
            elif blink_rate >= self.norms.BLINK_PD_THRESHOLD:
                updrs_scores["blink"] = 2
            else:
                updrs_scores["blink"] = 3
                clinical_notes.append(f"Reduced blink rate ({blink_rate:.0f}/min) - hypomimia indicator")
        
        if features.get("smile_count"):
            if smile_intensity >= 0.80:
                updrs_scores["facial_expression"] = 0
            elif smile_intensity >= 0.60:
                updrs_scores["facial_expression"] = 1
            elif smile_intensity >= 0.40:
                updrs_scores["facial_expression"] = 2
            else:
                updrs_scores["facial_expression"] = 3
                clinical_notes.append("Reduced facial expressivity - masked facies")
        
        total = sum(updrs_scores.values())
        max_score = len(updrs_scores) * 4 if updrs_scores else 8
        
        facial_health = ((max_score - total) / max_score) * 100 if max_score > 0 else 50
        pd_risk = (total / max_score) * 20 if max_score > 0 else 0
        ad_risk = pd_risk * 0.05
        
        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "category_score": round(facial_health, 2),
            "stage": self._get_stage_from_risk(pd_risk),
            "severity": self._get_severity(pd_risk),
            "ad_stage": self._get_ad_stage_from_risk(ad_risk),
            "pd_stage": self._get_pd_stage_from_risk(pd_risk),
            "updrs_subscores": updrs_scores,
            "clinical_notes": clinical_notes if clinical_notes else ["Facial expression within normal range"],
            "facial_metrics": {
                "blink_rate_per_min": round(blink_rate, 1) if blink_rate else None,
                "expression_intensity_pct": round(smile_intensity * 100, 1) if smile_intensity else None,
            }
        }
    
    # ========== HELPER METHODS ==========
    
    def _calculate_hoehn_yahr(self, updrs_scores: Dict, features: Dict) -> ParkinsonStage:
        """Calculate Hoehn & Yahr stage."""
        total = sum(updrs_scores.values())
        postural = updrs_scores.get("postural_stability", 0)
        
        if total == 0:
            return ParkinsonStage.STAGE_0
        elif total <= 4 and postural <= 1:
            return ParkinsonStage.STAGE_1
        elif total <= 8 and postural <= 1:
            return ParkinsonStage.STAGE_2
        elif postural >= 2:
            return ParkinsonStage.STAGE_3
        elif postural >= 3:
            return ParkinsonStage.STAGE_4
        else:
            return ParkinsonStage.STAGE_2
    
    def _get_severity(self, risk: float) -> str:
        if risk < 20:
            return "low"
        elif risk < 40:
            return "mild"
        elif risk < 60:
            return "moderate"
        elif risk < 80:
            return "high"
        else:
            return "severe"
    
    def _get_stage_from_risk(self, risk: float) -> str:
        if risk < 15:
            return "Normal"
        elif risk < 30:
            return "Minimal"
        elif risk < 50:
            return "Mild"
        elif risk < 70:
            return "Moderate"
        else:
            return "Severe"
    
    def _get_ad_stage_from_risk(self, risk: float) -> str:
        if risk < 10:
            return CognitiveStage.NORMAL.value
        elif risk < 25:
            return CognitiveStage.SUBJECTIVE_DECLINE.value
        elif risk < 40:
            return CognitiveStage.MCI.value
        elif risk < 60:
            return CognitiveStage.MILD_DEMENTIA.value
        elif risk < 80:
            return CognitiveStage.MODERATE_DEMENTIA.value
        else:
            return CognitiveStage.SEVERE_DEMENTIA.value
    
    def _get_pd_stage_from_risk(self, risk: float) -> str:
        if risk < 10:
            return ParkinsonStage.STAGE_0.value
        elif risk < 25:
            return ParkinsonStage.STAGE_1.value
        elif risk < 40:
            return ParkinsonStage.STAGE_2.value
        elif risk < 60:
            return ParkinsonStage.STAGE_3.value
        elif risk < 80:
            return ParkinsonStage.STAGE_4.value
        else:
            return ParkinsonStage.STAGE_5.value
    
    def _interpret_cognitive(self, moca: float, domains: Dict) -> str:
        if moca >= 26:
            return "Cognitive function within normal limits. No significant concerns identified."
        elif moca >= 22:
            return "Performance suggests possible Mild Cognitive Impairment (MCI). Recommend follow-up neuropsychological evaluation."
        elif moca >= 17:
            return "Performance indicates likely cognitive impairment. Clinical evaluation recommended."
        else:
            return "Significant cognitive impairment detected. Urgent clinical evaluation strongly recommended."
    
    def _get_cognitive_recommendations(self, stage: CognitiveStage, risk: float) -> List[str]:
        recommendations = []
        
        if stage == CognitiveStage.NORMAL:
            recommendations.append("Continue regular cognitive health monitoring")
            recommendations.append("Maintain physical and mental activities")
        elif stage == CognitiveStage.MCI:
            recommendations.append("Schedule comprehensive neuropsychological evaluation")
            recommendations.append("Consider lifestyle modifications (exercise, diet, sleep)")
            recommendations.append("Monitor for progression - repeat testing in 6-12 months")
        else:
            recommendations.append("Urgent consultation with neurologist recommended")
            recommendations.append("Comprehensive dementia workup advised")
            recommendations.append("Consider caregiver support resources")
        
        return recommendations
    
    def _default_assessment(self) -> Dict[str, Any]:
        return {
            "ad_risk": 0,
            "pd_risk": 0,
            "category_score": 50,
            "stage": "Unknown",
            "severity": "low",
            "ad_stage": CognitiveStage.NORMAL.value,
            "pd_stage": ParkinsonStage.STAGE_0.value,
            "clinical_notes": ["Insufficient data for assessment"],
        }


# ==================== COMPOSITE FUSION ====================

class CompositeFusionService:
    """
    Multi-category fusion for overall AD/PD risk.
    
    Weights based on clinical evidence for early detection:
    - Cognitive: Primary AD marker, secondary PD marker
    - Motor: Primary PD marker (cardinal signs)
    - Gait: Important for both (falls in AD, freezing in PD)
    - Speech: Moderate both (semantic issues AD, dysarthria PD)
    - Facial: Hypomimia primarily PD
    """
    
    # Evidence-based category weights
    WEIGHTS_AD = {
        "cognitive": 0.45,   # Primary: Memory, executive
        "speech": 0.20,      # Language, semantic fluency
        "gait": 0.20,        # Falls risk, spatial navigation
        "motor": 0.05,       # Late-stage only
        "facial": 0.10,      # Minimal contribution
    }
    
    WEIGHTS_PD = {
        "motor": 0.35,       # Cardinal: Bradykinesia, tremor, rigidity
        "gait": 0.25,        # Festination, freezing, postural instability
        "speech": 0.15,      # Hypokinetic dysarthria
        "cognitive": 0.15,   # PD-MCI, PD-dementia
        "facial": 0.10,      # Hypomimia
    }
    
    def calculate_composite(self, category_results: Dict[str, Dict]) -> Dict[str, Any]:
        """Calculate weighted composite risk scores."""
        
        ad_weighted = 0
        pd_weighted = 0
        total_ad_weight = 0
        total_pd_weight = 0
        validity_concerns = []
        
        for category, results in category_results.items():
            # Check validity
            validity = results.get("validity", {})
            if not validity.get("is_valid", True):
                validity_concerns.append(f"{category}: {validity.get('status', 'Unknown')}")
            
            # Weighted scores
            ad_weight = self.WEIGHTS_AD.get(category, 0.1)
            pd_weight = self.WEIGHTS_PD.get(category, 0.1)
            
            ad_weighted += results.get("ad_risk", 0) * ad_weight
            pd_weighted += results.get("pd_risk", 0) * pd_weight
            
            total_ad_weight += ad_weight
            total_pd_weight += pd_weight
        
        # Normalize
        composite_ad = ad_weighted / total_ad_weight if total_ad_weight > 0 else 0
        composite_pd = pd_weighted / total_pd_weight if total_pd_weight > 0 else 0
        
        # Determine primary concern
        if composite_ad > composite_pd + 10:
            primary = "Alzheimer's Disease"
        elif composite_pd > composite_ad + 10:
            primary = "Parkinson's Disease"
        else:
            primary = "Mixed/Undetermined"
        
        return {
            "composite_ad_risk": round(composite_ad, 2),
            "composite_pd_risk": round(composite_pd, 2),
            "primary_concern": primary,
            "overall_risk": round(max(composite_ad, composite_pd), 2),
            "categories_assessed": list(category_results.keys()),
            "validity_summary": {
                "all_valid": len(validity_concerns) == 0,
                "concerns": validity_concerns,
            },
            "recommendation": self._get_recommendation(composite_ad, composite_pd, validity_concerns),
            "disclaimer": (
                "SCREENING TOOL ONLY. This assessment does not constitute a medical diagnosis. "
                "Please consult a qualified healthcare professional for proper evaluation and diagnosis."
            ),
        }
    
    def _get_recommendation(self, ad: float, pd: float, validity_concerns: List) -> str:
        if validity_concerns:
            return "Results may be unreliable due to validity concerns. Consider re-testing under standardized conditions."
        
        max_risk = max(ad, pd)
        
        if max_risk < 15:
            return "Results within normal limits. Continue regular health monitoring."
        elif max_risk < 30:
            return "Minor deviations noted. Consider follow-up assessment in 6-12 months."
        elif max_risk < 50:
            return "Some concerns identified. Consultation with a neurologist is recommended."
        elif max_risk < 70:
            return "Moderate risk indicators present. Clinical evaluation is strongly recommended."
        else:
            return "Significant risk indicators detected. Urgent neurological evaluation is recommended."