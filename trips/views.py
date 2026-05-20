import re
import html
import requests

from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response

from .places_service import (
    search_places_for_list,
    resolve_place_id_from_text,
    is_similar_place_title,
)

from .models import Trip, List, ListItem
from .serializers import TripSerializer, ListSerializer, ListItemSerializer
from .ai_recommendation_service import choose_best_places_with_ai
#from .ai_recommendation_service import choose_best_place_with_ai


def extract_coordinates_from_google_maps_url(url):
    if not url:
        return None, None

    urls_to_check = [url]

    try:
        response = requests.get(
            url,
            allow_redirects=True,
            timeout=10,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0 Safari/537.36"
                )
            },
        )

        final_url = response.url
        response_text = response.text

        print("ORIGINAL URL:", url)
        print("FINAL URL:", final_url)

        urls_to_check.append(final_url)

        found_urls = re.findall(
            r'https://www\.google\.com/maps[^"\']+',
            response_text,
        )
        urls_to_check.extend(found_urls)

        urls_to_check.append(response_text)

    except requests.RequestException as e:
        print("REQUEST ERROR:", e)

    normalized_values = []

    for value in urls_to_check:
        value = html.unescape(value)

        value = (
            value.replace("\\u003d", "=")
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("%2C", ",")
            .replace("%3A", ":")
            .replace("%2F", "/")
            .replace("%3F", "?")
            .replace("%3D", "=")
            .replace("%26", "&")
        )

        normalized_values.append(value)

    patterns = [
        r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
        r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
        r'query=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
        r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
        r'll=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
        r'\[null,null,(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\]',
    ]

    for candidate in normalized_values:
        print("CHECKING:", candidate[:300])

        for pattern in patterns:
            match = re.search(pattern, candidate)

            if match:
                latitude = float(match.group(1))
                longitude = float(match.group(2))

                print("FOUND COORDINATES:", latitude, longitude)

                return latitude, longitude

    coordinate_pair_pattern = re.compile(
        r'(-?\d{1,3}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})'
    )

    for candidate in normalized_values:
        matches = coordinate_pair_pattern.findall(candidate)

        for first, second in matches:
            first_value = float(first)
            second_value = float(second)

            if -90 <= first_value <= 90 and -180 <= second_value <= 180:
                print(
                    "FOUND FALLBACK COORDINATES:",
                    first_value,
                    second_value,
                )
                return first_value, second_value

            if -180 <= first_value <= 180 and -90 <= second_value <= 90:
                print(
                    "FOUND FALLBACK COORDINATES:",
                    second_value,
                    first_value,
                )
                return second_value, first_value

    print("NO COORDINATES FOUND")

    return None, None


class TripViewSet(viewsets.ModelViewSet):
    serializer_class = TripSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Trip.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ListViewSet(viewsets.ModelViewSet):
    serializer_class = ListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = List.objects.filter(trip__user=self.request.user)

        trip_id = self.request.query_params.get('trip')
        if trip_id:
            queryset = queryset.filter(trip_id=trip_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        serializer.save()


class ListItemViewSet(viewsets.ModelViewSet):
    serializer_class = ListItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = ListItem.objects.filter(list__trip__user=self.request.user)

        list_id = self.request.query_params.get('list')
        trip_id = self.request.query_params.get('trip')

        if list_id:
            queryset = queryset.filter(list_id=list_id)

        if trip_id:
            queryset = queryset.filter(list__trip_id=trip_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        external_link = self.request.data.get('external_link', '')
        latitude = self.request.data.get('latitude')
        longitude = self.request.data.get('longitude')

        if external_link and (not latitude or not longitude):
            latitude, longitude = extract_coordinates_from_google_maps_url(
                external_link
            )

        serializer.save(
            latitude=latitude,
            longitude=longitude,
        )

    def perform_update(self, serializer):
        instance = self.get_object()

        external_link = self.request.data.get(
            'external_link',
            instance.external_link,
        )

        latitude = self.request.data.get(
            'latitude',
            instance.latitude,
        )

        longitude = self.request.data.get(
            'longitude',
            instance.longitude,
        )

        if external_link and (not latitude or not longitude):
            extracted_latitude, extracted_longitude = (
                extract_coordinates_from_google_maps_url(external_link)
            )

            if extracted_latitude is not None and extracted_longitude is not None:
                latitude = extracted_latitude
                longitude = extracted_longitude

        serializer.save(
            latitude=latitude,
            longitude=longitude,
        )

def filter_existing_places_from_candidates(trip, trip_list, candidates):
    existing_items = ListItem.objects.filter(list=trip_list)

    destination = trip.destination or trip.title

    existing_place_ids = set()
    existing_titles = []

    for existing_item in existing_items:
        if existing_item.title:
            existing_titles.append(existing_item.title)

            resolved_place_id = resolve_place_id_from_text(
                title=existing_item.title,
                destination=destination,
            )

            if resolved_place_id:
                existing_place_ids.add(resolved_place_id)

    filtered_candidates = []

    for candidate in candidates:
        candidate_place_id = candidate.get("place_id")
        candidate_title = candidate.get("title", "")

        if candidate_place_id and candidate_place_id in existing_place_ids:
            continue

        is_duplicate_by_title = any(
            is_similar_place_title(candidate_title, existing_title)
            for existing_title in existing_titles
        )

        if is_duplicate_by_title:
            continue

        filtered_candidates.append(candidate)

    return filtered_candidates

class GooglePlacesSuggestionsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        list_id = request.data.get("list_id")

        if not list_id:
            return Response(
                {"detail": "list_id is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            trip_list = List.objects.get(
                id=list_id,
                trip__user=request.user,
            )
        except List.DoesNotExist:
            return Response(
                {"detail": "List not found"},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            places_result = search_places_for_list(
                trip=trip_list.trip,
                trip_list=trip_list,
                max_results=8,
            )
        except ValueError as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        items = places_result["items"]

        items = filter_existing_places_from_candidates(
            trip=trip_list.trip,
            trip_list=trip_list,
            candidates=items,
        )

        existing_items = ListItem.objects.filter(list=trip_list)

        existing_titles = {
            item.title.strip().lower()
            for item in existing_items
            if item.title
        }

        existing_links = {
            item.external_link.strip()
            for item in existing_items
            if item.external_link
        }

        filtered_items = []

        for item in items:
            title = item.get("title", "").strip().lower()
            external_link = item.get("external_link", "").strip()

            if title in existing_titles:
                continue

            if external_link and external_link in existing_links:
                continue

            filtered_items.append(item)

        items = filtered_items

        if not items:
            return Response(
                {
                    "detail": "No new places found. All good candidates may already be in this list.",
                    "query": places_result["query"],
                    "items": [],
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            ai_result = choose_best_places_with_ai(
                trip=trip_list.trip,
                trip_list=trip_list,
                query=places_result["query"],
                items=items,
            )
        except ValueError as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(
            {
                "trip": {
                    "id": trip_list.trip.id,
                    "title": trip_list.trip.title,
                    "destination": trip_list.trip.destination,
                },
                "list": {
                    "id": trip_list.id,
                    "title": trip_list.title,
                },
                "query": places_result["query"],
                "items": ai_result["items"],
                "recommendations_count": ai_result["count"],
                "candidates_count": len(items),
            },
            status=status.HTTP_200_OK,
        )