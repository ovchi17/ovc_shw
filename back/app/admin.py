from __future__ import annotations
import json
from markupsafe import Markup
from sqlalchemy import select
from sqladmin import Admin, ModelView
from sqladmin.authentication import AuthenticationBackend
from sqlalchemy.orm import joinedload
from starlette.requests import Request
from starlette.responses import RedirectResponse
from app.core.config import settings
from app.models.user import User
from app.models.recording import Recording, AnalysisResult, AnalysisModuleResult, Task
from app.models.recommendation import Recommendation


class AdminAuth(AuthenticationBackend):
    async def login(self, request: Request) -> bool:
        form = await request.form()
        ok = (
            form.get("username") == settings.admin_username
            and form.get("password") == settings.admin_password
        )
        if ok:
            request.session["authenticated"] = True
        return ok

    async def logout(self, request: Request) -> bool:
        request.session.clear()
        return True

    async def authenticate(self, request: Request) -> bool:
        return request.session.get("authenticated") is True


STATUS_COLOR = {
    "done": "success",
    "processing": "warning",
    "transcribing": "warning",
    "analyzing": "warning",
    "enhancing": "warning",
    "queued": "secondary",
    "error": "danger",
    "failed": "danger",
    "upload": "info",
    "record": "primary",
}

STATUS_LABEL = {
    "done": "Готово",
    "processing": "Обработка",
    "transcribing": "Транскрипция",
    "analyzing": "Анализ",
    "enhancing": "Шумоподавление",
    "queued": "В очереди",
    "error": "Ошибка",
    "failed": "Ошибка",
    "upload": "Загрузка",
    "record": "Запись",
}

MODULE_LABEL = {
    "parasites": "Слова-паразиты",
    "pauses": "Паузы",
    "tempo": "Темп",
    "lexical": "Лексика",
    "syntax": "Синтаксис",
}


def badge(value: str | None) -> Markup:
    if not value:
        return Markup('<span class="text-muted">—</span>')
    color = STATUS_COLOR.get(value, "secondary")
    label = STATUS_LABEL.get(value, value)
    return Markup(f'<span class="badge bg-{color}-lt text-{color}">{label}</span>')


def score(value: int | None) -> Markup:
    if value is None:
        return Markup('<span class="text-muted">—</span>')
    if value >= 75:
        color, icon = "#22c55e", "+"
    elif value >= 50:
        color, icon = "#f59e0b", "~"
    else:
        color, icon = "#ef4444", "-"
    bar = round(value / 100 * 64)
    return Markup(
        f'<div class="d-flex align-items-center gap-2">'
        f'  <div style="width:64px;height:6px;background:#e2e8f0;border-radius:3px;overflow:hidden">'
        f'    <div style="width:{bar}px;height:100%;background:{color};border-radius:3px"></div>'
        f'  </div>'
        f'  <span style="color:{color};font-weight:600;font-size:.85rem">{icon} {value}</span>'
        f'</div>'
    )


def duration(sec: float | None) -> Markup:
    if sec is None:
        return Markup('<span class="text-muted">—</span>')
    m, s = int(sec) // 60, int(sec) % 60
    return Markup(f'<span class="text-secondary">{m}:{s:02d}</span>')


def module_badge(value: str | None) -> Markup:
    if not value:
        return Markup('<span class="text-muted">—</span>')
    label = MODULE_LABEL.get(value, value)
    return Markup(f'<strong>{label}</strong>')


def progress_bar(pct: int | None) -> Markup:
    if pct is None:
        return Markup('<span class="text-muted">—</span>')
    color = "success" if pct == 100 else "primary"
    return Markup(
        f'<div class="d-flex align-items-center gap-2">'
        f'  <div class="progress flex-grow-1" style="height:8px;max-width:80px">'
        f'    <div class="progress-bar bg-{color}" style="width:{pct}%"></div>'
        f'  </div>'
        f'  <small class="text-muted">{pct}%</small>'
        f'</div>'
    )


