"""
Symptom Tracker API Endpoints
"""

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func
from datetime import date, datetime, timedelta
from typing import Optional

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.models.symptom import SymptomEntry

router = APIRouter()


@router.post("/log")
async def log_symptoms(
    body: dict,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Log daily symptoms. One entry per day (upserts)."""
    entry_date = date.today()

    # Check if entry exists for today
    result = await db.execute(
        select(SymptomEntry).where(
            and_(
                SymptomEntry.user_id == user_id,
                SymptomEntry.entry_date == entry_date,
            )
        )
    )
    entry = result.scalar_one_or_none()

    symptoms = {
        "memory_issues": body.get("memory_issues", 0),
        "confusion": body.get("confusion", 0),
        "tremors": body.get("tremors", 0),
        "balance_issues": body.get("balance_issues", 0),
        "speech_difficulty": body.get("speech_difficulty", 0),
        "sleep_disturbance": body.get("sleep_disturbance", 0),
        "mood_changes": body.get("mood_changes", 0),
        "fatigue": body.get("fatigue", 0),
    }

    # Calculate overall severity (average of all non-zero symptoms)
    values = [v for v in symptoms.values() if v > 0]
    overall = round(sum(values) / len(values), 1) if values else 0.0

    if entry:
        # Update existing
        for k, v in symptoms.items():
            setattr(entry, k, v)
        entry.overall_severity = overall
        entry.notes = body.get("notes", entry.notes)
    else:
        # Create new
        entry = SymptomEntry(
            user_id=user_id,
            entry_date=entry_date,
            **symptoms,
            overall_severity=overall,
            notes=body.get("notes"),
        )
        db.add(entry)

    await db.commit()
    await db.refresh(entry)

    return {
        "id": entry.id,
        "entry_date": str(entry.entry_date),
        "symptoms": symptoms,
        "overall_severity": overall,
        "notes": entry.notes,
    }


@router.get("/today")
async def get_today_symptoms(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get today's symptom entry if exists."""
    result = await db.execute(
        select(SymptomEntry).where(
            and_(
                SymptomEntry.user_id == user_id,
                SymptomEntry.entry_date == date.today(),
            )
        )
    )
    entry = result.scalar_one_or_none()

    if not entry:
        return {"logged_today": False, "symptoms": None}

    return {
        "logged_today": True,
        "symptoms": {
            "memory_issues": entry.memory_issues,
            "confusion": entry.confusion,
            "tremors": entry.tremors,
            "balance_issues": entry.balance_issues,
            "speech_difficulty": entry.speech_difficulty,
            "sleep_disturbance": entry.sleep_disturbance,
            "mood_changes": entry.mood_changes,
            "fatigue": entry.fatigue,
            "overall_severity": entry.overall_severity,
            "notes": entry.notes,
        },
    }


@router.get("/history")
async def get_symptom_history(
    days: int = Query(30, ge=1, le=365),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get symptom history for trend charts."""
    start_date = date.today() - timedelta(days=days)

    result = await db.execute(
        select(SymptomEntry)
        .where(
            and_(
                SymptomEntry.user_id == user_id,
                SymptomEntry.entry_date >= start_date,
            )
        )
        .order_by(SymptomEntry.entry_date)
    )
    entries = result.scalars().all()

    history = []
    for e in entries:
        history.append({
            "date": str(e.entry_date),
            "memory_issues": e.memory_issues,
            "confusion": e.confusion,
            "tremors": e.tremors,
            "balance_issues": e.balance_issues,
            "speech_difficulty": e.speech_difficulty,
            "sleep_disturbance": e.sleep_disturbance,
            "mood_changes": e.mood_changes,
            "fatigue": e.fatigue,
            "overall_severity": e.overall_severity,
        })

    # Calculate averages
    if entries:
        avg_severity = round(sum(e.overall_severity for e in entries) / len(entries), 1)
        most_common = max(
            ["memory_issues", "confusion", "tremors", "balance_issues",
             "speech_difficulty", "sleep_disturbance", "mood_changes", "fatigue"],
            key=lambda s: sum(getattr(e, s, 0) for e in entries),
        )
    else:
        avg_severity = 0.0
        most_common = None

    return {
        "entries": history,
        "total": len(entries),
        "avg_severity": avg_severity,
        "most_common_symptom": most_common,
        "days_logged": len(entries),
    }
