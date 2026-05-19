import os
import requests


def detect_place_query(list_title, destination):
    title = list_title.lower().strip()

    category_map = [
        (
            ["пекарня", "пекарні", "булочна", "випічка", "bakery", "bakeries"],
            "bakery",
            "🥐",
        ),
        (
            ["кафе", "кавʼярня", "кав'ярня", "кав’ярня", "coffee", "cafe", "cafes"],
            "cafe",
            "☕",
        ),
        (
            ["ресторан", "ресторани", "їжа", "поісти", "поїсти", "restaurant", "restaurants", "food"],
            "restaurant",
            "🍽️",
        ),
        (
            ["парк", "парки", "сад", "сквер", "park", "parks", "garden"],
            "park",
            "🌳",
        ),
        (
            ["музей", "музеї", "галерея", "museum", "museums", "gallery"],
            "museum",
            "🏛️",
        ),
        (
            ["фото", "локації", "вид", "краєвид", "оглядовий", "photo", "viewpoint", "view"],
            "photo spot",
            "📸",
        ),
        (
            ["пляж", "пляжі", "море", "озеро", "beach", "beaches", "sea", "lake"],
            "beach",
            "🏖️",
        ),
        (
            ["бар", "бари", "паб", "bar", "bars", "pub"],
            "bar",
            "🍸",
        ),
        (
            ["шопінг", "магазини", "ринок", "shopping", "market", "mall"],
            "shopping",
            "🛍️",
        ),
    ]

    for keywords, category, icon in category_map:
        if any(keyword in title for keyword in keywords):
            return f"{category} in {destination}", icon

    return f"{list_title} in {destination}", "📍"


def build_google_maps_url(latitude, longitude, place_id=None):
    url = (
        "https://www.google.com/maps/search/?api=1"
        f"&query={latitude},{longitude}"
    )

    if place_id:
        url += f"&query_place_id={place_id}"

    return url


def search_places_for_list(trip, trip_list, max_results=5):
    api_key = os.getenv("GOOGLE_PLACES_API_KEY")

    if not api_key:
        raise ValueError("GOOGLE_PLACES_API_KEY is not set")

    destination = trip.destination or trip.title

    if not destination:
        raise ValueError("Trip destination is empty")

    text_query, icon = detect_place_query(
        list_title=trip_list.title,
        destination=destination,
    )

    response = requests.post(
        "https://places.googleapis.com/v1/places:searchText",
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.location,"
                "places.rating,"
                "places.userRatingCount,"
                "places.googleMapsUri"
            ),
        },
        json={
            "textQuery": text_query,
            "maxResultCount": max_results,
            "languageCode": "uk",
        },
        timeout=10,
    )

    if response.status_code != 200:
        raise ValueError(
            f"Google Places error {response.status_code}: {response.text}"
        )

    data = response.json()
    places = data.get("places", [])

    results = []

    for place in places:
        name = place.get("displayName", {}).get("text", "")
        address = place.get("formattedAddress", "")
        location = place.get("location", {})
        latitude = location.get("latitude")
        longitude = location.get("longitude")
        rating = place.get("rating")
        rating_count = place.get("userRatingCount")
        place_id = place.get("id")
        google_maps_uri = place.get("googleMapsUri")

        if not name or latitude is None or longitude is None:
            continue

        description_parts = []

        if address:
            description_parts.append(address)

        if rating:
            description_parts.append(f"Рейтинг: {rating}")

        if rating_count:
            description_parts.append(f"Відгуків: {rating_count}")

        results.append(
            {
                "title": name,
                "description": " · ".join(description_parts),
                "map_symbol": icon,
                "external_link": google_maps_uri
                or build_google_maps_url(latitude, longitude, place_id),
                "latitude": latitude,
                "longitude": longitude,
                "place_id": place_id,
                "rating": rating,
                "rating_count": rating_count,
            }
        )

    return {
        "query": text_query,
        "items": results,
    }