def count_badge(n: int, color: str = "blue") -> Markup:
    return Markup(f'<span class="badge bg-{color}-lt text-{color}">{n}</span>')


def email_link(email: str | None) -> Markup:
    if not email:
        return Markup('<span class="text-muted">—</span>')
    return Markup(f'<a href="mailto:{email}" class="text-muted">{email}</a>')


def expandable_text(text: str | None, preview: int = 120) -> Markup:
    if not text:
        return Markup('<span class="text-muted">—</span>')
    esc_full = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    if len(text) <= preview:
        return Markup(f'<span class="small">{esc_full}</span>')
    esc_short = esc_full[:preview]
    uid = abs(hash(text[:60])) % 9999999
    return Markup(
        f'<div>'
        f'<span class="text-muted small">{esc_short}…</span> '
        f'<a class="small link-secondary" data-bs-toggle="collapse" href="#exp-{uid}" role="button">'
        f'Развернуть</a>'
        f'<div class="collapse mt-1" id="exp-{uid}">'
        f'<pre style="white-space:pre-wrap;font-size:.75rem;background:#f8fafc;'
        f'padding:8px;border-radius:4px;max-height:400px;overflow:auto">{esc_full}</pre>'
        f'</div>'
        f'</div>'
    )


def expandable_json(data: dict | list | None) -> Markup:
    if not data:
        return Markup('<span class="text-muted">—</span>')
    try:
        pretty = json.dumps(data, ensure_ascii=False, indent=2)
    except Exception:
        pretty = str(data)
    return expandable_text(pretty, preview=100)


def render_details_json(data: dict | None) -> Markup:
    if not data:
        return Markup('<span class="text-muted">—</span>')

    skip = {
        "score", "details", "filler_timecodes", "personal_fillers",
        "top_fillers_overall", "medium_pause_timecodes", "long_pause_timecodes",
        "top_lemmas",
    }

    rows = []
    for k, v in data.items():
        if k in skip:
            continue
        if isinstance(v, float):
            v = f"{v:.2f}"
        elif isinstance(v, bool):
            v = "да" if v else "нет"
        rows.append(
            f"<tr>"
            f"<td class='text-muted small pe-3' style='white-space:nowrap'>{k}</td>"
            f"<td class='fw-medium small'>{v}</td>"
            f"</tr>"
        )

    table = (
        '<table class="table table-sm table-borderless mb-0" style="max-width:460px">'
        "<tbody>" + "".join(rows) + "</tbody></table>"
    )

    extra = ""
    top = data.get("top_fillers_overall") or []
    if isinstance(top, list) and top:
        items = ", ".join(f'&laquo;{i["word"]}&raquo;&nbsp;x{i["count"]}' for i in top[:5])
        extra += f'<div class="mt-2 small text-muted"><strong>Топ паразиты:</strong> {items}</div>'

    personal = data.get("personal_fillers") or []
    if isinstance(personal, list) and personal:
        items = ", ".join(f'&laquo;{i["word"]}&raquo;&nbsp;x{i["count"]}' for i in personal[:5])
        extra += f'<div class="mt-1 small text-muted"><strong>Личные паразиты:</strong> {items}</div>'

    lemmas = data.get("top_lemmas") or []
    if isinstance(lemmas, list) and lemmas:
        items = ", ".join(f'&laquo;{w}&raquo;&nbsp;x{c}' for w, c in lemmas[:8])
        extra += f'<div class="mt-1 small text-muted"><strong>Топ леммы:</strong> {items}</div>'

    return Markup(
        f'<div style="background:#f8fafc;border-radius:6px;padding:10px">'
        f'{table}{extra}'
        f'</div>'
    )


def error_cell(text: str | None) -> Markup:
    if not text:
        return Markup('<span class="text-muted">—</span>')
    short = text[:80] + ("…" if len(text) > 80 else "")
    safe = text.replace('"', "&quot;")
    return Markup(f'<span class="text-danger small" title="{safe}">{short}</span>')



