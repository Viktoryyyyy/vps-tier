import json
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, CallbackQueryHandler, ContextTypes
import config

SOT_PATH = Path("/opt/tg_bot/sot/users.json")

INVITE_TEXT = "Доступ предоставляется по приглашению"
INCOMPLETE_TEXT = "Доступ создан не полностью. Напишите администратору."

IOS_LINK = "https://apps.apple.com/app/id6446814690"
ANDROID_RELEASES = "https://github.com/2dust/v2rayNG/releases/latest"
WINDOWS_LINK = "https://github.com/2dust/v2rayN/releases"
MACOS_LINK = "https://github.com/Cenmrev/V2RayX/releases/latest"

def _load_json(path: Path) -> object:
    if not path.exists():
        return {"users": []}
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"users": []}

def _save_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    tmp.replace(path)

def load_sot() -> dict:
    raw = _load_json(SOT_PATH)
    if isinstance(raw, list):
        return {"users": raw}
    if isinstance(raw, dict):
        if "users" in raw and isinstance(raw["users"], list):
            return raw
        if all(isinstance(k, str) and isinstance(v, dict) for k, v in raw.items()):
            users = []
            for k, v in raw.items():
                u = dict(v)
                u.setdefault("tg_id", k)
                users.append(u)
            return {"users": users}
    return {"users": []}

def get_user(data: dict, tg_id: str) -> dict | None:
    for u in data.get("users", []):
        if str(u.get("tg_id")) == tg_id:
            return u
    return None

def is_allowed(user: dict | None) -> bool:
    return bool(user) and str(user.get("status")) == "active"

def has_subscription(user: dict) -> bool:
    sub_url = user.get("sub_url")
    return isinstance(sub_url, str) and sub_url.strip() != ""

def main_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("Статус подписки", callback_data="status")],
        [InlineKeyboardButton("Инструкции", callback_data="os_menu")],
        [InlineKeyboardButton("Не работает", callback_data="not_working")],
    ])

def os_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("iOS", callback_data="os_ios")],
        [InlineKeyboardButton("Android", callback_data="os_android")],
        [InlineKeyboardButton("Windows", callback_data="os_windows")],
        [InlineKeyboardButton("macOS", callback_data="os_macos")],
        [InlineKeyboardButton("Назад", callback_data="back")],
    ])

def instructions(platform: str) -> str:
    if platform == "ios":
        return (
            "📱 iOS\n"
            "Клиент: V2Box\n"
            f"{IOS_LINK}\n\n"
            "1) В боте откройте «Статус подписки» и скопируйте Subscription URL.\n"
            "2) В V2Box выберите Import from URL и вставьте ссылку.\n"
            "3) Нажмите Refresh.\n"
        )
    if platform == "android":
        return (
            "🤖 Android\n"
            "Клиент: v2rayNG\n"
            f"{ANDROID_RELEASES}\n\n"
            "1) Установите приложение.\n"
            "2) В боте откройте «Статус подписки» и скопируйте Subscription URL.\n"
            "3) В v2rayNG нажмите + → Import config from clipboard/URL.\n"
            "4) Обновите подписку и включите.\n"
        )
    if platform == "windows":
        return (
            "🖥 Windows\n"
            "Клиент: v2rayN\n"
            f"{WINDOWS_LINK}\n\n"
            "1) Скачайте архив и распакуйте.\n"
            "2) Запустите v2rayN.\n"
            "3) В боте откройте «Статус подписки» и скопируйте Subscription URL.\n"
            "4) Subscription → Subscribe from clipboard/URL.\n"
            "5) Update subscriptions и включите сервер.\n"
        )
    return (
        "💻 macOS\n"
        "Клиент: V2RayX\n"
        f"{MACOS_LINK}\n\n"
        "1) Скачайте .dmg и установите приложение.\n"
        "2) В боте откройте «Статус подписки» и скопируйте Subscription URL.\n"
        "3) Import from URL.\n"
        "4) Обновите и включите профиль.\n"
    )

def status_text(user: dict) -> str:
    sub_url = user.get("sub_url") or ""
    return "Статус: active\nSubscription URL:\n" + str(sub_url)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    tg_id = str(update.effective_user.id)
    data = load_sot()
    user = get_user(data, tg_id)

    if not is_allowed(user):
        await update.message.reply_text(INVITE_TEXT)
        return

    if not has_subscription(user):
        await update.message.reply_text(INCOMPLETE_TEXT)
        return

    await update.message.reply_text("Ferry VPN\n\nВыберите действие:", reply_markup=main_kb())

async def on_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    tg_id = str(query.from_user.id)

    data = load_sot()
    user = get_user(data, tg_id)

    if not is_allowed(user):
        await query.edit_message_text(INVITE_TEXT)
        return

    if not has_subscription(user):
        await query.edit_message_text(INCOMPLETE_TEXT)
        return

    if query.data == "back":
        await query.edit_message_text("Ferry VPN\n\nВыберите действие:", reply_markup=main_kb())
        return

    if query.data == "status":
        await query.edit_message_text(status_text(user), reply_markup=main_kb())
        return

    if query.data == "os_menu":
        await query.edit_message_text("Выберите вашу ОС:", reply_markup=os_kb())
        return

    if query.data.startswith("os_"):
        await query.edit_message_text(instructions(query.data.split("_", 1)[1]), reply_markup=os_kb())
        return

    if query.data == "not_working":
        await query.edit_message_text("Опишите проблему администратору.", reply_markup=main_kb())
        return

    await query.edit_message_text("Команда не распознана.", reply_markup=main_kb())

if __name__ == "__main__":
    app = ApplicationBuilder().token(config.BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(on_button))
    app.run_polling()
