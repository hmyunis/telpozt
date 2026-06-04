import logging

import google.generativeai as genai

from app.config import Config

logger = logging.getLogger(__name__)

if Config.GEMINI_API_KEY:
    genai.configure(api_key=Config.GEMINI_API_KEY)


def generate_rewrite(system_prompt: str, source_text: str) -> str:
    try:
        model = genai.GenerativeModel(
            model_name=Config.GEMINI_MODEL,
            system_instruction=system_prompt,
        )
        response = model.generate_content(source_text)
        if response.text:
            return response.text.strip()
        raise ValueError("Empty response returned from Gemini API.")
    except Exception as e:
        logger.error(f"Gemini API generation failed: {e}")
        raise


def generate_topic_summary(text: str) -> str:
    try:
        model = genai.GenerativeModel(model_name=Config.GEMINI_MODEL)
        prompt = (
            "Summarize the main technical or informational topic of the following text in exactly one clear sentence. "
            "Focus only on the core message, without preamble or pleasantries:\n\n" + text
        )
        response = model.generate_content(prompt)
        if response.text:
            return response.text.strip()
        return "General Information Update"
    except Exception as e:
        logger.error(f"Topic summarization failed: {e}")
        return "Topic extraction unavailable"


def get_text_embedding(text: str) -> list[float]:
    try:
        normalized = " ".join(text.split())
        result = genai.embed_content(
            model=Config.GEMINI_EMBEDDING_MODEL,
            content=normalized,
            task_type="RETRIEVAL_DOCUMENT",
        )
        if "embedding" in result:
            return result["embedding"]
        raise ValueError("Invalid embedding structure returned.")
    except Exception as e:
        logger.error(f"Failed to generate embedding: {e}")
        raise