class UserAdmin(ModelView, model=User):
    name = "Пользователь"
    name_plural = "Пользователи"

    page_size = 30
    page_size_options = [20, 30, 50, 100]

    column_list = [
        User.id,
        User.name,
        User.email,
        User.custom_fillers,
        User.created_at,
    ]

    column_labels = {
        User.id: "#",
        User.name: "Имя",
        User.email: "Email",
        User.custom_fillers: "Свои паразиты",
        User.created_at: "Дата регистрации",
    }

    column_formatters = {
        User.email: lambda m, a: email_link(m.email),
        User.custom_fillers: lambda m, a: expandable_text(m.custom_fillers, preview=60),
    }

    column_searchable_list = [User.name, User.email]
    column_sortable_list = [User.id, User.name, User.created_at]
    column_default_sort = [(User.created_at, True)]
    column_details_list = [
        User.id,
        User.name,
        User.email,
        User.custom_fillers,
        User.created_at,
    ]

    column_details_labels = {
        User.id: "#",
        User.name: "Имя",
        User.email: "Email",
        User.custom_fillers: "Свои паразиты (JSON)",
        User.created_at: "Дата регистрации",
    }

    column_details_formatters = {
        User.email: lambda m, a: email_link(m.email),
        User.custom_fillers: lambda m, a: expandable_text(m.custom_fillers),
    }

    form_excluded_columns = [User.password_hash, User.recordings]
    can_create = False
    can_edit = True
    can_delete = True


class RecordingAdmin(ModelView, model=Recording):
    name = "Запись"
    name_plural = "Записи"

    page_size = 30
    page_size_options = [20, 30, 50, 100]

    column_list = [
        Recording.id,
        Recording.user_id,
        "user.name",
        Recording.filename,
        Recording.file_path,
        Recording.duration_sec,
        Recording.status,
        "analysis.total_score",
        Recording.created_at,
    ]

    column_labels = {
        Recording.id: "#",
        "user.name": "Пользователь",
        Recording.filename: "Имя файла",
        Recording.file_path: "Путь к файлу",
        Recording.duration_sec: "Длительность",
        Recording.status: "Статус",
        "analysis.total_score": "Итоговый балл",
        Recording.user_id: "ID пользователя",
        Recording.created_at: "Дата загрузки",
    }

    column_formatters = {
        Recording.status: lambda m, a: badge(m.status),
        Recording.duration_sec: lambda m, a: duration(m.duration_sec),
        "analysis.total_score": lambda m, a: score(
            m.analysis.total_score if m.analysis else None
        ),
        Recording.file_path: lambda m, a: Markup(
            f'<span class="text-muted small" title="{(m.file_path or "").replace(chr(34), "&quot;")}">'
            f'{(m.file_path or "—")[-45:]}'
            f'</span>'
        ) if m.file_path else Markup('<span class="text-muted">—</span>'),
    }

    column_searchable_list = [Recording.filename, "user.name"]
    column_sortable_list = [Recording.id, Recording.duration_sec, Recording.created_at, "user.name"]
    column_default_sort = [(Recording.created_at, True)]

    column_details_list = [
        Recording.id,
        Recording.user_id,
        "user.name",
        Recording.filename,
        Recording.file_path,
        Recording.duration_sec,
        Recording.status,
        "analysis.total_score",
        Recording.created_at,
    ]

    column_details_labels = {
        Recording.id: "#",
        Recording.user_id: "ID пользователя",
        "user.name": "Пользователь",
        Recording.filename: "Имя файла",
        Recording.file_path: "Путь к файлу",
        Recording.duration_sec: "Длительность",
        Recording.status: "Статус",
        "analysis.total_score": "Итоговый балл",
        Recording.created_at: "Дата загрузки",
    }

    column_details_formatters = {
        Recording.status: lambda m, a: badge(m.status),
        Recording.duration_sec: lambda m, a: duration(m.duration_sec),
        "analysis.total_score": lambda m, a: score(
            m.analysis.total_score if m.analysis else None
        ),
        Recording.file_path: lambda m, a: expandable_text(m.file_path),
    }

    async def scaffold_list(self, request: Request, **kwargs):
        stmt = select(self.model).options(
            joinedload(Recording.user),
            joinedload(Recording.analysis),
        )
        return await super().scaffold_list(request, _stmt=stmt, **kwargs)

    form_excluded_columns = [Recording.user, Recording.analysis]
    can_create = False
    can_edit = False
    can_delete = True



