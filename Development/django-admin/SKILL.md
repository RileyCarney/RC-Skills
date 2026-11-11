# Django Admin — Python Web Development

You are an expert in customizing the Django admin interface for efficient back-office management.

## Core Philosophy

### Overview

Django's admin site provides an auto-generated CRUD interface for database models. It supports list views with filtering and search, inline editing of related models, custom actions, permission controls, and form customization. With targeted overrides it can serve as a full internal tool.

## Setup & Configuration

```python
# settings.py
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # ...
]

# urls.py
from django.contrib import admin
from django.urls import path

admin.site.site_header = "My App Admin"
admin.site.site_title = "My App"
admin.site.index_title = "Dashboard"

urlpatterns = [
    path("admin/", admin.site.urls),
]
```

## Core Patterns

### Basic ModelAdmin

```python
from django.contrib import admin
from .models import Article, Tag, Comment


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "author", "status_badge", "published_at", "created_at"]
    list_filter = ["published_at", "author", "tags"]
    search_fields = ["title", "body", "author__username"]
    prepopulated_fields = {"slug": ("title",)}
    date_hierarchy = "created_at"
    ordering = ["-created_at"]
    list_per_page = 25
    list_select_related = ["author"]
    raw_id_fields = ["author"]
    autocomplete_fields = ["tags"]
    readonly_fields = ["created_at", "updated_at"]

    fieldsets = (
        (None, {
            "fields": ("title", "slug", "body"),
        }),
        ("Publishing", {
            "fields": ("author", "published_at", "tags"),
            "classes": ("collapse",),
        }),
        ("Metadata", {
            "fields": ("created_at", "updated_at"),
        }),
    )

    @admin.display(description="Status", ordering="published_at")
    def status_badge(self, obj):
        if obj.published_at:
            return "Published"
        return "Draft"
```

### Inline Editing

```python
class CommentInline(admin.TabularInline):
    model = Comment
    extra = 0
    fields = ["user", "body", "approved", "created_at"]
    readonly_fields = ["created_at"]
    raw_id_fields = ["user"]
    show_change_link = True


class ImageInline(admin.StackedInline):
    model = ArticleImage
    extra = 1
    max_num = 10


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    inlines = [ImageInline, CommentInline]
```

### Custom Actions

```python
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    actions = ["publish_selected", "unpublish_selected", "export_as_csv"]

    @admin.action(description="Publish selected articles")
    def publish_selected(self, request, queryset):
        count = queryset.filter(published_at__isnull=True).update(
            published_at=timezone.now()
        )
        self.message_user(request, f"{count} articles published.")

    @admin.action(description="Export selected as CSV")
    def export_as_csv(self, request, queryset):
        import csv
        from django.http import HttpResponse

        response = HttpResponse(content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="articles.csv"'
        writer = csv.writer(response)
        writer.writerow(["Title", "Author", "Published At"])
        for article in queryset.select_related("author"):
            writer.writerow([
                article.title,
                article.author.username,
                article.published_at,
            ])
        return response
```

### Custom Filters

```python
class HasCommentsFilter(admin.SimpleListFilter):
    title = "has comments"
    parameter_name = "has_comments"

    def lookups(self, request, model_admin):
        return [
            ("yes", "Has comments"),
            ("no", "No comments"),
        ]

    def queryset(self, request, queryset):
        if self.value() == "yes":
            return queryset.filter(comments__isnull=False).distinct()
        if self.value() == "no":
            return queryset.filter(comments__isnull=True)
        return queryset


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    list_filter = ["published_at", HasCommentsFilter]
```

### Overriding QuerySets and Save Behavior

```python
@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        qs = qs.select_related("author").prefetch_related("tags")
        if not request.user.is_superuser:
            qs = qs.filter(author=request.user)
        return qs

    def save_model(self, request, obj, form, change):
        if not change:  # creating
            obj.author = request.user
        super().save_model(request, obj, form, change)

    def has_delete_permission(self, request, obj=None):
        if obj and obj.published_at:
            return False  # prevent deleting published articles
        return super().has_delete_permission(request, obj)
```

### Custom Admin Views

```python
from django.urls import path
from django.template.response import TemplateResponse


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                "stats/",
                self.admin_site.admin_view(self.stats_view),
                name="article_stats",
            ),
        ]
        return custom_urls + urls

    def stats_view(self, request):
        context = {
            **self.admin_site.each_context(request),
            "title": "Article Statistics",
            "total_articles": Article.objects.count(),
            "published_count": Article.objects.filter(
                published_at__isnull=False
            ).count(),
        }
        return TemplateResponse(
            request, "admin/article_stats.html", context
        )
```

### Custom Form Widgets

```python
from django import forms


class ArticleAdminForm(forms.ModelForm):
    class Meta:
        model = Article
        fields = "__all__"
        widgets = {
            "body": forms.Textarea(attrs={"rows": 20, "class": "vLargeTextField"}),
        }

    def clean_title(self):
        title = self.cleaned_data["title"]
        if title.isupper():
            raise forms.ValidationError("Title should not be all caps.")
        return title


@admin.register(Article)
class ArticleAdmin(admin.ModelAdmin):
    form = ArticleAdminForm
```

## Best Practices

- Always set `list_select_related` and override `get_queryset` to prefetch related data. Admin list views easily generate hundreds of queries without this.
- Use `raw_id_fields` or `autocomplete_fields` for ForeignKey fields that reference tables with many rows. The default dropdown loads every row.
- Use `readonly_fields` for computed or auto-generated fields to prevent accidental edits.
- Use `fieldsets` to organize fields into logical sections and hide rarely used fields under collapsible sections.
- Restrict access with `has_view_permission`, `has_change_permission`, `has_delete_permission`, and `has_add_permission` for fine-grained control.
- Use `@admin.display(ordering=...)` on custom list display methods to enable column sorting.

## Common Pitfalls

- Registering the same model twice causes an `AlreadyRegistered` error. Use `@admin.register(Model)` decorator instead of calling `admin.site.register()` separately.
- Using `fields = "__all__"` on admin forms can expose sensitive fields. Always list fields explicitly in production.
- Not using `list_select_related`, causing the admin list view to run a separate query for every row's ForeignKey display.
- Adding expensive annotations in `get_queryset` without realizing they run on every admin page load, including the changelist and change form.
- Forgetting to wrap custom admin URLs with `self.admin_site.admin_view()`, which skips authentication checks and CSRF protection.
- Overriding `save_model` without calling `super()`, which prevents the object from being saved to the database.
## Anti-Patterns

**Over-engineering for hypothetical scale.** Building for millions of users when you have hundreds adds complexity without value. Solve today's problems first.

**Ignoring the existing ecosystem.** Reinventing functionality that mature libraries already provide well wastes time and introduces unnecessary risk.

**Premature abstraction.** Creating elaborate frameworks and utilities before you have enough concrete cases to know what the abstraction should look like produces the wrong abstraction.

**Neglecting error handling at boundaries.** Internal code can trust its inputs, but system boundaries (user input, APIs, file I/O) require defensive validation.

**Skipping documentation for obvious code.** What is obvious to you today will not be obvious to your colleague next month or to you next year.
