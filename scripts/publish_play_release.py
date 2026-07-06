from __future__ import annotations

import argparse
import os
import random
import re
import sys
import time
from pathlib import Path

import google.auth
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload


SCOPES = ("https://www.googleapis.com/auth/androidpublisher",)
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_AAB_PATH = REPO_ROOT / "lotofacil_app" / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
DEFAULT_PUBSPEC_PATH = REPO_ROOT / "lotofacil_app" / "pubspec.yaml"
DEFAULT_GRADLE_PATH = REPO_ROOT / "lotofacil_app" / "android" / "app" / "build.gradle.kts"


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _parse_pubspec_version(pubspec_path: Path) -> str | None:
    if not pubspec_path.exists():
        return None
    match = re.search(r"^version:\s*([^\s]+)\s*$", _read_text(pubspec_path), flags=re.MULTILINE)
    return match.group(1).strip() if match else None


def _parse_application_id(gradle_path: Path) -> str | None:
    if not gradle_path.exists():
        return None
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', _read_text(gradle_path))
    return match.group(1).strip() if match else None


def _load_release_notes(path: Path | None, language: str) -> list[dict[str, str]]:
    if path is None:
        return []
    notes = _read_text(path).strip()
    if not notes:
        raise ValueError(f"Arquivo de release notes vazio: {path}")
    return [{"language": language, "text": notes}]


def _resolve_existing_file(path_str: str, description: str) -> Path:
    path = Path(path_str).expanduser()
    if not path.is_absolute():
        path = REPO_ROOT / path
    path = path.resolve()
    if not path.exists():
        raise FileNotFoundError(f"{description} nao encontrado: {path}")
    return path


def _is_transient_error(exc: Exception) -> bool:
    if isinstance(exc, HttpError):
        status = exc.resp.status if exc.resp is not None else None
        return status in {408, 409, 429, 500, 502, 503, 504}

    message = str(exc).lower()
    transient_markers = (
        "timed out",
        "timeout",
        "connection reset",
        "connection aborted",
        "temporarily unavailable",
        "broken pipe",
    )
    return any(marker in message for marker in transient_markers)


def _execute_with_retry(label: str, operation, retries: int) -> dict:
    attempt = 0
    while True:
        attempt += 1
        try:
            return operation()
        except Exception as exc:
            if attempt > retries or not _is_transient_error(exc):
                raise

            # Backoff exponencial com jitter reduz falhas transitórias em upload e commit.
            delay = (2 ** (attempt - 1)) + random.uniform(0.0, 0.5)
            print(f"{label} falhou na tentativa {attempt}/{retries + 1}. Tentando novamente em {delay:.1f}s...")
            time.sleep(delay)