class AnalysisResultAdmin(ModelView, model=AnalysisResult):
    name = "Результат анализа"
    name_plural = "Результаты анализа"

    page_size = 30
    page_size_options = [20, 30, 50, 100]

    column_list = [
        AnalysisResult.id,
        AnalysisResult.recording_id,
        "recording.filename",
        AnalysisResult.total_score,
        "score_parasites",
        "score_pauses",
        "score_tempo",
        "score_lexical",
        "score_syntax",
        AnalysisResult.analyzed_at,
    ]

    column_labels = {
        AnalysisResult.id: "#",
        AnalysisResult.recording_id: "ID записи",
        "recording.filename": "Файл записи",
        AnalysisResult.total_score: "Итоговый балл",
        "score_parasites": "Слова-паразиты",
        "score_pauses": "Паузы",
        "score_tempo": "Темп",
        "score_lexical": "Лексика",
        "score_syntax": "Синтаксис",
        AnalysisResult.timecodes: "Таймкоды",
        AnalysisResult.transcript: "Транскрипт",
        AnalysisResult.analyzed_at: "Время анализа",
    }

    column_formatters = {
        AnalysisResult.total_score: lambda m, a: score(m.total_score),
        "score_parasites": lambda m, a: score(m.score_parasites),
        "score_pauses": lambda m, a: score(m.score_pauses),
        "score_tempo": lambda m, a: score(m.score_tempo),
        "score_lexical": lambda m, a: score(m.score_lexical),
        "score_syntax": lambda m, a: score(m.score_syntax),
        "recording.filename": lambda m, a: Markup(
            f'<span class="text-muted small">'
            f'{m.recording.filename[:40] if m.recording else str(m.recording_id)}'
            f'</span>'
        ),
    }

    column_sortable_list = [
        AnalysisResult.id,
        AnalysisResult.recording_id,
        AnalysisResult.total_score,
        AnalysisResult.analyzed_at,
    ]
    column_default_sort = [(AnalysisResult.analyzed_at, True)]
    column_searchable_list = [AnalysisResult.transcript, "recording.filename"]

    column_details_list = [
        AnalysisResult.id,
        AnalysisResult.recording_id,
        "recording.filename",
        AnalysisResult.total_score,
        "score_parasites",
        "score_pauses",
        "score_tempo",
        "score_lexical",
        "score_syntax",
        AnalysisResult.timecodes,
        AnalysisResult.transcript,
        AnalysisResult.analyzed_at,
    ]

    column_details_labels = {
        AnalysisResult.id: "#",
        AnalysisResult.recording_id: "ID записи",
        "recording.filename": "Файл записи",
        AnalysisResult.total_score: "Итоговый балл",
        "score_parasites": "Слова-паразиты",
        "score_pauses": "Паузы",
        "score_tempo": "Темп",
        "score_lexical": "Лексика",
        "score_syntax": "Синтаксис",
        AnalysisResult.timecodes: "Таймкоды (JSON)",
        AnalysisResult.transcript: "Транскрипт",
        AnalysisResult.analyzed_at: "Время анализа",
    }

    column_details_formatters = {
        AnalysisResult.total_score: lambda m, a: score(m.total_score),
        "score_parasites": lambda m, a: score(m.score_parasites),
        "score_pauses": lambda m, a: score(m.score_pauses),
        "score_tempo": lambda m, a: score(m.score_tempo),
        "score_lexical": lambda m, a: score(m.score_lexical),
        "score_syntax": lambda m, a: score(m.score_syntax),
        "recording.filename": lambda m, a: Markup(
            f'<span class="fw-medium">'
            f'{m.recording.filename if m.recording else str(m.recording_id)}'
            f'</span>'
        ),
        AnalysisResult.timecodes: lambda m, a: expandable_json(m.timecodes),
        AnalysisResult.transcript: lambda m, a: expandable_text(m.transcript, preview=200),
    }

    form_excluded_columns = [AnalysisResult.recording, AnalysisResult.modules]
    can_create = False
    can_edit = False
    can_delete = True

    def list_query(self, request):
        return select(self.model).options(joinedload(self.model.recording))

    def details_query(self, request):
        return select(self.model).options(joinedload(self.model.recording))


