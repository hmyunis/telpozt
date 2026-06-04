from app.utils.timezone import validate_iana_timezone

VALID_ENTITY_TYPES = {"company", "individual", "media_outlet", "community"}
VALID_TONES = {"formal", "semi_formal", "casual", "punchy"}
VALID_STRUCTURES = {"paragraph", "bullet_points", "lead_conclusion", "inverted_pyramid"}
VALID_LENGTH_PRESETS = {"short", "medium", "long", "custom"}
VALID_EMOJI_USAGES = {"none", "minimal", "moderate", "heavy"}
VALID_JARGON_HANDLING = {"preserve", "simplify", "explain_inline"}
VALID_CTA_STYLES = {"none", "soft", "strong"}
VALID_HASHTAG_STYLES = {"none", "minimal", "topical"}
VALID_PRIORITIES = {"high", "normal", "low"}


def validate_style_profile(data: dict):
    """
    Validates field integrity for style configuration schemas.
    Raises ValueError with context if validation checks fail.
    """
    required = [
        "name",
        "tone",
        "structure",
        "length_preset",
        "emoji_usage",
        "jargon_handling",
        "call_to_action",
        "hashtag_style",
    ]
    for req in required:
        if not data.get(req):
            raise ValueError(f"Missing required style configuration field: {req}")

    if data.get("entity_type") and data["entity_type"] not in VALID_ENTITY_TYPES:
        raise ValueError(f"Invalid entity_type. Must be one of: {VALID_ENTITY_TYPES}")
    if data["tone"] not in VALID_TONES:
        raise ValueError(f"Invalid tone. Must be one of: {VALID_TONES}")
    if data["structure"] not in VALID_STRUCTURES:
        raise ValueError(f"Invalid structure. Must be one of: {VALID_STRUCTURES}")
    if data["length_preset"] not in VALID_LENGTH_PRESETS:
        raise ValueError(f"Invalid length_preset. Must be one of: {VALID_LENGTH_PRESETS}")
    if data["emoji_usage"] not in VALID_EMOJI_USAGES:
        raise ValueError(f"Invalid emoji_usage. Must be one of: {VALID_EMOJI_USAGES}")
    if data["jargon_handling"] not in VALID_JARGON_HANDLING:
        raise ValueError(f"Invalid jargon_handling. Must be one of: {VALID_JARGON_HANDLING}")
    if data["call_to_action"] not in VALID_CTA_STYLES:
        raise ValueError(f"Invalid call_to_action style. Must be one of: {VALID_CTA_STYLES}")
    if data["hashtag_style"] not in VALID_HASHTAG_STYLES:
        raise ValueError(f"Invalid hashtag_style. Must be one of: {VALID_HASHTAG_STYLES}")

    if data["length_preset"] == "custom":
        char_min = data.get("char_min")
        char_max = data.get("char_max")
        if char_min is None or char_max is None:
            raise ValueError("Custom length presets require both char_min and char_max boundaries.")
        if not (isinstance(char_min, int) and isinstance(char_max, int)):
            raise ValueError("Character boundary ranges must be integers.")
        if char_min < 0 or char_max <= char_min:
            raise ValueError("Character range boundaries must be positive and incremental.")


def validate_user_input(data: dict, is_new=True):
    """Checks user-related fields and updates."""
    if is_new:
        if not data.get("username") or len(data["username"].strip()) < 3:
            raise ValueError("Username is required and must contain at least 3 characters.")
        if not data.get("password") or len(data["password"]) < 8:
            raise ValueError("Passwords must contain at least 8 characters.")
        if not data.get("telegram_chat_id"):
            raise ValueError("A valid Telegram DM target notification ID is required.")

    if "timezone" in data:
        if not validate_iana_timezone(data["timezone"]):
            raise ValueError(f"The zone '{data['timezone']}' is not a recognized IANA timezone.")


def validate_channel_priority(priority: str):
    """Checks prioritize filters."""
    if priority not in VALID_PRIORITIES:
        raise ValueError(f"Invalid scraping tier option. Must be one of: {VALID_PRIORITIES}")