def parse_args() -> argparse.Namespace:
    detected_package_name = _parse_application_id(DEFAULT_GRADLE_PATH)
    detected_release_name = _parse_pubspec_version(DEFAULT_PUBSPEC_PATH)

    parser = argparse.ArgumentParser(
        description="Publica um AAB no Google Play Console usando a Android Publisher API.",
    )
    parser.add_argument(
        "--service-account-json",
        default=os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"),
        help="Caminho para o JSON da service account com acesso ao app no Play Console.",
    )
    parser.add_argument(
        "--package-name",
        default=os.getenv("GOOGLE_PLAY_PACKAGE_NAME") or detected_package_name,
        help="Application ID do app Android, por exemplo com.leonerdi.lotosmart.",
    )
    parser.add_argument(
        "--aab",
        default=os.getenv("GOOGLE_PLAY_AAB") or str(DEFAULT_AAB_PATH),
        help="Caminho para o arquivo .aab que sera enviado.",
    )
    parser.add_argument(
        "--track",
        default=os.getenv("GOOGLE_PLAY_TRACK", "internal"),
        choices=["internal", "alpha", "beta", "production"],
        help="Track do Play Console que recebera a release.",
    )
    parser.add_argument(
        "--release-status",
        default=os.getenv("GOOGLE_PLAY_RELEASE_STATUS", "completed"),
        choices=["draft", "completed", "halted", "inProgress"],
        help="Status da release ao publicar na track.",
    )
    parser.add_argument(
        "--release-name",
        default=os.getenv("GOOGLE_PLAY_RELEASE_NAME") or detected_release_name,
        help="Nome da release exibido no Console. Ex.: 1.0.2+3.",
    )
    parser.add_argument(
        "--release-notes-file",
        default=os.getenv("GOOGLE_PLAY_RELEASE_NOTES_FILE"),
        help="Arquivo txt com as notas da versao.",
    )
    parser.add_argument(
        "--release-notes-language",
        default=os.getenv("GOOGLE_PLAY_RELEASE_NOTES_LANGUAGE", "pt-BR"),
        help="Idioma das notas da versao. Ex.: pt-BR.",
    )
    parser.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="Cria a release mas deixa as mudancas fora da submissao imediata para revisao.",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=int(os.getenv("GOOGLE_PLAY_API_RETRIES", "4")),
        help="Quantidade de retries para falhas transitórias da API (padrao: 4).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.package_name:
        print("Nao foi possivel detectar o package name. Informe --package-name.", file=sys.stderr)
        return 2

    service_account_json = None
    if args.service_account_json:
        service_account_json = _resolve_existing_file(args.service_account_json, "JSON da service account")
    aab_path = _resolve_existing_file(args.aab, "Arquivo AAB")
    release_notes_path = None
    if args.release_notes_file:
        release_notes_path = _resolve_existing_file(args.release_notes_file, "Arquivo de release notes")

    if service_account_json is not None:
        credentials = service_account.Credentials.from_service_account_file(
            str(service_account_json),
            scopes=SCOPES,
        )
    else:
        credentials, _ = google.auth.default(scopes=SCOPES)

    service = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)

    edit = _execute_with_retry(
        "edits.insert",
        lambda: service.edits().insert(packageName=args.package_name, body={}).execute(),
        retries=args.retries,
    )
    edit_id = edit["id"]

    try:
        bundle = _execute_with_retry(
            "bundles.upload",
            lambda: service.edits().bundles().upload(
                packageName=args.package_name,
                editId=edit_id,
                media_body=MediaFileUpload(
                    str(aab_path),
                    mimetype="application/octet-stream",
                    resumable=True,
                ),
            ).execute(),
            retries=args.retries,
        )

        version_code = str(bundle["versionCode"])
        release = {
            "status": args.release_status,
            "versionCodes": [version_code],
        }
        if args.release_name:
            release["name"] = args.release_name

        release_notes = _load_release_notes(release_notes_path, args.release_notes_language)
        if release_notes:
            release["releaseNotes"] = release_notes

        track_response = _execute_with_retry(
            "tracks.update",
            lambda: service.edits().tracks().update(
                packageName=args.package_name,
                editId=edit_id,
                track=args.track,
                body={"releases": [release]},
            ).execute(),
            retries=args.retries,
        )

        _execute_with_retry(
            "edits.commit",
            lambda: service.edits().commit(
                packageName=args.package_name,
                editId=edit_id,
                changesNotSentForReview=args.changes_not_sent_for_review,
            ).execute(),
            retries=args.retries,
        )
    except Exception:
        try:
            _execute_with_retry(
                "edits.delete",
                lambda: service.edits().delete(packageName=args.package_name, editId=edit_id).execute(),
                retries=min(args.retries, 2),
            )
        except Exception:
            pass
        raise

    print("Publicacao enviada com sucesso.")
    print(f"Package: {args.package_name}")
    print(f"Track: {args.track}")
    print(f"Status: {args.release_status}")
    print(f"Version code: {version_code}")
    print(f"Release name: {args.release_name or '(nao informado)'}")
    print(f"AAB: {aab_path}")
    print(f"Track response: {track_response.get('track', args.track)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())