class AnalysisModuleAdmin(ModelView, model=AnalysisModuleResult):
    name = "Модуль анализа"
    name_plural = "Модули анализа"

    page_size = 50
    page_size_options = [30, 50, 100]

    column_list = [
        AnalysisModuleResult.id,
        AnalysisModuleResult.analysis_id,
        AnalysisModuleResult.module,
        AnalysisModuleResult.score,
        "details_preview",
    ]

    column_labels = {
        AnalysisModuleResult.id: "#",
        AnalysisModuleResult.analysis_id: "ID анализа",
        AnalysisModuleResult.module: "Модуль",
        AnalysisModuleResult.score: "Балл",
        "details_preview": "Метрики",
    }

    column_formatters = {
        AnalysisModuleResult.module: lambda m, a: module_badge(m.module),
        AnalysisModuleResult.score: lambda m, a: score(m.score),
        "details_preview": lambda m, a: render_details_json(m.details),
    }

    column_sortable_list = [
        AnalysisModuleResult.id,
        AnalysisModuleResult.analysis_id,
        AnalysisModuleResult.score,
    ]
    column_default_sort = [(AnalysisModuleResult.analysis_id, True)]

    column_details_list = [
        AnalysisModuleResult.id,
        AnalysisModuleResult.analysis_id,
        AnalysisModuleResult.module,
        AnalysisModuleResult.score,
        "details_preview",
    ]

    column_details_labels = {
        AnalysisModuleResult.id: "#",
        AnalysisModuleResult.analysis_id: "ID анализа",
        AnalysisModuleResult.module: "Модуль",
        AnalysisModuleResult.score: "Балл",
        "details_preview": "Детальные метрики",
    }

    column_details_formatters = {
        AnalysisModuleResult.module: lambda m, a: module_badge(m.module),
        AnalysisModuleResult.score: lambda m, a: score(m.score),
        "details_preview": lambda m, a: render_details_json(m.details),
    }

    form_excluded_columns = [AnalysisModuleResult.analysis]
    can_create = False
    can_edit = False
    can_delete = False



class TaskAdmin(ModelView, model=Task):
    name = "Задача"
    name_plural = "Фоновые задачи"

    page_size = 30
    page_size_options = [20, 30, 50, 100]

    column_list = [
        Task.task_id,
        Task.recording_id,
        Task.status,
        Task.progress_pct,
        Task.message,
        Task.analysis_id,
        Task.error,
    ]

    column_labels = {
        Task.task_id: "UUID задачи",
        Task.recording_id: "ID записи",
        Task.status: "Статус",
        Task.progress_pct: "Прогресс",
        Task.message: "Сообщение",
        Task.error: "Ошибка",
        Task.analysis_id: "ID анализа",
    }

    column_formatters = {
        Task.status: lambda m, a: badge(m.status),
        Task.progress_pct: lambda m, a: progress_bar(m.progress_pct),
        Task.error: lambda m, a: error_cell(m.error),
    }

    column_details_list = [
        Task.task_id,
        Task.recording_id,
        Task.status,
        Task.progress_pct,
        Task.message,
        Task.analysis_id,
        Task.error,
    ]

    column_details_labels = {
        Task.task_id: "UUID задачи",
        Task.recording_id: "ID записи",
        Task.status: "Статус",
        Task.progress_pct: "Прогресс (%)",
        Task.message: "Сообщение",
        Task.analysis_id: "ID анализа",
        Task.error: "Текст ошибки",
    }

    column_details_formatters = {
        Task.status: lambda m, a: badge(m.status),
        Task.progress_pct: lambda m, a: progress_bar(m.progress_pct),
        Task.error: lambda m, a: expandable_text(m.error),
    }

    column_searchable_list = [Task.task_id, Task.status]
    column_sortable_list = [Task.recording_id, Task.progress_pct]
    column_default_sort = [(Task.task_id, True)]

    can_create = False
    can_edit = False
    can_delete = True


