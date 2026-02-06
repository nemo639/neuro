"""Run server with detailed logging to file."""
import sys
import os
import logging
import traceback as tb

# Set up file logging
log_file = "d:/neuroverse/neuroverse-backend/server_debug.log"
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, mode='w'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Patch sys.excepthook to log unhandled exceptions
def exception_handler(exc_type, exc_value, exc_tb):
    logger.error("Uncaught exception", exc_info=(exc_type, exc_value, exc_tb))

sys.excepthook = exception_handler

# Now start uvicorn
import uvicorn

logger.info("Starting NeuroVerse server with debug logging...")
logger.info(f"Log file: {log_file}")

try:
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8001,  # Use different port
        log_level="debug",
        access_log=True
    )
except Exception as e:
    logger.error(f"Server crashed: {e}")
    logger.error(tb.format_exc())
