TONE_DESCRIPTIONS = {
    "formal": "High vocabulary, strictly informative, structured, academic-grade tone without conversational filler.",
    "semi_formal": "Professional and objective tone, but readable, balanced, clear, and direct.",
    "casual": "Conversational, relaxed, friendly tone that speaks directly to the audience as a peer.",
    "punchy": "Highly energetic, concise, action-focused language designed to capture attention instantly.",
}

STRUCTURE_DESCRIPTIONS = {
    "paragraph": "Standard narrative form, utilizing coherent paragraph breaks.",
    "bullet_points": "Highly itemized list using structured bullet points to break down complex items.",
    "lead_conclusion": "An engaging, attention-grabbing opening headline, followed by context paragraphs, and closing with a summary.",
    "inverted_pyramid": "Most crucial information at the top, followed by secondary details and supporting context.",
}

EMOJI_DESCRIPTIONS = {
    "none": "Never use emojis under any circumstances.",
    "minimal": "Use emojis very sparingly (1-2 maximum), and only to highlight key structural headers.",
    "moderate": "Include descriptive emojis naturally within sentences to break up walls of text.",
    "heavy": "Incorporate emojis frequently at sentence starts, bullet points, and headers to drive visual engagement.",
}

JARGON_DESCRIPTIONS = {
    "preserve": "Keep specialized terms and technical terminology exactly as they are in the source.",
    "simplify": "Convert complex concepts and technical terms into simple, widely understood descriptions.",
    "explain_inline": "Keep technical terms, but provide a brief explanation in parentheses immediately after.",
}

CTA_DESCRIPTIONS = {
    "none": "Do not include any Call to Action commands or closing directives.",
    "soft": "End with a subtle suggestion, such as pointing the reader to a topic to consider or a gentle question to encourage discussion.",
    "strong": "End with a clear, direct call to action, urging the user to respond, comment, or share.",
}

HASHTAG_DESCRIPTIONS = {
    "none": "Never append tags or hashtags.",
    "minimal": "Add 1-2 highly relevant, broad categories at the very end of the post.",
    "topical": "Include several contextual hashtags to map standard keyword categories.",
}


def resolve_char_range(profile: dict) -> tuple[int, int]:
    preset = profile.get("length_preset")
    if preset == "short":
        return 200, 500
    if preset == "medium":
        return 500, 1000
    if preset == "long":
        return 1000, 2000
    if preset == "custom":
        return profile.get("char_min", 200), profile.get("char_max", 1000)
    return 500, 1000


def build_system_prompt(profile: dict, workspace: dict, recent_topics: list[str]) -> str:
    lines = []
    if profile.get("entity_name"):
        lines.append(f"You are writing on behalf of {profile['entity_name']}, a {profile.get('entity_type', 'organization')}.")
    lines.append(f"Tone: {TONE_DESCRIPTIONS.get(profile['tone'], 'Professional')}")
    lines.append(f"Structure: {STRUCTURE_DESCRIPTIONS.get(profile['structure'], 'Narrative paragraph')}")
    char_min, char_max = resolve_char_range(profile)
    lines.append(f"Length: {char_min}–{char_max} characters.")
    lines.append(f"Emoji usage: {EMOJI_DESCRIPTIONS.get(profile['emoji_usage'], 'Do not use emojis')}")
    lines.append(f"Technical jargon: {JARGON_DESCRIPTIONS.get(profile['jargon_handling'], 'Preserve specialized terms')}")
    lines.append(f"Call to action: {CTA_DESCRIPTIONS.get(profile['call_to_action'], 'No call to action')}")
    lines.append(f"Hashtags: {HASHTAG_DESCRIPTIONS.get(profile['hashtag_style'], 'Do not use hashtags')}")
    if profile.get("additional_instructions"):
        lines.append(f"Additional instructions: {profile['additional_instructions']}")
    if recent_topics:
        topics_str = "\n".join(f"- {t}" for t in recent_topics)
        lines.append(f"\nDo not rewrite content if it substantially covers any of these recently posted topics:\n{topics_str}")
    lines.append("\nRewrite the following Telegram post according to the above instructions. Output only the final post text, no preamble or extra commentary.")
    return "\n".join(lines)
