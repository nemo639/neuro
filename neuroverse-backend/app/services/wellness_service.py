"""
Wellness Service - Daily wellness tracking and correlation analysis
"""

from datetime import datetime, timedelta, date
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from fastapi import HTTPException, status
from datetime import datetime, timezone
from app.models.wellness import WellnessEntry
from app.schemas.wellness import (
    WellnessEntryCreate, WellnessEntryUpdate, WellnessEntryResponse,
    WellnessDashboardResponse, WellnessHistoryResponse, WellnessMetric
)


class WellnessService:
    """Wellness tracking and analysis service."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_entry(self, user_id: int, data: WellnessEntryCreate) -> WellnessEntry:
        """Create a new wellness entry."""
        # Check if entry exists for today
        today = data.entry_date or datetime.now().date()
        
        existing = await self.db.execute(
            select(WellnessEntry).where(
                and_(
                    WellnessEntry.user_id == user_id,
                    func.date(WellnessEntry.entry_date) == today
                )
            )
        )
        
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Wellness entry already exists for today. Use update instead."
            )
        
        entry = WellnessEntry(
            user_id=user_id,
            sleep_hours=data.sleep_hours,
            sleep_quality=data.sleep_quality.value if data.sleep_quality else None,
            screen_time_hours=data.screen_time_hours,
            gaming_hours=data.gaming_hours,
            stress_level=data.stress_level,
            mood=data.mood.value if data.mood else None,
            anxiety_level=data.anxiety_level,
            physical_activity_minutes=data.physical_activity_minutes,
            exercise_type=data.exercise_type,
            water_intake_glasses=data.water_intake_glasses,
            notes=data.notes,
            entry_date=datetime.combine(today, datetime.min.time()),
        )
        
        self.db.add(entry)
        await self.db.commit()
        await self.db.refresh(entry)
        
        return entry
    
    async def update_entry(
        self, 
        user_id: int, 
        entry_id: int, 
        data: WellnessEntryUpdate
    ) -> WellnessEntry:
        """Update an existing wellness entry."""
        entry = await self._get_entry(entry_id, user_id)
        
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if hasattr(value, 'value'):  # Handle enums
                value = value.value
            setattr(entry, field, value)
        
        await self.db.commit()
        await self.db.refresh(entry)
        
        return entry
    
    async def get_entry(self, user_id: int, entry_id: int) -> WellnessEntry:
        """Get a specific wellness entry."""
        return await self._get_entry(entry_id, user_id)
    
    async def get_today_entry(self, user_id: int) -> Optional[WellnessEntry]:
        """Get today's wellness entry if exists."""
        from datetime import datetime
        today = datetime.now().date()  # Local date
    
        result = await self.db.execute(
        select(WellnessEntry).where(
            and_(
                WellnessEntry.user_id == user_id,
                func.date(WellnessEntry.created_at) == today  # Use created_at instead
            )
        )
    )
        return result.scalar_one_or_none()
    
    async def get_history(
        self, 
        user_id: int,
        days: int = 30,
        limit: int = 100
    ) -> WellnessHistoryResponse:
        """Get wellness history."""
        start_date = datetime.utcnow() - timedelta(days=days)
        
        result = await self.db.execute(
            select(WellnessEntry)
            .where(
                and_(
                    WellnessEntry.user_id == user_id,
                    WellnessEntry.entry_date >= start_date
                )
            )
            .order_by(WellnessEntry.entry_date.desc())
            .limit(limit)
        )
        
        entries = list(result.scalars().all())
        
        # Build daily summary for charts
        daily_summary = []
        for entry in entries:
            daily_summary.append({
                "date": entry.entry_date.strftime("%Y-%m-%d") if entry.entry_date else None,
                "sleep": entry.sleep_hours,
                "stress": entry.stress_level,
                "activity": entry.physical_activity_minutes,
                "screen_time": entry.screen_time_hours,
                "mood": entry.mood,
            })
        
        return WellnessHistoryResponse(
            entries=[WellnessEntryResponse.model_validate(e) for e in entries],
            total=len(entries),
            daily_summary=daily_summary,
        )
    
    async def get_dashboard(self, user_id: int) -> WellnessDashboardResponse:
        """Get wellness dashboard with averages and metrics."""
        today_entry = await self.get_today_entry(user_id)
        
        # Get last 7 days for averages
        week_ago = datetime.utcnow() - timedelta(days=7)
        result = await self.db.execute(
            select(WellnessEntry).where(
                and_(
                    WellnessEntry.user_id == user_id,
                    WellnessEntry.entry_date >= week_ago
                )
            )
        )
        week_entries = list(result.scalars().all())
        
        # Calculate averages
        avg_sleep = self._calculate_avg(week_entries, "sleep_hours")
        avg_screen = self._calculate_avg(week_entries, "screen_time_hours")
        avg_stress = self._calculate_avg(week_entries, "stress_level")
        avg_activity = self._calculate_avg(week_entries, "physical_activity_minutes")
        
        # Build metrics
        metrics = [
            WellnessMetric(
                name="Sleep",
                current_value=today_entry.sleep_hours if today_entry else None,
                unit="hours",
                trend=self._get_trend(week_entries, "sleep_hours"),
                trend_percentage=self._get_trend_pct(week_entries, "sleep_hours"),
                status=self._sleep_status(avg_sleep),
                recommendation=self._sleep_recommendation(avg_sleep),
            ),
            WellnessMetric(
                name="Screen Time",
                current_value=today_entry.screen_time_hours if today_entry else None,
                unit="hours",
                trend=self._get_trend(week_entries, "screen_time_hours", inverse=True),
                trend_percentage=self._get_trend_pct(week_entries, "screen_time_hours"),
                status=self._screen_status(avg_screen),
                recommendation=self._screen_recommendation(avg_screen),
            ),
            WellnessMetric(
                name="Stress Level",
                current_value=today_entry.stress_level if today_entry else None,
                unit="/10",
                trend=self._get_trend(week_entries, "stress_level", inverse=True),
                trend_percentage=self._get_trend_pct(week_entries, "stress_level"),
                status=self._stress_status(avg_stress),
                recommendation=self._stress_recommendation(avg_stress),
            ),
            WellnessMetric(
                name="Physical Activity",
                current_value=today_entry.physical_activity_minutes if today_entry else None,
                unit="min",
                trend=self._get_trend(week_entries, "physical_activity_minutes"),
                trend_percentage=self._get_trend_pct(week_entries, "physical_activity_minutes"),
                status=self._activity_status(avg_activity),
                recommendation=self._activity_recommendation(avg_activity),
            ),
        ]
        
        # Calculate logging streak
        streak = await self._calculate_streak(user_id)
        
        # Generate recommendations
        recommendations = self._generate_recommendations(avg_sleep, avg_screen, avg_stress, avg_activity)
        
        return WellnessDashboardResponse(
            user_id=user_id,
            today_entry=WellnessEntryResponse.model_validate(today_entry) if today_entry else None,
            has_logged_today=today_entry is not None,
            avg_sleep_hours=avg_sleep,
            avg_screen_time=avg_screen,
            avg_stress_level=avg_stress,
            avg_activity_minutes=avg_activity,
            metrics=metrics,
            correlations=[],  # TODO: Implement correlation analysis
            logging_streak=streak,
            recommendations=recommendations,
        )
    
    # ============== PRIVATE HELPERS ==============
    
    async def _get_entry(self, entry_id: int, user_id: int) -> WellnessEntry:
        """Get entry by ID, verify ownership."""
        result = await self.db.execute(
            select(WellnessEntry).where(
                and_(
                    WellnessEntry.id == entry_id,
                    WellnessEntry.user_id == user_id
                )
            )
        )
        entry = result.scalar_one_or_none()
        
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Wellness entry not found"
            )
        
        return entry
    
    def _calculate_avg(self, entries: List[WellnessEntry], field: str) -> Optional[float]:
        """Calculate average for a field."""
        values = [getattr(e, field) for e in entries if getattr(e, field) is not None]
        return sum(values) / len(values) if values else None
    
    def _get_trend(self, entries: List[WellnessEntry], field: str, inverse: bool = False) -> str:
        """Determine trend direction."""
        if len(entries) < 2:
            return "stable"
        
        # Compare first half to second half averages
        mid = len(entries) // 2
        first_half = entries[mid:]  # Older entries
        second_half = entries[:mid]  # Newer entries
        
        avg_first = self._calculate_avg(first_half, field) or 0
        avg_second = self._calculate_avg(second_half, field) or 0
        
        diff = avg_second - avg_first
        
        if abs(diff) < 0.1 * max(avg_first, 1):
            return "stable"
        
        if inverse:
            return "down" if diff > 0 else "up"
        return "up" if diff > 0 else "down"
    
    def _get_trend_pct(self, entries: List[WellnessEntry], field: str) -> float:
        """Calculate trend percentage change."""
        if len(entries) < 2:
            return 0.0
        
        mid = len(entries) // 2
        avg_first = self._calculate_avg(entries[mid:], field) or 0
        avg_second = self._calculate_avg(entries[:mid], field) or 0
        
        if avg_first == 0:
            return 0.0
        
        return round(((avg_second - avg_first) / avg_first) * 100, 1)
    
    async def _calculate_streak(self, user_id: int) -> int:
        """Calculate consecutive logging days."""
        result = await self.db.execute(
            select(WellnessEntry.entry_date)
            .where(WellnessEntry.user_id == user_id)
            .order_by(WellnessEntry.entry_date.desc())
        )
        dates = [r[0].date() if r[0] else None for r in result.all()]
        
        if not dates or dates[0] != date.today():
            return 0
        
        streak = 1
        for i in range(1, len(dates)):
            if dates[i] and dates[i-1] and (dates[i-1] - dates[i]).days == 1:
                streak += 1
            else:
                break
        
        return streak
    
    def _sleep_status(self, avg: Optional[float]) -> str:
        if avg is None:
            return "fair"
        if avg >= 7:
            return "good"
        elif avg >= 5:
            return "fair"
        return "poor"
    
    def _screen_status(self, avg: Optional[float]) -> str:
        if avg is None:
            return "fair"
        if avg <= 4:
            return "good"
        elif avg <= 7:
            return "fair"
        return "poor"
    
    def _stress_status(self, avg: Optional[float]) -> str:
        if avg is None:
            return "fair"
        if avg <= 4:
            return "good"
        elif avg <= 6:
            return "fair"
        return "poor"
    
    def _activity_status(self, avg: Optional[float]) -> str:
        if avg is None:
            return "fair"
        if avg >= 30:
            return "good"
        elif avg >= 15:
            return "fair"
        return "poor"
    
    def _sleep_recommendation(self, avg: Optional[float]) -> Optional[str]:
        if avg is None or avg >= 7:
            return None
        return "Aim for 7-9 hours of sleep for optimal cognitive health."
    
    def _screen_recommendation(self, avg: Optional[float]) -> Optional[str]:
        if avg is None or avg <= 4:
            return None
        return "Consider reducing screen time to less than 4 hours daily."
    
    def _stress_recommendation(self, avg: Optional[float]) -> Optional[str]:
        if avg is None or avg <= 4:
            return None
        return "Try stress-reduction techniques like meditation or deep breathing."
    
    def _activity_recommendation(self, avg: Optional[float]) -> Optional[str]:
        if avg is None or avg >= 30:
            return None
        return "Aim for at least 30 minutes of physical activity daily."
    
    def _generate_recommendations(
        self,
        sleep: Optional[float],
        screen: Optional[float],
        stress: Optional[float],
        activity: Optional[float]
    ) -> List[str]:
        """Generate personalized recommendations."""
        recs = []
        
        if sleep and sleep < 6:
            recs.append("🛏️ Prioritize sleep - aim for 7-8 hours nightly")
        
        if screen and screen > 6:
            recs.append("📱 Your screen time is high - try digital detox breaks")
        
        if stress and stress > 6:
            recs.append("🧘 High stress detected - consider mindfulness practices")
        
        if activity and activity < 20:
            recs.append("🚶 Increase daily movement - even short walks help")
        
        if not recs:
            recs.append("✨ Great job maintaining your wellness habits!")
        
        return recs
