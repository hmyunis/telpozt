import json
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def validate_iana_timezone(tz_name: str) -> bool:
    """Checks if a timezone string exists in the system IANA database."""
    try:
        ZoneInfo(tz_name)
        return True
    except (ZoneInfoNotFoundError, ValueError):
        return False


def convert_local_slots_to_utc(slots_list: list[str], tz_name: str) -> str:
    """
    Converts local HH:MM schedules into UTC HH:MM slots on the current date,
    then returns them as a JSON list string.
    """
    local_tz = ZoneInfo(tz_name)
    utc_tz = ZoneInfo("UTC")
    now_local = datetime.now(local_tz)

    utc_slots = []
    for slot in slots_list:
        try:
            h, m = map(int, slot.split(":"))
            dt_local = now_local.replace(hour=h, minute=m, second=0, microsecond=0)
            dt_utc = dt_local.astimezone(utc_tz)
            utc_slots.append(dt_utc.strftime("%H:%M"))
        except (ValueError, IndexError) as err:
            raise ValueError(f"Invalid time format: {slot}. Use HH:MM.") from err

    return json.dumps(sorted(utc_slots))


def convert_utc_slots_to_local(utc_slots_json: str, tz_name: str) -> list[str]:
    """Converts serialized UTC time slots back into local user times for display."""
    local_tz = ZoneInfo(tz_name)
    utc_tz = ZoneInfo("UTC")
    now_utc = datetime.now(utc_tz)

    slots_list = json.loads(utc_slots_json)
    local_slots = []
    for slot in slots_list:
        h, m = map(int, slot.split(":"))
        dt_utc = now_utc.replace(hour=h, minute=m, second=0, microsecond=0)
        dt_local = dt_utc.astimezone(local_tz)
        local_slots.append(dt_local.strftime("%H:%M"))

    return sorted(local_slots)


def get_current_utc_iso() -> str:
    """Returns the current timestamp as a standard ISO string."""
    return datetime.now(ZoneInfo("UTC")).isoformat()
