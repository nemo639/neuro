"""
Neuro Chat Service - AI Health Companion powered by Groq API

Uses the user's test results and health scores as context to provide
personalized, clinically-informed conversational responses.
"""

import logging
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any

import httpx
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete
from sqlalchemy.sql import func

from app.models.user import User
from app.models.chat_conversation import ChatConversation
from app.models.chat_message import ChatMessage
from app.models.test_result import TestResult
from app.models.test_session import TestSession
from app.core.config import settings

logger = logging.getLogger(__name__)

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.1-70b-versatile"

# System prompt that makes the LLM a neuro health companion
SYSTEM_PROMPT = """You are Neuro, an AI health companion inside the NeuroVerse app — a smartphone-based multimodal screening platform for Alzheimer's Disease (AD) and Parkinson's Disease (PD).

## YOUR CORE IDENTITY
You are warm, knowledgeable, supportive, and conversational. You feel like a trusted friend who happens to know a lot about brain health. You can also chat about everyday topics — you're not limited to only medical questions.

## WHAT YOU CAN DO

### 1. Explain Test Results & Risk Scores
- Break down AD risk scores, PD risk scores, and category scores (cognitive, speech, motor, facial) in plain language
- Explain what "low/moderate/high risk" means practically
- Compare scores across categories to give a holistic picture
- Clarify that NeuroVerse is a screening tool, NOT a diagnostic tool

### 2. Neurodegenerative Disease Knowledge
**Alzheimer's Disease (AD):**
- What it is: progressive brain disorder affecting memory, thinking, and behavior
- Early signs: forgetting recent events, difficulty planning, confusion with time/place, mood changes
- Stages: preclinical → mild cognitive impairment (MCI) → mild → moderate → severe dementia
- Risk factors: age (65+), family history, APOE-e4 gene, cardiovascular health, head injuries
- Protective factors: education, social engagement, physical activity, cognitive stimulation

**Parkinson's Disease (PD):**
- What it is: progressive nervous system disorder affecting movement
- Early signs: slight tremor, reduced facial expression (hypomimia), soft speech, small handwriting (micrographia), stiffness
- Motor symptoms: tremor, bradykinesia (slowness), rigidity, postural instability
- Non-motor symptoms: sleep issues, constipation, depression, anxiety, loss of smell
- Risk factors: age (60+), male sex, genetics, pesticide/herbicide exposure
- Protective factors: exercise (especially aerobic), caffeine consumption, Mediterranean diet

**Other Related Conditions:**
- Vascular dementia, Lewy body dementia, frontotemporal dementia
- Essential tremor vs Parkinson's tremor differences
- Mild Cognitive Impairment (MCI) — not everyone with MCI develops dementia

### 3. NeuroVerse Test Categories Explained
**Cognitive Tests:**
- Clock Drawing Test (CDT): Tests visuospatial skills, executive function, and planning. Score 1-6 (Shulman scale, 6=perfect)
- Trail Making Test (TMT): Tests visual attention, processing speed, mental flexibility. Measures time and accuracy
- Stroop Test: Tests selective attention, cognitive flexibility, processing speed
- N-Back Test: Tests working memory capacity
- Word Recall: Tests verbal memory encoding and retrieval
- Story Recall: Tests episodic memory and comprehension

**Speech & Language Tests:**
- Sustained Vowel: Analyzes voice stability, jitter, shimmer — detects vocal cord rigidity
- Picture Description: Tests fluency, vocabulary, sentence complexity, information content
- Story Recall (speech aspect): Analyzes speech rate, pauses, articulation

**Motor Tests:**
- Spiral Drawing: Detects tremor severity, smoothness, and regularity in hand movement
- Meander Drawing: Tests motor precision and ability to follow a path
- Finger Tapping: Measures tapping speed, regularity, and fatigue — detects bradykinesia
- Resting Tremor: Detects involuntary tremor using phone accelerometer

**Facial & Eye Analysis:**
- Facial expression range and spontaneity
- Smile symmetry and blink rate
- Hypomimia detection (mask-like face in PD)

**Gait & Movement:**
- Walking speed, stride length, arm swing symmetry
- Turn hesitation, freezing of gait detection

### 4. Lifestyle & Wellness Advice
**Brain-Healthy Diet:**
- MIND diet: leafy greens, berries, nuts, whole grains, fish, poultry, olive oil, beans
- Foods to limit: red meat, butter/margarine, cheese, pastries/sweets, fried food
- Hydration: 8+ glasses of water daily
- Omega-3 fatty acids: salmon, walnuts, flaxseed
- Antioxidants: blueberries, dark chocolate, green tea, turmeric

**Exercise for Brain Health:**
- Aerobic: 150 min/week moderate (brisk walking, swimming, cycling)
- Strength training: 2-3x/week — improves neuroplasticity
- Balance & coordination: yoga, tai chi — reduces fall risk
- Dance: combines physical, cognitive, and social stimulation
- Walking: even 30 min/day significantly reduces dementia risk

**Cognitive Engagement:**
- Learn new skills (instrument, language, craft)
- Puzzles: crosswords, Sudoku, jigsaw puzzles
- Reading, writing, journaling
- Board games and card games
- Brain training apps (in moderation)

**Sleep Optimization:**
- 7-9 hours per night — brain clears toxic proteins (beta-amyloid) during deep sleep
- Consistent sleep/wake schedule
- Dark, cool bedroom (65-68°F / 18-20°C)
- Limit screens 1 hour before bed
- Avoid caffeine after 2 PM

**Stress Management:**
- Meditation and mindfulness (even 10 min/day)
- Deep breathing exercises (4-7-8 technique)
- Social connections — loneliness increases dementia risk by 50%
- Nature exposure — 20 min in green spaces reduces cortisol
- Journaling and gratitude practice

**Social Health:**
- Regular meaningful conversations
- Group activities, clubs, volunteering
- Maintaining friendships and family connections
- Social isolation is a major risk factor for cognitive decline

### 5. General Daily Life Questions
You can also help with:
- General health & wellness questions (nutrition, fitness, sleep, mental health)
- Explaining medical terminology in simple words
- Motivation and encouragement for healthy habits
- Answering curiosity questions about the brain, body, and science
- Daily tips: productivity, mindfulness, healthy routines
- Emotional support: anxiety about health, coping with diagnosis fears
- Caregiver support: tips for those caring for someone with AD/PD
- General knowledge: science, nature, technology, everyday questions
- Light conversation: weather, hobbies, daily life topics

## YOUR BOUNDARIES (NEVER CROSS THESE)
- NEVER diagnose — always say "NeuroVerse is a screening tool, not a diagnostic device. Please consult your doctor for medical diagnosis"
- NEVER recommend specific medications, dosages, or treatments
- NEVER replace professional medical advice — always encourage doctor visits for concerns
- NEVER fabricate test results or scores you don't have
- NEVER be alarmist — frame information positively and supportively
- NEVER provide emergency medical advice — direct to emergency services (911/local equivalent)

## YOUR TONE
- Warm, friendly, and empathetic — like a knowledgeable friend
- Use simple language, avoid medical jargon (or explain it when used)
- Be encouraging and positive, even when discussing difficult topics
- Use bullet points and short paragraphs for readability
- Reference the user's actual scores when available
- Keep responses concise (2-4 short paragraphs or bullet lists)
- Add relevant follow-up questions to keep the conversation going
"""


