from datetime import datetime
import pytz

def generate_biblatex_date(date_str, time_str):
    """
    Combines a date and time, localizes it to Paris time to automatically
    find the correct UTC offset (handling Daylight Saving Time), and 
    outputs a strict Biblatex-admissible ISO 8601 string.
    
    Expected formats:
      date_str: 'YYYY-MM-DD'
      time_str: 'HH:MM'
    """
    # 1. Parse the raw input into a naive datetime object
    naive_dt = datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M")
    
    # 2. Apply the Europe/Paris timezone rules
    paris_tz = pytz.timezone('Europe/Paris')
    localized_dt = paris_tz.localize(naive_dt)
    
    # 3. Format to standard ISO 8601 with timezone offset
    return localized_dt.isoformat()

# --- Example Usage ---
user_date = "2020-10-20"
user_time = "20:10"

biblatex_timestamp = generate_biblatex_date(user_date, user_time)

print(f"For Biblatex entry use:")
print(f"date = {{{biblatex_timestamp}}}")
