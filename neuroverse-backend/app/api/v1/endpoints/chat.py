"""
Chat API Endpoints - Neuro AI Health Companion (Multi-conversation)
"""

import logging
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.db.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.services.chat_service import ChatService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/chat", tags=["Chat"])


# ── Conversation Management ──────────────────────────────────


@router.get("/conversations")
async def list_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all conversations for the current user."""
    try:
        service = ChatService(db)
        conversations = await service.list_conversations(current_user.id)
        return {"conversations": conversations}
    except Exception as e:
        logger.error("List conversations error: %s", e)
        return {"conversations": []}


@router.post("/conversations")
async def create_conversation(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new empty conversation."""
    try:
        title = body.get("title", "New Chat")
        service = ChatService(db)
        conv = await service.create_conversation(current_user.id, title=title)
        return conv
    except Exception as e:
        logger.error("Create conversation error: %s", e)
        return {"error": "Failed to create conversation"}


@router.put("/conversations/{conversation_id}/rename")
async def rename_conversation(
    conversation_id: str,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Rename a conversation."""
    try:
        title = body.get("title", "").strip()
        if not title:
            return {"error": "Title cannot be empty"}
        service = ChatService(db)
        ok = await service.rename_conversation(current_user.id, conversation_id, title)
        return {"success": ok}
    except Exception as e:
        logger.error("Rename conversation error: %s", e)
        return {"success": False}


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a single conversation and its messages."""
    try:
        service = ChatService(db)
        await service.delete_conversation(current_user.id, conversation_id)
        return {"success": True, "message": "Conversation deleted"}
    except Exception as e:
        logger.error("Delete conversation error: %s", e)
        return {"success": False}


# ── Messages ─────────────────────────────────────────────────


@router.get("/history")
async def get_chat_history(
    conversation_id: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
):
    """Get messages for a specific conversation."""
    try:
        service = ChatService(db)
        return await service.get_history(current_user.id, conversation_id, limit=limit)
    except Exception as e:
        logger.error("Chat history error: %s", e)
        return {"conversation_id": conversation_id, "messages": []}


@router.post("/send")
async def send_message(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Send a message. If no conversation_id, a new conversation is auto-created."""
    message = body.get("message", "").strip()
    if not message:
        return {"error": "Message cannot be empty"}

    conversation_id = body.get("conversation_id")

    try:
        service = ChatService(db)
        result = await service.send_message(
            user_id=current_user.id,
            message=message,
            conversation_id=conversation_id,
        )
        return result
    except Exception as e:
        logger.error("Chat send error: %s", e, exc_info=True)
        return {
            "conversation_id": conversation_id,
            "reply": f"I'm having trouble right now: {str(e)[:200]}. Please try again in a moment.",
        }


@router.delete("/clear")
async def clear_all_chats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Clear ALL conversations and messages for the user."""
    try:
        service = ChatService(db)
        await service.clear_all_conversations(current_user.id)
    except Exception as e:
        logger.error("Chat clear error: %s", e)
    return {"success": True, "message": "All chat history cleared"}
