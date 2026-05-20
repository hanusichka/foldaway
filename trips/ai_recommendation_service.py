import json
import os

from openai import OpenAI


def _compact_place_for_ai(index, item):
    return {
        "index": index,
        "title": item.get("title", ""),
        "description": item.get("description", ""),
        "rating": item.get("rating"),
        "rating_count": item.get("rating_count"),
        "external_link": item.get("external_link", ""),
        "latitude": item.get("latitude"),
        "longitude": item.get("longitude"),
    }


def _safe_json_loads(text):
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")

        if start != -1 and end != -1 and end > start:
            return json.loads(text[start:end + 1])

        raise


# def choose_best_place_with_ai(trip, trip_list, query, items):
#     if not items:
#         raise ValueError("No places were provided for AI recommendation")

#     api_key = os.getenv("OPENAI_API_KEY")

#     if not api_key:
#         raise ValueError("OPENAI_API_KEY is not set")

#     client = OpenAI(api_key=api_key)

#     compact_items = [
#         _compact_place_for_ai(index, item)
#         for index, item in enumerate(items)
#     ]

#     destination = trip.destination or trip.title or "unknown destination"
#     list_title = trip_list.title or "travel list"

#     prompt = f"""
# You are an expert travel recommendation assistant for a travel planning app.

# The user has a trip and a list inside that trip.

# Trip destination:
# {destination}

# List title:
# {list_title}

# Google Places search query:
# {query}

# Candidate places from Google Places:
# {json.dumps(compact_items, ensure_ascii=False, indent=2)}

# Task:
# Choose exactly ONE best place from the candidate places.

# Decision rules:
# - Choose a real concrete place only from the provided candidates.
# - Do not invent new places.
# - Prefer places that feel local, memorable, high-quality, and useful for a traveler.
# - Avoid generic chains if a more distinctive local option exists.
# - Consider rating and rating_count, but do not blindly choose only the highest rating.
# - If the list title is about food, cafes, bakeries, museums, parks, photo spots, views, beaches, bars, hotels, shopping, or similar travel locations, choose the best matching place.
# - Do not suggest packing items, forgotten things, documents, chargers, clothes, luggage, or todo-list items.

# Return only valid JSON in this exact format:
# {{
#   "selected_index": 0,
#   "reason": "Short explanation in Ukrainian why this is the best recommendation.",
#   "short_description": "One short Ukrainian sentence describing the place."
# }}
# """

#     response = client.responses.create(
#         model="gpt-4.1-mini",
#         input=prompt,
#         temperature=0.2,
#     )

#     raw_text = response.output_text.strip()
#     data = _safe_json_loads(raw_text)

#     selected_index = data.get("selected_index")

#     if not isinstance(selected_index, int):
#         raise ValueError("AI response does not contain a valid selected_index")

#     if selected_index < 0 or selected_index >= len(items):
#         raise ValueError("AI selected_index is out of range")

#     selected_item = dict(items[selected_index])

#     reason = data.get("reason", "").strip()
#     short_description = data.get("short_description", "").strip()

#     if reason:
#         selected_item["reason"] = reason

#     if short_description:
#         selected_item["ai_description"] = short_description

#     return {
#         "item": selected_item,
#         "selected_index": selected_index,
#         "reason": reason,
#         "ai_description": short_description,
#     }

def choose_best_places_with_ai(trip, trip_list, query, items, limit=5):
    if not items:
        raise ValueError("No places were provided for AI recommendations")

    api_key = os.getenv("OPENAI_API_KEY")

    if not api_key:
        raise ValueError("OPENAI_API_KEY is not set")

    client = OpenAI(api_key=api_key)

    compact_items = [
        _compact_place_for_ai(index, item)
        for index, item in enumerate(items)
    ]

    destination = trip.destination or trip.title or "unknown destination"
    list_title = trip_list.title or "travel list"

    prompt = f"""
You are an expert travel recommendation assistant for a travel planning app.

The user has a trip and a list inside that trip.

Trip destination:
{destination}

List title:
{list_title}

Google Places search query:
{query}

Candidate places from Google Places:
{json.dumps(compact_items, ensure_ascii=False, indent=2)}

Task:
Choose up to {limit} best places from the candidate places.

Decision rules:
- Choose only real concrete places from the provided candidates.
- Do not invent new places.
- Do not choose duplicates.
- Prefer places that feel local, memorable, high-quality, and useful for a traveler.
- Avoid generic chains if more distinctive local options exist.
- Consider rating and rating_count, but do not blindly choose only the highest rating.
- Make the recommendations diverse if possible.
- If the list title is about food, cafes, bakeries, museums, parks, photo spots, views, beaches, bars, hotels, shopping, or similar travel locations, choose the best matching places.
- Do not suggest packing items, forgotten things, documents, chargers, clothes, luggage, or todo-list items.

Return only valid JSON in this exact format:
{{
  "recommendations": [
    {{
      "selected_index": 0,
      "reason": "Short explanation in Ukrainian why this place is recommended.",
      "short_description": "One short Ukrainian sentence describing the place."
    }}
  ]
}}
"""

    response = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt,
        temperature=0.2,
    )

    raw_text = response.output_text.strip()
    data = _safe_json_loads(raw_text)

    recommendations = data.get("recommendations")

    if not isinstance(recommendations, list):
        raise ValueError("AI response does not contain recommendations list")

    selected_items = []
    used_indexes = set()

    for recommendation in recommendations:
        selected_index = recommendation.get("selected_index")

        if not isinstance(selected_index, int):
            continue

        if selected_index < 0 or selected_index >= len(items):
            continue

        if selected_index in used_indexes:
            continue

        used_indexes.add(selected_index)

        selected_item = dict(items[selected_index])

        reason = recommendation.get("reason", "").strip()
        short_description = recommendation.get("short_description", "").strip()

        if reason:
            selected_item["reason"] = reason

        if short_description:
            selected_item["ai_description"] = short_description

        selected_item["selected_index"] = selected_index

        selected_items.append(selected_item)

        if len(selected_items) >= limit:
            break

    if not selected_items:
        raise ValueError("AI did not select any valid places")

    return {
        "items": selected_items,
        "count": len(selected_items),
    }