def _build_health_context(user: User) -> str:
    """Build a context string from the user's current health scores."""
    parts = []
    if user.ad_risk_score is not None and user.ad_risk_score > 0:
        parts.append(f"AD Risk: {user.ad_risk_score:.1f}% ({user.ad_stage or 'N/A'})")
    if user.pd_risk_score is not None and user.pd_risk_score > 0:
        parts.append(f"PD Risk: {user.pd_risk_score:.1f}% ({user.pd_stage or 'N/A'})")
    for cat in ("cognitive", "speech", "motor", "facial"):
        val = getattr(user, f"{cat}_score", None)
        if val is not None and val > 0:
            parts.append(f"{cat.title()} Health: {val:.1f}%")

    if not parts:
        return "No test results available yet."
    return "Current health snapshot: " + " | ".join(parts)


class ChatService:
    def __init__(self, db: AsyncSession):
        self.db = db

    # ── Conversation Management ──────────────────────────────────

    async def list_conversations(self, user_id: int) -> List[Dict[str, Any]]:
        """List all conversations for a user, most recent first."""
        q = (
            select(ChatConversation)
            .where(ChatConversation.user_id == user_id)
            .order_by(ChatConversation.updated_at.desc())
        )
        convs = (await self.db.execute(q)).scalars().all()
        return [
            {
                "id": c.id,
                "title": c.title,
                "created_at": c.created_at.isoformat() if c.created_at else None,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            }
            for c in convs
        ]

    async def create_conversation(self, user_id: int, title: str = "New Chat") -> Dict[str, Any]:
        """Create a new conversation."""
        conv = ChatConversation(
            id=str(uuid.uuid4()),
            user_id=user_id,
            title=title,
        )
        self.db.add(conv)
        await self.db.commit()
        await self.db.refresh(conv)
        return {
            "id": conv.id,
            "title": conv.title,
            "created_at": conv.created_at.isoformat() if conv.created_at else None,
        }

    async def rename_conversation(self, user_id: int, conversation_id: str, title: str) -> bool:
        """Rename a conversation."""
        q = select(ChatConversation).where(
            and_(ChatConversation.id == conversation_id, ChatConversation.user_id == user_id)
        )
        conv = (await self.db.execute(q)).scalar_one_or_none()
        if not conv:
            return False
        conv.title = title
        await self.db.commit()
        return True

    async def delete_conversation(self, user_id: int, conversation_id: str):
        """Delete a conversation and all its messages."""
        # Messages cascade-deleted via relationship
        stmt = delete(ChatConversation).where(
            and_(ChatConversation.id == conversation_id, ChatConversation.user_id == user_id)
        )
        await self.db.execute(stmt)
        await self.db.commit()

    # ── Messages ─────────────────────────────────────────────────

    async def get_history(self, user_id: int, conversation_id: str, limit: int = 50) -> Dict[str, Any]:
        """Get messages for a specific conversation."""
        # Verify conversation belongs to user
        conv_q = select(ChatConversation).where(
            and_(ChatConversation.id == conversation_id, ChatConversation.user_id == user_id)
        )
        conv = (await self.db.execute(conv_q)).scalar_one_or_none()
        if not conv:
            return {"conversation_id": conversation_id, "title": "Chat", "messages": []}

        msgs_q = (
            select(ChatMessage)
            .where(
                and_(
                    ChatMessage.user_id == user_id,
                    ChatMessage.conversation_id == conversation_id,
                )
            )
            .order_by(ChatMessage.created_at.asc())
            .limit(limit)
        )
        msgs = (await self.db.execute(msgs_q)).scalars().all()

        return {
            "conversation_id": conv.id,
            "title": conv.title,
            "messages": [
                {
                    "role": m.role,
                    "content": m.content,
                    "created_at": m.created_at.isoformat() if m.created_at else None,
                }
                for m in msgs
            ],
        }

    async def send_message(
        self, user_id: int, message: str, conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Send a message to Neuro and get a response."""
        user = (await self.db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
        if not user:
            return {"error": "User not found"}

        # Create conversation if needed
        if conversation_id:
            conv_q = select(ChatConversation).where(
                and_(ChatConversation.id == conversation_id, ChatConversation.user_id == user_id)
            )
            conv = (await self.db.execute(conv_q)).scalar_one_or_none()
            if not conv:
                return {"error": "Conversation not found"}
            conv_id = conversation_id
        else:
            # Auto-create new conversation with first message as title
            title = message[:50] + ("..." if len(message) > 50 else "")
            conv = ChatConversation(
                id=str(uuid.uuid4()),
                user_id=user_id,
                title=title,
            )
            self.db.add(conv)
            conv_id = conv.id

        # Save user message
        user_msg = ChatMessage(
            user_id=user_id,
            conversation_id=conv_id,
            role="user",
            content=message,
        )
        self.db.add(user_msg)

        # Build conversation history for context (last 10 messages)
        history_msgs = []
        if conversation_id:
            hist_q = (
                select(ChatMessage)
                .where(
                    and_(
                        ChatMessage.user_id == user_id,
                        ChatMessage.conversation_id == conv_id,
                    )
                )
                .order_by(ChatMessage.created_at.desc())
                .limit(10)
            )
            hist = list((await self.db.execute(hist_q)).scalars().all())
            hist.reverse()
            history_msgs = [{"role": m.role, "content": m.content} for m in hist]

        # Build health context & call Groq
        health_ctx = _build_health_context(user)
        groq_messages = [
            {"role": "system", "content": SYSTEM_PROMPT + f"\n\nUser's {health_ctx}"},
        ]
        groq_messages.extend(history_msgs)
        groq_messages.append({"role": "user", "content": message})

        reply = await self._call_groq(groq_messages)

        # Save assistant reply
        assistant_msg = ChatMessage(
            user_id=user_id,
            conversation_id=conv_id,
            role="assistant",
            content=reply,
        )
        self.db.add(assistant_msg)

        # Update conversation timestamp
        conv.updated_at = func.now()

        await self.db.commit()

        return {
            "conversation_id": conv_id,
            "title": conv.title,
            "reply": reply,
        }

    async def clear_all_conversations(self, user_id: int):
        """Delete all conversations and messages for a user."""
        await self.db.execute(
            delete(ChatConversation).where(ChatConversation.user_id == user_id)
        )
        await self.db.commit()

    async def _call_groq(self, messages: List[Dict]) -> str:
        """Call Groq API for chat completion."""
        api_key = getattr(settings, "GROQ_API_KEY", None)
        if not api_key:
            return self._fallback_response(messages[-1]["content"])

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    GROQ_API_URL,
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": GROQ_MODEL,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 1024,
                        "top_p": 0.9,
                    },
                )

            if response.status_code == 200:
                data = response.json()
                return data["choices"][0]["message"]["content"]
            else:
                logger.warning("Groq API error %d: %s", response.status_code, response.text)
                return self._fallback_response(messages[-1]["content"])

        except Exception as e:
            logger.error("Groq API call failed: %s", e)
            return self._fallback_response(messages[-1]["content"])

    def _fallback_response(self, user_message: str) -> str:
        """Provide a helpful response when Groq API is unavailable."""
        msg_lower = user_message.lower()

        if any(w in msg_lower for w in ["result", "score", "risk", "test"]):
            return (
                "I'd love to help you understand your results! Your test scores are "
                "available in the XAI section where each metric is explained in detail. "
                "For a full interpretation, I recommend discussing your results with your "
                "healthcare provider. Is there a specific score you'd like to know more about?"
            )
        if any(w in msg_lower for w in ["alzheimer", "dementia", "memory", "cognitive"]):
            return (
                "Alzheimer's disease is a progressive neurodegenerative condition that "
                "primarily affects memory and cognitive function. Early detection through "
                "screening tools like NeuroVerse can help identify subtle changes before "
                "they become clinically apparent. Regular cognitive engagement, physical "
                "exercise, quality sleep, and a Mediterranean diet have all shown promise "
                "in supporting brain health. Would you like specific tips?"
            )
        if any(w in msg_lower for w in ["parkinson", "tremor", "motor", "movement"]):
            return (
                "Parkinson's disease affects movement and motor control, often starting "
                "with subtle signs like reduced facial expression or slight tremors. "
                "NeuroVerse screens for these early indicators through motor, facial, and "
                "speech tests. Regular exercise — especially activities like walking, "
                "swimming, and tai chi — has been shown to benefit motor function. "
                "Would you like to know more about any specific aspect?"
            )
        if any(w in msg_lower for w in ["exercise", "health", "tip", "improve", "lifestyle"]):
            return (
                "Great question! Here are evidence-based tips for brain health:\n\n"
                "• Physical exercise — 150 min/week of moderate activity\n"
                "• Cognitive engagement — puzzles, reading, learning new skills\n"
                "• Social interaction — regular meaningful conversations\n"
                "• Quality sleep — 7-9 hours with consistent schedule\n"
                "• MIND diet — leafy greens, berries, nuts, fish, olive oil\n"
                "• Stress management — meditation, deep breathing\n\n"
                "Which area would you like to explore further?"
            )
        if any(w in msg_lower for w in ["diet", "food", "eat", "nutrition"]):
            return (
                "The MIND diet is specifically designed for brain health! Here's what to focus on:\n\n"
                "• Leafy greens — at least 6 servings/week (spinach, kale, salad)\n"
                "• Berries — at least 2 servings/week (blueberries are top-rated)\n"
                "• Nuts — 5+ servings/week (walnuts are especially good)\n"
                "• Fish — at least 1 serving/week (salmon, sardines for omega-3s)\n"
                "• Whole grains — 3+ servings/day\n"
                "• Olive oil — use as primary cooking oil\n\n"
                "Limit red meat, butter, cheese, fried foods, and pastries. "
                "Would you like to know more about specific nutrients for brain health?"
            )
        if any(w in msg_lower for w in ["sleep", "insomnia", "tired", "rest"]):
            return (
                "Sleep is crucial for brain health! During deep sleep, your brain clears "
                "toxic proteins like beta-amyloid that are linked to Alzheimer's.\n\n"
                "Tips for better sleep:\n"
                "• Aim for 7-9 hours per night\n"
                "• Keep a consistent sleep/wake schedule\n"
                "• Make your room dark and cool (18-20°C)\n"
                "• Limit screens 1 hour before bed\n"
                "• Avoid caffeine after 2 PM\n"
                "• Try relaxation techniques before bed\n\n"
                "Poor sleep quality over time increases dementia risk. Would you like tips on relaxation techniques?"
            )
        if any(w in msg_lower for w in ["stress", "anxiety", "worried", "scared", "nervous", "fear"]):
            return (
                "It's completely natural to feel anxious about health matters. "
                "Remember, NeuroVerse is a screening tool that helps catch things early — "
                "and early awareness is empowering, not frightening.\n\n"
                "Some stress-relief techniques:\n"
                "• Deep breathing: breathe in 4 sec, hold 7 sec, out 8 sec\n"
                "• Mindfulness meditation — even 10 min/day helps\n"
                "• Nature walks — 20 min in green spaces reduces cortisol\n"
                "• Talk to someone you trust about your feelings\n"
                "• Journaling and gratitude practice\n\n"
                "Chronic stress actually harms brain health, so managing it is important. "
                "Would you like to talk about what's on your mind?"
            )
        if any(w in msg_lower for w in ["clock", "drawing", "cdt"]):
            return (
                "The Clock Drawing Test (CDT) is one of our cognitive assessments. "
                "It evaluates visuospatial skills, executive function, and planning ability.\n\n"
                "You're asked to draw a clock showing a specific time. We evaluate:\n"
                "• Circle shape and closure\n"
                "• Number placement and completeness\n"
                "• Hand positioning and proportions\n\n"
                "It's scored on the Shulman scale (1-6, where 6 is perfect). "
                "Difficulties with this task can indicate early cognitive changes. "
                "Would you like to know about other tests?"
            )
        if any(w in msg_lower for w in ["spiral", "meander", "handwriting"]):
            return (
                "The spiral and meander drawing tests assess your motor control and hand steadiness.\n\n"
                "• Spiral Drawing: You trace a spiral pattern. We analyze tremor severity, "
                "smoothness, and regularity of your hand movement.\n"
                "• Meander Drawing: You follow a winding path. This tests motor precision "
                "and your ability to stay within boundaries.\n\n"
                "These tests can detect subtle tremors and motor changes that might indicate "
                "early Parkinson's. Would you like tips on improving motor function?"
            )
        if any(w in msg_lower for w in ["hello", "hi ", "hey", "good morning", "good evening", "howdy"]):
            return (
                "Hey there! 👋 I'm Neuro, your AI health companion in NeuroVerse. "
                "I'm here to help you understand your test results, share brain health tips, "
                "or just chat about anything on your mind.\n\n"
                "Here are some things I can help with:\n"
                "• Explaining your test results and risk scores\n"
                "• Brain health tips (diet, exercise, sleep, stress)\n"
                "• Information about Alzheimer's and Parkinson's\n"
                "• General wellness advice\n"
                "• Or just a friendly conversation!\n\n"
                "What would you like to talk about?"
            )
        if any(w in msg_lower for w in ["thank", "thanks", "appreciate"]):
            return (
                "You're very welcome! I'm always here whenever you need to chat. "
                "Remember, taking an active interest in your brain health is one of the "
                "best things you can do. Feel free to come back anytime with questions — "
                "no question is too small. Take care of yourself! 😊"
            )
        if any(w in msg_lower for w in ["how are you", "how r u", "what's up", "whats up"]):
            return (
                "I'm doing great, thanks for asking! I'm always ready and happy to chat. "
                "More importantly, how are YOU doing today? Is there anything about your "
                "health or wellness I can help you with, or would you just like to chat?"
            )
        if any(w in msg_lower for w in ["who are you", "what are you", "what can you do"]):
            return (
                "I'm Neuro — your AI health companion built right into NeuroVerse! "
                "Think of me as a knowledgeable friend who's always available.\n\n"
                "I can help you with:\n"
                "• Understanding your screening test results\n"
                "• Learning about Alzheimer's and Parkinson's disease\n"
                "• Brain-healthy lifestyle tips (diet, exercise, sleep)\n"
                "• Explaining what each test measures\n"
                "• Emotional support and encouragement\n"
                "• General health and daily life questions\n\n"
                "I'm NOT a doctor though — for medical concerns, always consult your healthcare provider. "
                "What can I help you with today?"
            )

        return (
            "Thanks for reaching out! I'm Neuro, your AI health companion. I can help "
            "you understand your test results, learn about brain health, answer general "
            "questions, or just have a friendly chat. Feel free to ask me anything — "
            "from your NeuroVerse scores to daily wellness tips. What's on your mind?"
        )