CATEGORY_LABEL = {
    "parasites": "Слова-паразиты",
    "pauses":    "Паузы",
    "tempo":     "Темп",
    "lexical":   "Лексика",
    "syntax":    "Синтаксис",
}

CATEGORY_COLOR = {
    "parasites": "red",
    "pauses":    "orange",
    "tempo":     "yellow",
    "lexical":   "green",
    "syntax":    "blue",
}


def category_badge(value: str | None) -> Markup:
    if not value:
        return Markup('<span class="text-muted">—</span>')
    color = CATEGORY_COLOR.get(value, "secondary")
    label = CATEGORY_LABEL.get(value, value)
    return Markup(f'<span class="badge bg-{color}-lt text-{color}">{label}</span>')


class RecommendationAdmin(ModelView, model=Recommendation):
    name = "Упражнение"
    name_plural = "Упражнения и советы"

    page_size = 30
    page_size_options = [20, 30, 50, 100]

    column_list = [
        Recommendation.id,
        Recommendation.category,
        Recommendation.title,
        Recommendation.body,
        Recommendation.source,
    ]

    column_labels = {
        Recommendation.id: "#",
        Recommendation.category: "Категория",
        Recommendation.title: "Заголовок",
        Recommendation.body: "Содержание",
        Recommendation.source: "Источник",
    }

    column_formatters = {
        Recommendation.category: lambda m, a: category_badge(m.category),
        Recommendation.body: lambda m, a: expandable_text(m.body, preview=120),
        Recommendation.source: lambda m, a: expandable_text(m.source, preview=80),
    }

    column_searchable_list = [Recommendation.title, Recommendation.body, Recommendation.category]
    column_sortable_list = [Recommendation.id, Recommendation.category, Recommendation.title]
    column_default_sort = [(Recommendation.category, False), (Recommendation.id, False)]

    column_details_list = [
        Recommendation.id,
        Recommendation.category,
        Recommendation.title,
        Recommendation.body,
        Recommendation.source,
    ]

    column_details_labels = {
        Recommendation.id: "#",
        Recommendation.category: "Категория",
        Recommendation.title: "Заголовок",
        Recommendation.body: "Содержание",
        Recommendation.source: "Источник",
    }

    column_details_formatters = {
        Recommendation.category: lambda m, a: category_badge(m.category),
        Recommendation.body: lambda m, a: expandable_text(m.body, preview=400),
        Recommendation.source: lambda m, a: expandable_text(m.source, preview=200),
    }

    form_columns = [
        Recommendation.category,
        Recommendation.title,
        Recommendation.body,
        Recommendation.source,
    ]

    can_create = True
    can_edit = True
    can_delete = True


class Admin(Admin):
    async def index(self, request: Request):
        return RedirectResponse(url=request.url_for("admin:list", identity="user"))


def create_admin(app, engine) -> Admin:
    auth = AdminAuth(secret_key=settings.secret_key)
    admin = Admin(
        app=app,
        engine=engine,
        authentication_backend=auth,
        title="Clarity Admin",
        base_url="/admin",
        templates_dir="app/templates",
    )
    admin.add_view(UserAdmin)
    admin.add_view(RecordingAdmin)
    admin.add_view(AnalysisResultAdmin)
    admin.add_view(AnalysisModuleAdmin)
    admin.add_view(TaskAdmin)
    admin.add_view(RecommendationAdmin)
    return admin
