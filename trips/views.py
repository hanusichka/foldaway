import re
import html
import requests

from rest_framework import viewsets, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response

from .places_service import search_places_for_list

from .models import Trip, List, ListItem
from .serializers import TripSerializer, ListSerializer, ListItemSerializer


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
            result = search_places_for_list(
                trip=trip_list.trip,
                trip_list=trip_list,
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
                "query": result["query"],
                "items": result["items"],
            },
            status=status.HTTP_200_OK,
        )