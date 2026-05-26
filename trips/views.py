import re
import html
import requests

from django.contrib.auth.models import User
from django.db.models import Q

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
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


def user_has_trip_access(trip, user):
    return trip.user == user or trip.members.filter(id=user.id).exists()


class TripViewSet(viewsets.ModelViewSet):
    serializer_class = TripSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        return Trip.objects.filter(
            Q(user=user) | Q(members=user)
        ).distinct().order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'], url_path='share')
    def share(self, request, pk=None):
        trip = self.get_object()

        if trip.user != request.user:
            return Response(
                {'error': 'Тільки власник подорожі може надавати доступ.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        email = request.data.get('email', '').strip().lower()

        if not email:
            return Response(
                {'error': 'Вкажіть email користувача.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user_to_add = User.objects.filter(email__iexact=email).first()

        if not user_to_add:
            return Response(
                {'error': 'Користувача з таким email не знайдено.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if user_to_add == trip.user:
            return Response(
                {'error': 'Власник уже має доступ до цієї подорожі.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if trip.members.filter(id=user_to_add.id).exists():
            return Response(
                {'message': 'Цей користувач уже має доступ до подорожі.'},
                status=status.HTTP_200_OK,
            )

        trip.members.add(user_to_add)

        return Response(
            {
                'message': f'Користувачу {user_to_add.email} надано доступ до подорожі.',
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=['post'], url_path='unshare')
    def unshare(self, request, pk=None):
        trip = self.get_object()

        if trip.user != request.user:
            return Response(
                {'error': 'Тільки власник подорожі може забирати доступ.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        email = request.data.get('email', '').strip().lower()

        if not email:
            return Response(
                {'error': 'Вкажіть email користувача.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user_to_remove = User.objects.filter(email__iexact=email).first()

        if not user_to_remove:
            return Response(
                {'error': 'Користувача з таким email не знайдено.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if user_to_remove == trip.user:
            return Response(
                {'error': 'Не можна забрати доступ у власника подорожі.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        trip.members.remove(user_to_remove)

        return Response(
            {
                'message': f'Доступ для {user_to_remove.email} забрано.',
            },
            status=status.HTTP_200_OK,
        )


class ListViewSet(viewsets.ModelViewSet):
    serializer_class = ListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = List.objects.filter(
            Q(trip__user=self.request.user) | Q(trip__members=self.request.user)
        ).distinct()

        trip_id = self.request.query_params.get('trip')

        if trip_id:
            queryset = queryset.filter(trip_id=trip_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        trip = serializer.validated_data.get('trip')

        if not user_has_trip_access(trip, self.request.user):
            raise permissions.PermissionDenied(
                'У вас немає доступу до цієї подорожі.'
            )

        serializer.save()


class ListItemViewSet(viewsets.ModelViewSet):
    serializer_class = ListItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = ListItem.objects.filter(
            Q(list__trip__user=self.request.user) |
            Q(list__trip__members=self.request.user)
        ).distinct()

        list_id = self.request.query_params.get('list')
        trip_id = self.request.query_params.get('trip')

        if list_id:
            queryset = queryset.filter(list_id=list_id)

        if trip_id:
            queryset = queryset.filter(list__trip_id=trip_id)

        return queryset.order_by('position', 'created_at')

    def perform_create(self, serializer):
        trip_list = serializer.validated_data.get('list')

        if not user_has_trip_access(trip_list.trip, self.request.user):
            raise permissions.PermissionDenied(
                'У вас немає доступу до цього списку.'
            )

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
                Q(id=list_id),
                Q(trip__user=request.user) | Q(trip__members=request.user),
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