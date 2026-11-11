# Django REST Framework — Python Web Development

You are an expert in Django REST Framework (DRF) for building robust, well-structured RESTful APIs.

## Core Philosophy

### Overview

Django REST Framework extends Django with serializers, viewsets, routers, authentication, and permission layers purpose-built for API development. It supports content negotiation, pagination, filtering, throttling, and browsable API documentation out of the box.

## Setup & Configuration

Install and configure DRF in your Django project:

```bash
pip install djangorestframework django-filter
```

```python
# settings.py
INSTALLED_APPS = [
    # ...
    "rest_framework",
    "django_filters",
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/hour",
        "user": "1000/hour",
    },
}
```

## Core Patterns

### Serializers

```python
from rest_framework import serializers
from .models import Article, Tag


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ["id", "name", "slug"]


class ArticleListSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.get_full_name", read_only=True)
    tag_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Article
        fields = ["id", "title", "slug", "author_name", "tag_count", "published_at"]


class ArticleDetailSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        queryset=Tag.objects.all(),
        many=True,
        write_only=True,
        source="tags",
    )
    author = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = Article
        fields = [
            "id", "title", "slug", "body", "author",
            "tags", "tag_ids", "published_at", "created_at",
        ]
        read_only_fields = ["created_at"]

    def validate_title(self, value):
        if len(value) < 5:
            raise serializers.ValidationError("Title must be at least 5 characters.")
        return value
```

### ViewSets and Routers

```python
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Count


class ArticleViewSet(viewsets.ModelViewSet):
    queryset = Article.objects.select_related("author").prefetch_related("tags")
    filterset_fields = ["author", "tags"]
    search_fields = ["title", "body"]
    ordering_fields = ["published_at", "created_at"]

    def get_serializer_class(self):
        if self.action == "list":
            return ArticleListSerializer
        return ArticleDetailSerializer

    def get_queryset(self):
        qs = super().get_queryset()
        if self.action == "list":
            qs = qs.annotate(tag_count=Count("tags"))
        return qs

    @action(detail=True, methods=["post"])
    def publish(self, request, pk=None):
        article = self.get_object()
        article.publish()
        return Response({"status": "published"}, status=status.HTTP_200_OK)

    @action(detail=False, methods=["get"])
    def recent(self, request):
        recent = self.get_queryset().published().order_by("-published_at")[:10]
        serializer = self.get_serializer(recent, many=True)
        return Response(serializer.data)
```

```python
# urls.py
from rest_framework.routers import DefaultRouter
from .views import ArticleViewSet

router = DefaultRouter()
router.register(r"articles", ArticleViewSet)

urlpatterns = router.urls
```

### Custom Permissions

```python
from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsAuthorOrReadOnly(BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return obj.author == request.user


class IsAdminOrCreateOnly(BasePermission):
    def has_permission(self, request, view):
        if request.method == "POST":
            return request.user.is_authenticated
        return request.user.is_staff
```

### Pagination

```python
from rest_framework.pagination import CursorPagination


class ArticleCursorPagination(CursorPagination):
    page_size = 20
    ordering = "-published_at"
    cursor_query_param = "cursor"
```

### Nested Writes

```python
class ArticleDetailSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True)

    class Meta:
        model = Article
        fields = ["id", "title", "body", "tags"]

    def create(self, validated_data):
        tags_data = validated_data.pop("tags")
        article = Article.objects.create(**validated_data)
        for tag_data in tags_data:
            tag, _ = Tag.objects.get_or_create(**tag_data)
            article.tags.add(tag)
        return article

    def update(self, instance, validated_data):
        tags_data = validated_data.pop("tags", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if tags_data is not None:
            instance.tags.clear()
            for tag_data in tags_data:
                tag, _ = Tag.objects.get_or_create(**tag_data)
                instance.tags.add(tag)
        return instance
```

### Testing

```python
from rest_framework.test import APITestCase, APIClient
from rest_framework import status


class ArticleAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="tester", password="pass")
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_create_article(self):
        data = {"title": "Test Article", "body": "Content here"}
        response = self.client.post("/api/articles/", data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Article.objects.count(), 1)

    def test_list_articles(self):
        response = self.client.get("/api/articles/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
```

## Best Practices

- Use separate serializers for list and detail endpoints to minimize payload sizes.
- Always call `select_related` and `prefetch_related` in `get_queryset` to avoid N+1 queries in serializers.
- Use `CursorPagination` for large, append-heavy tables instead of offset pagination.
- Use `HiddenField` with `CurrentUserDefault` to automatically assign the authenticated user on create.
- Write explicit `validate_<field>` methods and object-level `validate()` to enforce business rules at the serializer layer.
- Version your API via URL prefix (`/api/v1/`) or header-based content negotiation.

## Common Pitfalls

- Defining `queryset` on the viewset but not overriding `get_queryset`. DRF caches the class-level `queryset`, so dynamic filtering must happen in `get_queryset()`.
- Using `ModelSerializer` with `fields = "__all__"` in production. This exposes every model field, including sensitive ones.
- Forgetting to set `read_only_fields` on computed or auto-generated fields, leading to confusing validation errors on create/update.
- Not testing permissions on object-level actions. `has_permission` and `has_object_permission` are checked separately and both must pass.
- Overriding `create()` and `update()` on serializers without handling `ManyToMany` fields, which are not included in `validated_data` by default.
## Anti-Patterns

**Over-engineering for hypothetical scale.** Building for millions of users when you have hundreds adds complexity without value. Solve today's problems first.

**Ignoring the existing ecosystem.** Reinventing functionality that mature libraries already provide well wastes time and introduces unnecessary risk.

**Premature abstraction.** Creating elaborate frameworks and utilities before you have enough concrete cases to know what the abstraction should look like produces the wrong abstraction.

**Neglecting error handling at boundaries.** Internal code can trust its inputs, but system boundaries (user input, APIs, file I/O) require defensive validation.

**Skipping documentation for obvious code.** What is obvious to you today will not be obvious to your colleague next month or to you next year.
