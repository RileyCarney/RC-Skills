# Django ORM — Python Web Development

You are an expert in Django's ORM for modeling data, writing efficient queries, and managing database schemas.

## Core Philosophy

### Overview

Django's ORM provides a Pythonic abstraction over relational databases. It handles model definitions, query construction, migrations, and relationship management while supporting PostgreSQL, MySQL, SQLite, and Oracle.

## Setup & Configuration

Database configuration lives in `settings.py`:

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "mydb",
        "USER": "myuser",
        "PASSWORD": "mypassword",
        "HOST": "localhost",
        "PORT": "5432",
        "CONN_MAX_AGE": 600,
        "OPTIONS": {
            "connect_timeout": 10,
        },
    }
}
```

For multiple databases, define a database router:

```python
class PrimaryReplicaRouter:
    def db_for_read(self, model, **hints):
        return "replica"

    def db_for_write(self, model, **hints):
        return "default"
```

## Core Patterns

### Model Definition

```python
from django.db import models
from django.utils import timezone


class Article(models.Model):
    title = models.CharField(max_length=200, db_index=True)
    slug = models.SlugField(max_length=200, unique=True)
    body = models.TextField()
    author = models.ForeignKey(
        "auth.User",
        on_delete=models.CASCADE,
        related_name="articles",
    )
    tags = models.ManyToManyField("Tag", blank=True, related_name="articles")
    published_at = models.DateTimeField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-published_at"]
        indexes = [
            models.Index(fields=["author", "-published_at"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["author", "slug"],
                name="unique_author_slug",
            ),
        ]

    def __str__(self):
        return self.title

    def publish(self):
        self.published_at = timezone.now()
        self.save(update_fields=["published_at", "updated_at"])
```

### QuerySet Optimization

```python
# select_related for ForeignKey (JOIN)
articles = Article.objects.select_related("author").all()

# prefetch_related for ManyToMany or reverse FK (separate query)
articles = Article.objects.prefetch_related("tags").all()

# Combine both
articles = (
    Article.objects
    .select_related("author")
    .prefetch_related("tags")
    .filter(published_at__isnull=False)
)

# Custom Prefetch object for filtered prefetching
from django.db.models import Prefetch

articles = Article.objects.prefetch_related(
    Prefetch(
        "comments",
        queryset=Comment.objects.filter(approved=True).select_related("user"),
        to_attr="approved_comments",
    )
)
```

### Aggregation and Annotation

```python
from django.db.models import Count, Avg, Q, F, Value
from django.db.models.functions import Coalesce

# Annotate each author with their article count
authors = (
    User.objects
    .annotate(article_count=Count("articles"))
    .filter(article_count__gt=5)
    .order_by("-article_count")
)

# Conditional aggregation
stats = Article.objects.aggregate(
    total=Count("id"),
    published=Count("id", filter=Q(published_at__isnull=False)),
    avg_comments=Avg("comment_count"),
)

# F expressions for database-level field references
Article.objects.filter(updated_at__gt=F("published_at"))

# Bulk update with F expression
Article.objects.filter(status="draft").update(views=F("views") + 1)
```

### Custom Managers and QuerySets

```python
class ArticleQuerySet(models.QuerySet):
    def published(self):
        return self.filter(published_at__isnull=False)

    def by_author(self, user):
        return self.filter(author=user)

    def with_comment_count(self):
        return self.annotate(comment_count=Count("comments"))


class ArticleManager(models.Manager):
    def get_queryset(self):
        return ArticleQuerySet(self.model, using=self._db)

    def published(self):
        return self.get_queryset().published()


class Article(models.Model):
    # ...
    objects = ArticleManager()
```

### Migrations

```bash
# Create migrations after model changes
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Show migration SQL without applying
python manage.py sqlmigrate app_name 0001

# Data migration
python manage.py makemigrations --empty app_name -n populate_slugs
```

```python
# Data migration example
from django.db import migrations
from django.utils.text import slugify


def populate_slugs(apps, schema_editor):
    Article = apps.get_model("blog", "Article")
    for article in Article.objects.filter(slug=""):
        article.slug = slugify(article.title)
        article.save(update_fields=["slug"])


class Migration(migrations.Migration):
    dependencies = [("blog", "0002_article_slug")]
    operations = [
        migrations.RunPython(populate_slugs, migrations.RunPython.noop),
    ]
```

### Raw SQL and Database Functions

```python
# Raw queries when the ORM is insufficient
articles = Article.objects.raw(
    "SELECT * FROM blog_article WHERE tsv @@ plainto_tsquery(%s)",
    [search_term],
)

# Database functions
from django.db.models.functions import Lower, Length, TruncMonth

Article.objects.annotate(
    title_lower=Lower("title"),
    title_length=Length("title"),
    pub_month=TruncMonth("published_at"),
)
```

## Best Practices

- Always use `select_related` and `prefetch_related` to avoid N+1 queries. Use `django-debug-toolbar` or `nplusone` to detect them during development.
- Use `update_fields` in `.save()` calls to avoid race conditions and reduce the data written.
- Use `bulk_create` and `bulk_update` for batch operations instead of looping `.save()`.
- Define `indexes` and `constraints` in `Meta` rather than relying only on `db_index=True` on individual fields.
- Write data migrations as separate migration files, not inline with schema migrations.
- Use `iterator()` for large querysets that do not need caching: `Article.objects.all().iterator(chunk_size=2000)`.
- Use `Exists` subqueries instead of `.count()` or `.filter(...).exists()` in annotations.

## Common Pitfalls

- Evaluating querysets too early. Assigning `list(qs)` or iterating in a template forces evaluation; keep querysets lazy until the last moment.
- Forgetting that `.all()` returns a new queryset but does not clone cached results. Each evaluation hits the database.
- Using `auto_now=True` on `updated_at` makes it impossible to set the field manually. Use a `pre_save` signal or override `save()` if manual control is needed.
- Ignoring `on_delete` semantics. Using `CASCADE` when `SET_NULL` or `PROTECT` is more appropriate can silently destroy data.
- Running schema migrations on large tables without a plan. Use `AddIndex(concurrently=True)` on PostgreSQL and schedule migrations during low-traffic windows.
- Accessing related objects inside loops without prefetching, causing hundreds of extra queries.
## Anti-Patterns

**Over-engineering for hypothetical scale.** Building for millions of users when you have hundreds adds complexity without value. Solve today's problems first.

**Ignoring the existing ecosystem.** Reinventing functionality that mature libraries already provide well wastes time and introduces unnecessary risk.

**Premature abstraction.** Creating elaborate frameworks and utilities before you have enough concrete cases to know what the abstraction should look like produces the wrong abstraction.

**Neglecting error handling at boundaries.** Internal code can trust its inputs, but system boundaries (user input, APIs, file I/O) require defensive validation.

**Skipping documentation for obvious code.** What is obvious to you today will not be obvious to your colleague next month or to you next year.
