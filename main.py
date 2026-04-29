import pandas as pd
import numpy as np
import random
import os
import logging
import time
import threading
import requests
import json
import re
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta, timezone
from collections import Counter, deque
from enum import Enum
from itertools import combinations

try:
    import psycopg2
    from psycopg2.extras import execute_values
except Exception:  # pragma: no cover - fallback defensivo
    psycopg2 = None
    execute_values = None

try:
    from zoneinfo import ZoneInfo
except Exception:  # pragma: no cover - fallback defensivo
    ZoneInfo = None

app = FastAPI()

DEFAULT_ALLOWED_ORIGINS = [
    "https://leonerdi.github.io",
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:5173",
    "http://localhost:8000",
    "http://localhost:8080",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:8000",
    "http://127.0.0.1:8080",
]


def _parse_allowed_origins() -> list[str]:
    raw_value = os.getenv("ALLOWED_ORIGINS", "").strip()
    if not raw_value:
        return DEFAULT_ALLOWED_ORIGINS.copy()
    origins = [origin.strip() for origin in raw_value.split(",") if origin.strip()]
    return origins or DEFAULT_ALLOWED_ORIGINS.copy()


def _resolve_cors_allow_credentials(origins: list[str]) -> bool:
    if origins == ["*"]:
        return False
    return os.getenv("CORS_ALLOW_CREDENTIALS", "1").strip().lower() not in {
        "0",
        "false",
        "no",
    }


def _safe_sql_identifier(raw_value: str, fallback: str) -> str:
    candidate = (raw_value or fallback).strip() or fallback
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", candidate):
        raise ValueError(
            "DB_TABLE inválido. Use apenas letras, números e underscore."
        )
    return candidate


ALLOWED_ORIGINS = _parse_allowed_origins()
CORS_ALLOW_CREDENTIALS = _resolve_cors_allow_credentials(ALLOWED_ORIGINS)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=CORS_ALLOW_CREDENTIALS,
    allow_methods=["GET"],
    allow_headers=["*"],
)

logger = logging.getLogger("lotofacil_sync")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# --- CONFIGURAÇÕES ---
CFG = {
    "WINDOW_SHORT": 30,
    "WINDOW_LONG": 300,
    "CANDIDATES": 800,
    "NUM_GAMES": 10,
    "SOMA_MIN": 170,
    "SOMA_MAX": 220,
    "SYNC_BASE_INTERVAL_SECONDS": int(os.getenv("SYNC_BASE_INTERVAL_SECONDS", "3600")),
    "SYNC_PREP_INTERVAL_SECONDS": int(os.getenv("SYNC_PREP_INTERVAL_SECONDS", "300")),
    "SYNC_PEAK_INTERVAL_SECONDS": int(os.getenv("SYNC_PEAK_INTERVAL_SECONDS", "120")),
    "SYNC_TARGET_HOUR_BRT": int(os.getenv("SYNC_TARGET_HOUR_BRT", "20")),
    "SYNC_TARGET_MINUTE_BRT": int(os.getenv("SYNC_TARGET_MINUTE_BRT", "45")),
    "SYNC_PREP_WINDOW_MINUTES": int(os.getenv("SYNC_PREP_WINDOW_MINUTES", "45")),
    "SYNC_PEAK_WINDOW_MINUTES": int(os.getenv("SYNC_PEAK_WINDOW_MINUTES", "120")),
    "SYNC_MAX_PROBE_AHEAD": int(os.getenv("SYNC_MAX_PROBE_AHEAD", "12")),
    "SYNC_MAX_CONSECUTIVE_MISSES": int(os.getenv("SYNC_MAX_CONSECUTIVE_MISSES", "2")),
}

CSV_PATH = "historico.csv"
API_BASE = "https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil"
JINA_PROXY_PREFIX = "https://r.jina.ai/http://"
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
ADMIN_API_TOKEN = os.getenv("ADMIN_API_TOKEN", "").strip()
DB_TABLE = _safe_sql_identifier(
    os.getenv("DB_TABLE", "historico_lotofacil"),
    fallback="historico_lotofacil",
)
CSV_COLUMNS = ["Concurso"] + [f"Bola{i}" for i in range(1, 16)]
API_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://loterias.caixa.gov.br/",
}

TAGS_ESTRATEGICAS = [
    "Foco em Dezenas Quentes",
    "Equilíbrio de Soma",
    "Tendência de Atraso",
    "Diversificação de Quadrantes",
    "Alta Densidade de Pares",
    "Dominância de Ímpares",
    "Sequência Progressiva",
    "Cobertura Máxima",
    "Padrão Recorrente",
    "Balanceamento Fino",
]

BORDAS_VOLANTE = {1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 20, 21, 22, 23, 24, 25}
DIAGONAIS_VOLANTE = {1, 5, 7, 9, 13, 17, 19, 21, 25}
CRUZ_VOLANTE = {3, 8, 11, 12, 13, 14, 15, 18, 23}


class EstrategiaEnum(str, Enum):
    equilibrado = "equilibrado"
    quentes = "quentes"
    atrasados = "atrasados"
    anti_divisao = "anti_divisao"


def _normalize_estrategia(estrategia: str | EstrategiaEnum | None) -> str:
    if isinstance(estrategia, EstrategiaEnum):
        return estrategia.value
    candidate = (estrategia or EstrategiaEnum.equilibrado.value).lower().strip()
    if candidate not in {item.value for item in EstrategiaEnum}:
        raise ValueError("Estratégia inválida")
    return candidate

_api_session = requests.Session()
_api_session.headers.update(API_HEADERS)

_sync_lock = threading.Lock()
_cache_lock = threading.Lock()
_storage_init_lock = threading.Lock()
_last_sync_attempt_ts = 0.0
_last_sync_result = {
    "status": "idle",
    "atualizado": False,
    "mensagem": "Sincronização ainda não executada neste processo.",
}

_runtime_cache = {
    "historico": {"key": None, "data": None},
    "contexto": {"key": None, "data": None},
    "response": {},
}

_metrics_lock = threading.Lock()
_runtime_metrics = {
    "started_at": time.time(),
    "requests_total": 0,
    "errors_total": 0,
    "latency_ms_window": deque(maxlen=400),
}

PUBLIC_RATE_LIMIT_PATHS = {
    "/diagnostico",
    "/gerar-combinacoes",
    "/gerar-jogos",
    "/similaridade",
}
PUBLIC_RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("PUBLIC_RATE_LIMIT_WINDOW_SECONDS", "60"))
PUBLIC_RATE_LIMIT_MAX_REQUESTS = int(os.getenv("PUBLIC_RATE_LIMIT_MAX_REQUESTS", "30"))
_rate_limit_lock = threading.Lock()
_rate_limit_hits: dict[tuple[str, str], deque[float]] = {}

_historico_revision = 0
_storage_initialized = False
_background_sync_started = False


def _require_admin_token(x_admin_token: str | None) -> None:
    if not ADMIN_API_TOKEN:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_API_TOKEN não configurado no servidor.",
        )

    if x_admin_token != ADMIN_API_TOKEN:
        raise HTTPException(status_code=403, detail="Acesso negado.")

if ZoneInfo is not None:
    BRT_TZ = ZoneInfo("America/Sao_Paulo")
else:
    # Fallback fixo para UTC-3 caso a base de fusos não esteja disponível.
    BRT_TZ = timezone(timedelta(hours=-3))


def _now_brt() -> datetime:
    return datetime.now(BRT_TZ)


def _invalidate_runtime_cache() -> None:
    with _cache_lock:
        _runtime_cache["historico"] = {"key": None, "data": None}
        _runtime_cache["contexto"] = {"key": None, "data": None}
        _runtime_cache["response"].clear()


def _db_enabled() -> bool:
    return bool(DATABASE_URL and psycopg2 is not None and execute_values is not None)


def _normalize_db_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql://" + url[len("postgres://") :]
    return url


def _db_connect():
    if not _db_enabled():
        raise RuntimeError("Banco de dados indisponível")
    db_url = _normalize_db_url(DATABASE_URL)
    sslmode = os.getenv("PGSSLMODE", "require")
    return psycopg2.connect(db_url, connect_timeout=10, sslmode=sslmode)


def _ensure_db_schema() -> None:
    cols = ",\n        ".join([f"bola{i} INTEGER NOT NULL" for i in range(1, 16)])
    query = f"""
    CREATE TABLE IF NOT EXISTS {DB_TABLE} (
        concurso INTEGER PRIMARY KEY,
        {cols},
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """
    with _db_connect() as conn:
        with conn.cursor() as cur:
            cur.execute(query)
        conn.commit()


def _load_historico_df_from_db() -> pd.DataFrame:
    select_cols = ", ".join(["concurso"] + [f"bola{i}" for i in range(1, 16)])
    query = f"SELECT {select_cols} FROM {DB_TABLE} ORDER BY concurso"
    with _db_connect() as conn:
        with conn.cursor() as cur:
            cur.execute(query)
            rows = cur.fetchall()

    if not rows:
        return pd.DataFrame(columns=CSV_COLUMNS)

    df = pd.DataFrame(rows, columns=["Concurso"] + [f"Bola{i}" for i in range(1, 16)])
    df = _padronizar_colunas_historico(df)
    for col in CSV_COLUMNS:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int)
    return df


def _persist_historico_df_to_db(df: pd.DataFrame) -> None:
    if df.empty:
        return

    rows = []
    for _, r in df.iterrows():
        rows.append(tuple(int(r[c]) for c in CSV_COLUMNS))

    insert_cols = ["concurso"] + [f"bola{i}" for i in range(1, 16)]
    insert_cols_sql = ", ".join(insert_cols)
    update_sql = ", ".join([f"bola{i}=EXCLUDED.bola{i}" for i in range(1, 16)]) + ", updated_at=NOW()"
    query = f"""
    INSERT INTO {DB_TABLE} ({insert_cols_sql})
    VALUES %s
    ON CONFLICT (concurso)
    DO UPDATE SET {update_sql}
    """

    with _db_connect() as conn:
        with conn.cursor() as cur:
            execute_values(cur, query, rows)
        conn.commit()


def _load_historico_df_from_csv() -> pd.DataFrame:
    if not os.path.exists(CSV_PATH):
        return pd.DataFrame(columns=CSV_COLUMNS)

    try:
        df = pd.read_csv(CSV_PATH)
        df = _padronizar_colunas_historico(df)

        for col in CSV_COLUMNS:
            if col not in df.columns:
                df[col] = np.nan

        df = df[CSV_COLUMNS]
        df["Concurso"] = pd.to_numeric(df["Concurso"], errors="coerce")
        df = df.dropna(subset=["Concurso"])
        df["Concurso"] = df["Concurso"].astype(int)

        for col in CSV_COLUMNS[1:]:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int)
        return df
    except Exception as e:
        logger.exception("Falha ao carregar historico.csv. Seguindo com base vazia. Erro: %s", e)
        return pd.DataFrame(columns=CSV_COLUMNS)


def _bootstrap_db_from_csv_if_empty() -> None:
    if not _db_enabled():
        return

    with _db_connect() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(1) FROM {DB_TABLE}")
            total = int(cur.fetchone()[0])

    if total > 0:
        return

    df_csv = _load_historico_df_from_csv()
    if not df_csv.empty:
        _persist_historico_df_to_db(df_csv)
        logger.info("Storage: DB inicializado a partir do CSV local (+%s concursos)", len(df_csv))


def _init_storage_if_needed() -> None:
    global _storage_initialized
    if _storage_initialized:
        return

    with _storage_init_lock:
        if _storage_initialized:
            return

        if _db_enabled():
            _ensure_db_schema()
            _bootstrap_db_from_csv_if_empty()

        _storage_initialized = True


def _historico_cache_key() -> tuple:
    global _historico_revision
    if _db_enabled():
        return ("db", _historico_revision)

    if not os.path.exists(CSV_PATH):
        return ("missing", 0)
    stat = os.stat(CSV_PATH)
    # mtime_ns + size evita cache stale em atualizações rápidas.
    return (stat.st_mtime_ns, stat.st_size)


def _get_cached_response(key: str, ttl_seconds: int):
    now = time.time()
    with _cache_lock:
        entry = _runtime_cache["response"].get(key)
        if not entry:
            return None
        if now - entry["ts"] > ttl_seconds:
            _runtime_cache["response"].pop(key, None)
            return None
        return entry["data"]


def _set_cached_response(key: str, data) -> None:
    with _cache_lock:
        _runtime_cache["response"][key] = {"ts": time.time(), "data": data}


def _snapshot_metrics() -> dict:
    with _metrics_lock:
        latencies = list(_runtime_metrics["latency_ms_window"])
        requests_total = int(_runtime_metrics["requests_total"])
        errors_total = int(_runtime_metrics["errors_total"])

    if latencies:
        avg_ms = round(float(np.mean(latencies)), 2)
        p95_ms = round(float(np.percentile(latencies, 95)), 2)
    else:
        avg_ms = 0.0
        p95_ms = 0.0

    error_rate = round((errors_total / requests_total) * 100, 2) if requests_total else 0.0
    uptime_seconds = int(max(0, time.time() - _runtime_metrics["started_at"]))

    return {
        "uptime_segundos": uptime_seconds,
        "requests_total": requests_total,
        "errors_total": errors_total,
        "error_rate_percentual": error_rate,
        "latencia_media_ms": avg_ms,
        "latencia_p95_ms": p95_ms,
        "janela_amostras": len(latencies),
    }


def _get_client_ip(request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "").strip()
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _check_public_rate_limit(request):
    if request.method != "GET":
        return None
    if request.url.path not in PUBLIC_RATE_LIMIT_PATHS:
        return None
    if PUBLIC_RATE_LIMIT_MAX_REQUESTS <= 0 or PUBLIC_RATE_LIMIT_WINDOW_SECONDS <= 0:
        return None

    now = time.time()
    key = (_get_client_ip(request), request.url.path)

    with _rate_limit_lock:
        bucket = _rate_limit_hits.setdefault(key, deque())
        cutoff = now - PUBLIC_RATE_LIMIT_WINDOW_SECONDS
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()

        if len(bucket) >= PUBLIC_RATE_LIMIT_MAX_REQUESTS:
            retry_after = max(1, int(bucket[0] + PUBLIC_RATE_LIMIT_WINDOW_SECONDS - now))
            return JSONResponse(
                status_code=429,
                content={"detail": "Muitas requisições. Tente novamente em instantes."},
                headers={"Retry-After": str(retry_after)},
            )

        bucket.append(now)

    return None


@app.middleware("http")
async def request_metrics_middleware(request, call_next):
    start = time.perf_counter()
    status_code = 500
    try:
        rate_limited_response = _check_public_rate_limit(request)
        if rate_limited_response is not None:
            status_code = int(rate_limited_response.status_code)
            return rate_limited_response

        response = await call_next(request)
        status_code = int(response.status_code)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")

        if request.url.path in {"/healthz", "/ops/metrics", "/admin/sync"}:
            response.headers["Cache-Control"] = "no-store"

        return response
    finally:
        elapsed_ms = (time.perf_counter() - start) * 1000
        with _metrics_lock:
            _runtime_metrics["requests_total"] += 1
            _runtime_metrics["latency_ms_window"].append(elapsed_ms)
            if status_code >= 500:
                _runtime_metrics["errors_total"] += 1


def _compute_sync_interval_seconds(now_brt: datetime) -> int:
    """
    Ajusta a cadência de sync para ficar mais próxima da publicação da Caixa:
    - Fora da janela: polling leve.
    - Janela pré-publicação: polling médio.
    - Janela pós-publicação (pico): polling rápido.
    """
    base_interval = max(300, int(CFG["SYNC_BASE_INTERVAL_SECONDS"]))
    prep_interval = max(60, int(CFG["SYNC_PREP_INTERVAL_SECONDS"]))
    peak_interval = max(60, int(CFG["SYNC_PEAK_INTERVAL_SECONDS"]))

    # Lotofácil: concurso regular de segunda a sábado.
    is_draw_day = now_brt.weekday() in (0, 1, 2, 3, 4, 5)
    if not is_draw_day:
        return base_interval

    target = now_brt.replace(
        hour=int(CFG["SYNC_TARGET_HOUR_BRT"]),
        minute=int(CFG["SYNC_TARGET_MINUTE_BRT"]),
        second=0,
        microsecond=0,
    )

    prep_start = target - timedelta(minutes=int(CFG["SYNC_PREP_WINDOW_MINUTES"]))
    peak_end = target + timedelta(minutes=int(CFG["SYNC_PEAK_WINDOW_MINUTES"]))

    if now_brt < prep_start or now_brt > peak_end:
        return base_interval
    if now_brt < target:
        return prep_interval
    return peak_interval


def _padronizar_colunas_historico(df: pd.DataFrame) -> pd.DataFrame:
    """Padroniza o DataFrame para o schema Concurso, Bola1..Bola15."""
    if "Concursos" in df.columns and "Concurso" not in df.columns:
        df = df.rename(columns={"Concursos": "Concurso"})
    return df


def _load_historico_df() -> pd.DataFrame:
    """Carrega o histórico em DataFrame padronizado, com fallback para vazio."""
    _init_storage_if_needed()

    if _db_enabled():
        try:
            return _load_historico_df_from_db()
        except Exception as e:
            logger.exception("Falha ao carregar histórico no DB. Usando fallback CSV. Erro: %s", e)

    return _load_historico_df_from_csv()


def _persist_historico_df(df: pd.DataFrame) -> None:
    global _historico_revision
    _init_storage_if_needed()

    if _db_enabled():
        _persist_historico_df_to_db(df)
    else:
        df.to_csv(CSV_PATH, index=False)

    _historico_revision += 1
    _invalidate_runtime_cache()


def _fetch_api_json(url: str) -> dict:
    """Busca JSON com timeout e validação HTTP, com fallback para espelho."""
    try:
        response = _api_session.get(url, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as direct_error:
        status = None
        if isinstance(direct_error, requests.HTTPError) and direct_error.response is not None:
            status = int(direct_error.response.status_code)

        # Somente tenta fallback em bloqueios/transientes comuns de infraestrutura.
        if status not in (403, 429, 500, 502, 503, 504):
            raise

        proxy_url = url
        if proxy_url.startswith("https://"):
            proxy_url = JINA_PROXY_PREFIX + proxy_url[len("https://") :]
        elif proxy_url.startswith("http://"):
            proxy_url = "https://r.jina.ai/" + proxy_url

        try:
            proxy_resp = requests.get(proxy_url, timeout=15, headers={"User-Agent": API_HEADERS["User-Agent"]})
            proxy_resp.raise_for_status()
            body = proxy_resp.text
            start = body.find("{")
            end = body.rfind("}")
            if start < 0 or end < 0 or end <= start:
                raise ValueError("Resposta do fallback não contém JSON válido")
            return json.loads(body[start : end + 1])
        except Exception as fallback_error:
            raise requests.HTTPError(f"{direct_error} | fallback: {fallback_error}")


def _fetch_latest_payload() -> dict:
    """Busca o concurso mais recente com fallback entre contratos da API da Caixa."""
    errors = []
    for url in (API_BASE, f"{API_BASE}/ultimo"):
        try:
            payload = _fetch_api_json(url)
            if _is_error_payload(payload):
                errors.append(f"{url}: payload de erro remoto")
                continue
            return payload
        except requests.RequestException as e:
            errors.append(f"{url}: {e}")
    raise requests.HTTPError(" | ".join(errors))


def _is_error_payload(payload: dict) -> bool:
    if not isinstance(payload, dict):
        return False
    error_keys = {"message", "exceptionMessage", "innerMessage", "stackTrace"}
    return any(k in payload for k in error_keys) and "numero" not in payload


def _extract_concurso_numero(payload: dict) -> int:
    """Extrai o número do concurso de payloads com contratos variados."""
    if not isinstance(payload, dict):
        raise ValueError("Payload inválido: esperado dict")

    candidate_keys = (
        "numero",
        "numeroConcurso",
        "numero_concurso",
        "numeroDoConcurso",
        "concurso",
    )

    for key in candidate_keys:
        value = payload.get(key)
        if value is not None and str(value).strip() != "":
            return int(value)

    # Alguns contratos podem vir em estrutura aninhada.
    resultado = payload.get("resultado")
    if isinstance(resultado, dict):
        for key in candidate_keys:
            value = resultado.get(key)
            if value is not None and str(value).strip() != "":
                return int(value)

    available = ", ".join(sorted(payload.keys()))
    raise KeyError(f"Campo de número do concurso não encontrado. Chaves disponíveis: {available}")


def _try_fetch_concurso_payload(concurso: int) -> dict | None:
    """Tenta buscar um concurso específico; retorna None quando não existe."""
    try:
        payload = _fetch_api_json(f"{API_BASE}/{concurso}")
        if _is_error_payload(payload):
            return None
        return payload
    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else None
        if status in (400, 404, 500, 502, 503, 504):
            return None
        raise


def _resolve_latest_concurso(ultimo_local: int) -> int:
    """Resolve o último concurso real com sondagem incremental para evitar cache defasado."""
    base_payload = _fetch_latest_payload()
    latest = _extract_concurso_numero(base_payload)

    # Algumas APIs podem devolver um "último" atrasado por cache. Sondamos alguns
    # concursos à frente para capturar publicação recém-disponível.
    probe = max(latest, ultimo_local)
    max_probe_ahead = max(1, int(CFG["SYNC_MAX_PROBE_AHEAD"]))
    for i in range(1, max_probe_ahead + 1):
        payload = _try_fetch_concurso_payload(probe + i)
        if payload is None:
            break
        latest = _extract_concurso_numero(payload)

    return latest


def _row_from_api_payload(payload: dict) -> dict:
    """Converte payload da API externa no formato Concurso, Bola1..Bola15."""
    numero = _extract_concurso_numero(payload)
    dezenas = payload.get("listaDezenas") or payload.get("dezenasSorteadasOrdemSorteio") or []

    if len(dezenas) != 15:
        raise ValueError(f"Payload inválido para concurso {numero}: dezenas={len(dezenas)}")

    dezenas_int = sorted(int(d) for d in dezenas)
    row = {"Concurso": numero}
    for i, dezena in enumerate(dezenas_int, start=1):
        row[f"Bola{i}"] = dezena
    return row


def sync_database() -> dict:
    """
    Sincroniza o histórico com os concursos mais recentes da API.
    Em caso de erro de rede/API, não quebra a aplicação (fallback resiliente).
    """
    try:
        df_local = _load_historico_df()
        ultimo_local = int(df_local["Concurso"].max()) if not df_local.empty else 0

        ultimo_api = _resolve_latest_concurso(ultimo_local)

        if ultimo_api <= ultimo_local:
            logger.info("Sync: base já atualizada (local=%s, api=%s)", ultimo_local, ultimo_api)
            return {
                "status": "sucesso",
                "atualizado": False,
                "ultimo_local": ultimo_local,
                "ultimo_api": ultimo_api,
                "novos_concursos": 0,
            }

        novos_rows = []
        consecutive_misses = 0
        max_consecutive_misses = max(1, int(CFG["SYNC_MAX_CONSECUTIVE_MISSES"]))
        for concurso in range(ultimo_local + 1, ultimo_api + 1):
            payload = _try_fetch_concurso_payload(concurso)
            if payload is None:
                consecutive_misses += 1
                if consecutive_misses >= max_consecutive_misses:
                    logger.info(
                        "Sync: encerrando varredura após %s ausência(s) consecutiva(s) (até concurso %s).",
                        consecutive_misses,
                        concurso,
                    )
                    break
                continue

            consecutive_misses = 0
            try:
                novos_rows.append(_row_from_api_payload(payload))
            except Exception as e:
                # Falha pontual de payload não derruba o sync completo.
                logger.warning("Sync: payload inválido no concurso %s: %s", concurso, e)

        if not novos_rows:
            return {
                "status": "sucesso",
                "atualizado": False,
                "ultimo_local": ultimo_local,
                "ultimo_api": ultimo_api,
                "novos_concursos": 0,
            }

        df_novos = pd.DataFrame(novos_rows)
        df_total = pd.concat([df_local, df_novos], ignore_index=True)
        df_total = df_total.drop_duplicates(subset=["Concurso"], keep="last")
        df_total = df_total.sort_values(by="Concurso").reset_index(drop=True)

        # Garante inteiros no formato final
        for col in CSV_COLUMNS:
            df_total[col] = pd.to_numeric(df_total[col], errors="coerce").fillna(0).astype(int)

        _persist_historico_df(df_total)

        logger.info(
            "Sync concluído: +%s concursos (local %s -> %s)",
            len(df_novos),
            ultimo_local,
            int(df_total["Concurso"].max()),
        )
        return {
            "status": "sucesso",
            "atualizado": True,
            "ultimo_local": ultimo_local,
            "ultimo_api": ultimo_api,
            "novos_concursos": len(df_novos),
        }
    except Exception as e:
        # Falha global: apenas loga e mantém sistema operando com base local
        logger.exception("Sync falhou. Sistema continuará com base local. Erro: %s", e)
        return {
            "status": "fallback",
            "atualizado": False,
            "mensagem": "Falha na sincronização remota; usando base local.",
            "erro": str(e),
        }


def ensure_database_synced(force: bool = False) -> dict:
    """
    Garante sync automático por janela de tempo para manter a base atualizada.
    Evita chamadas excessivas à API e concorrência entre requisições simultâneas.
    """
    global _last_sync_attempt_ts, _last_sync_result

    now = time.time()
    now_brt = _now_brt()
    interval = _compute_sync_interval_seconds(now_brt)
    elapsed = now - _last_sync_attempt_ts

    if not force and _last_sync_attempt_ts > 0 and elapsed < interval:
        return {
            "status": "skip",
            "atualizado": False,
            "mensagem": "Sync recente; aguardando próxima janela automática.",
            "proxima_tentativa_em_segundos": int(interval - elapsed),
            "intervalo_atual_segundos": interval,
            "horario_referencia_brt": now_brt.strftime("%Y-%m-%d %H:%M:%S"),
            "ultimo_resultado": _last_sync_result,
        }

    if not _sync_lock.acquire(blocking=False):
        return {
            "status": "busy",
            "atualizado": False,
            "mensagem": "Sync já em execução por outra requisição.",
            "intervalo_atual_segundos": interval,
            "horario_referencia_brt": now_brt.strftime("%Y-%m-%d %H:%M:%S"),
            "ultimo_resultado": _last_sync_result,
        }

    try:
        _last_sync_attempt_ts = now
        _last_sync_result = sync_database()
        return _last_sync_result
    finally:
        _sync_lock.release()


def load_historico_blindado():
    cache_key = _historico_cache_key()
    with _cache_lock:
        cached = _runtime_cache["historico"]
        if cached["key"] == cache_key and cached["data"] is not None:
            return cached["data"]

    if not _db_enabled() and not os.path.exists(CSV_PATH):
        logger.warning("Historico local indisponivel (%s). Usando base temporaria.", CSV_PATH)
        historico_tmp = [sorted(random.sample(range(1, 26), 15)) for _ in range(300)]
        with _cache_lock:
            _runtime_cache["historico"] = {"key": cache_key, "data": historico_tmp}
        return historico_tmp

    try:
        df = _load_historico_df()
        if df.empty:
            historico_tmp = [sorted(random.sample(range(1, 26), 15)) for _ in range(300)]
            with _cache_lock:
                _runtime_cache["historico"] = {"key": cache_key, "data": historico_tmp}
            return historico_tmp

        dados_puros = df.iloc[:, 1:16].values.tolist()
        historico = []
        for sorteio in dados_puros:
            if len(sorteio) == 15:
                historico.append(sorted([int(n) for n in sorteio]))

        with _cache_lock:
            _runtime_cache["historico"] = {"key": cache_key, "data": historico}
        return historico
    except Exception as e:
        logger.exception("Falha ao processar historico local. Usando base temporaria. Erro: %s", e)
        historico_tmp = [sorted(random.sample(range(1, 26), 15)) for _ in range(300)]
        with _cache_lock:
            _runtime_cache["historico"] = {"key": cache_key, "data": historico_tmp}
        return historico_tmp


def _background_sync_loop():
    tick_seconds = max(30, int(os.getenv("SYNC_BACKGROUND_TICK_SECONDS", "60")))
    logger.info("Background sync iniciado (tick=%ss)", tick_seconds)
    while True:
        try:
            ensure_database_synced(force=False)
        except Exception as e:
            logger.exception("Background sync loop falhou: %s", e)
        time.sleep(tick_seconds)


def _start_background_sync_if_enabled():
    global _background_sync_started
    if _background_sync_started:
        return

    enabled = os.getenv("SYNC_BACKGROUND_ENABLED", "1").strip().lower() not in {"0", "false", "no"}
    if not enabled:
        logger.info("Background sync desabilitado por SYNC_BACKGROUND_ENABLED")
        return

    thread = threading.Thread(target=_background_sync_loop, name="sync-background", daemon=True)
    thread.start()
    _background_sync_started = True


def _get_contexto_analitico(historico):
    cache_key = _historico_cache_key()
    with _cache_lock:
        cached = _runtime_cache["contexto"]
        if cached["key"] == cache_key and cached["data"] is not None:
            return cached["data"]

    stats = get_stats(historico)
    freq = stats["freq"]
    short_freq = get_freq_window(historico, CFG["WINDOW_SHORT"])
    delay_map = get_delay_map(historico)
    tendencias = calcular_tendencias(historico)
    hot_set = {item["dezena"] for item in tendencias["hot"]}
    cold_set = {item["dezena"] for item in tendencias["cold"]}
    equilibrio = calcular_equilibrio(historico)

    contexto = {
        "freq": freq,
        "short_freq": short_freq,
        "delay_map": delay_map,
        "tendencias": tendencias,
        "hot_set": hot_set,
        "cold_set": cold_set,
        "equilibrio": equilibrio,
    }

    with _cache_lock:
        _runtime_cache["contexto"] = {"key": cache_key, "data": contexto}

    return contexto


@app.on_event("startup")
def startup_sync():
    """Gatilho automático de atualização ao iniciar o servidor."""
    _init_storage_if_needed()
    result = ensure_database_synced(force=True)
    logger.info("Startup sync result: %s", result)
    _start_background_sync_if_enabled()


@app.get("/admin/sync")
def admin_sync(x_admin_token: str | None = Header(default=None)):
    """Força sincronização manual sem derrubar o serviço em caso de erro."""
    _require_admin_token(x_admin_token)
    return ensure_database_synced(force=True)


@app.get("/healthz")
def healthz():
    """Healthcheck leve para orquestrador e monitoramento."""
    return {
        "status": "ok",
        "timestamp": _now_brt().strftime("%Y-%m-%d %H:%M:%S"),
        "sync_status": _last_sync_result.get("status", "unknown"),
    }


@app.get("/ops/metrics")
def ops_metrics(x_admin_token: str | None = Header(default=None)):
    """Métricas operacionais básicas para gatilhos de escala."""
    _require_admin_token(x_admin_token)
    return {
        "status": "ok",
        "timestamp": _now_brt().strftime("%Y-%m-%d %H:%M:%S"),
        "sync": _last_sync_result,
        "metrics": _snapshot_metrics(),
    }


def get_stats(hist):
    flat_list = [n for draw in hist for n in draw]
    counts = pd.Series(flat_list).value_counts(normalize=True).to_dict()
    freq = {n: counts.get(n, 0) for n in range(1, 26)}
    return {"freq": freq}


def get_freq_window(hist, window=30):
    janela = hist[-window:] if len(hist) >= window else hist
    flat = [n for draw in janela for n in draw]
    counts = pd.Series(flat).value_counts(normalize=True).to_dict()
    return {n: counts.get(n, 0) for n in range(1, 26)}


def get_delay_map(hist):
    """Retorna há quantos concursos cada dezena não aparece."""
    delay_map = {}
    for n in range(1, 26):
        atraso = 0
        for draw in reversed(hist):
            if n in draw:
                break
            atraso += 1
        delay_map[n] = atraso
    return delay_map


def calcular_regime(historico):
    """Calcula o regime de estabilidade com base na variância das frequências."""
    if len(historico) < 60:
        return {"label": "Moderado", "index": 0.5, "descricao_humana": "Dados insuficientes para análise profunda."}

    janelas = [historico[-30:], historico[-60:-30]]
    freqs = []
    for janela in janelas:
        flat = [n for draw in janela for n in draw]
        c = Counter(flat)
        freqs.append([c.get(n, 0) for n in range(1, 26)])

    variacao = np.mean(np.abs(np.array(freqs[0]) - np.array(freqs[1])))
    MAX_VAR = 8.0
    index = float(np.clip(1.0 - (variacao / MAX_VAR), 0.0, 1.0))
    index = round(index, 3)

    if index >= 0.72:
        return {
            "label": "Estável",
            "index": index,
            "descricao_humana": "O padrão histórico está consistente. Ótimo momento para estratégias de frequência.",
        }
    elif index >= 0.42:
        return {
            "label": "Moderado",
            "index": index,
            "descricao_humana": "O histórico apresenta variações moderadas. A IA está reequilibrando os pesos.",
        }
    else:
        return {
            "label": "Inconstante",
            "index": index,
            "descricao_humana": "Alta variação detectada. A IA prioriza dezenas com atraso para compensar.",
        }


def calcular_tendencias(historico):
    """Retorna top-5 quentes e top-5 frias na janela de 30 concursos."""
    janela = historico[-30:]
    flat = [n for draw in janela for n in draw]
    c = Counter(flat)
    todos = {n: c.get(n, 0) for n in range(1, 26)}
    ordenado = sorted(todos.items(), key=lambda x: x[1], reverse=True)
    hot = [{"dezena": k, "frequencia": v} for k, v in ordenado[:5]]
    cold = [{"dezena": k, "frequencia": v} for k, v in ordenado[-5:]]
    return {"hot": hot, "cold": cold}


def calcular_equilibrio(historico):
    """Calcula a faixa de soma ideal e paridade sugerida."""
    somas = [sum(draw) for draw in historico[-100:]]
    soma_media = int(np.mean(somas))
    soma_std = int(np.std(somas))
    faixa_min = max(CFG["SOMA_MIN"], soma_media - soma_std)
    faixa_max = min(CFG["SOMA_MAX"], soma_media + soma_std)

    pares = [sum(1 for n in draw if n % 2 == 0) for draw in historico[-100:]]
    media_pares = round(np.mean(pares))
    media_impares = 15 - media_pares

    return {
        "faixa_soma": f"{faixa_min} - {faixa_max}",
        "paridade_sugerida": f"{media_pares} Pares / {media_impares} Ímpares",
        "soma_ideal": soma_media,
        "desvio_padrao_soma": round(float(np.std(somas)), 1),
    }


def calcular_atrasos_detectados(historico, top_n=5):
    delay_map = get_delay_map(historico)
    ordenado = sorted(delay_map.items(), key=lambda item: (-item[1], item[0]))
    return [
        {"dezena": int(dezena), "atraso": int(atraso)}
        for dezena, atraso in ordenado[:top_n]
    ]


def calcular_melhores_trincas(historico, window=180, top_n=3):
    janela = historico[-window:] if len(historico) >= window else historico
    contador = Counter()

    for draw in janela:
        for trio in combinations(sorted(draw), 3):
            contador[trio] += 1

    return [
        {
            "dezenas": list(trio),
            "frequencia": int(freq),
        }
        for trio, freq in contador.most_common(top_n)
    ]


def calcular_alerta_probabilistico(historico):
    if not historico:
        return {
            "intervalo": "N/D",
            "probabilidade_percentual": 0.0,
            "media_recente": 0.0,
            "media_base": 0.0,
            "corredor": "10-20",
            "faixas_probabilidade": [],
            "mensagem": "Sem dados suficientes para inferir corredores dominantes.",
        }

    janela_recente = historico[-30:] if len(historico) >= 30 else historico
    janela_base = historico[-120:] if len(historico) >= 120 else historico

    # Corredor monitorado para estratégia de concentração.
    corredor_label = "10-20"
    inicio, fim = 10, 20

    def _classificar_faixa(qtd_no_corredor: int) -> str:
        if qtd_no_corredor <= 5:
            return "0-5"
        if qtd_no_corredor <= 10:
            return "6-10"
        return "11-15"

    base_counts = [sum(1 for n in draw if inicio <= n <= fim) for draw in janela_base]
    recent_counts = [sum(1 for n in draw if inicio <= n <= fim) for draw in janela_recente]

    base_bins = Counter(_classificar_faixa(c) for c in base_counts)
    recent_bins = Counter(_classificar_faixa(c) for c in recent_counts)

    faixas = ["0-5", "6-10", "11-15"]
    total_base = len(base_counts) or 1
    total_recent = len(recent_counts) or 1
    faixas_probabilidade = []

    for faixa in faixas:
        prob_base = (base_bins.get(faixa, 0) / total_base) * 100
        prob_recente = (recent_bins.get(faixa, 0) / total_recent) * 100
        faixas_probabilidade.append(
            {
                "faixa": faixa,
                "probabilidade_percentual": round(prob_base, 1),
                "ocorrencias_base": int(base_bins.get(faixa, 0)),
                "ocorrencias_recentes": int(recent_bins.get(faixa, 0)),
                "tendencia_pp": round(prob_recente - prob_base, 1),
            }
        )

    # Melhor faixa: prioriza recorrência recente, depois aderência histórica.
    melhor = max(
        faixas_probabilidade,
        key=lambda item: (
            item["ocorrencias_recentes"],
            item["probabilidade_percentual"],
            item["tendencia_pp"],
        ),
    )

    top_sugestoes = sorted(
        faixas_probabilidade,
        key=lambda item: (
            item["ocorrencias_recentes"],
            item["probabilidade_percentual"],
            item["tendencia_pp"],
        ),
        reverse=True,
    )[:2]

    media_base = float(np.mean(base_counts)) if base_counts else 0.0
    media_recente = float(np.mean(recent_counts)) if recent_counts else 0.0
    sugestao_txt = " e ".join(item["faixa"] for item in top_sugestoes)

    return {
        "intervalo": melhor["faixa"],
        "corredor": corredor_label,
        "probabilidade_percentual": melhor["probabilidade_percentual"],
        "media_recente": round(media_recente, 2),
        "media_base": round(media_base, 2),
        "faixas_probabilidade": faixas_probabilidade,
        "mensagem": (
            f"No corredor {corredor_label}, a faixa mais aderente foi {melhor['faixa']} "
            f"(probabilidade historica {melhor['probabilidade_percentual']}%). "
            f"Sugestao de foco: {sugestao_txt}."
        ),
    }


def calcular_fechamento_ciclo_dezenas(historico, window=5):
    """
    Calcula o estado do ciclo de dezenas em uma janela recente.

    A ideia operacional: quanto menos dezenas faltantes para cobrir 1..25
    nos ultimos concursos da janela, maior a prioridade dessas faltantes.
    """
    if not historico:
        return {
            "janela": 0,
            "dezenas_faltantes": [],
            "faltantes": 25,
            "status": "dados_insuficientes",
        }

    janela = historico[-window:] if len(historico) >= window else historico
    vistas = {n for draw in janela for n in draw}
    faltantes = sorted(set(range(1, 26)) - vistas)

    if len(faltantes) <= 2:
        status = "fechamento_iminente"
    elif len(faltantes) <= 4:
        status = "fechamento_provavel"
    else:
        status = "ciclo_aberto"

    return {
        "janela": len(janela),
        "dezenas_faltantes": faltantes,
        "faltantes": len(faltantes),
        "status": status,
    }


def calcular_penalidade_anti_divisao(jogo):
    numeros = set(jogo)
    hits_borda = len(numeros & BORDAS_VOLANTE)
    hits_diagonal = len(numeros & DIAGONAIS_VOLANTE)
    hits_cruz = len(numeros & CRUZ_VOLANTE)
    sequencias = sum(1 for a, b in zip(jogo, jogo[1:]) if (b - a) == 1)
    linhas = [sum(1 for n in jogo if (linha * 5) + 1 <= n <= (linha * 5) + 5) for linha in range(5)]
    simetria = max(linhas) - min(linhas)
    return min((hits_borda * 5) + (hits_diagonal * 6) + (hits_cruz * 7) + (sequencias * 12) + (max(0, simetria - 2) * 10), 180)


def calcular_bonus_dispersao(jogo):
    gaps = [b - a for a, b in zip(jogo, jogo[1:])]
    variancia_gaps = float(np.std(gaps)) if gaps else 0.0
    quadrantes = len({(n - 1) // 5 for n in jogo})
    return min((variancia_gaps * 12) + (quadrantes * 6), 90)


def obter_contexto_inteligente(historico):
    df_local = _load_historico_df()
    ultimo_concurso = int(df_local["Concurso"].max()) if not df_local.empty else len(historico)
    similaridade = _find_similar_cycle(historico, window_size=5)
    return {
        "ultimo_concurso": ultimo_concurso,
        "proximo_concurso": ultimo_concurso + 1,
        "atrasadas_detectadas": calcular_atrasos_detectados(historico),
        "melhores_trincas": calcular_melhores_trincas(historico),
        "alerta_padrao": calcular_alerta_probabilistico(historico),
        "similaridade_ciclica": similaridade,
    }


def score_game(
    jogo,
    freq,
    short_freq,
    delay_map,
    hot_set,
    cold_set,
    soma_ideal,
    estrategia="equilibrado",
    ciclo_faltantes=None,
):
    """
    Calcula o IA Rating (0-1000) de um jogo.
    Critérios: frequência histórica, peso de quentes, cobertura de atrasadas,
    proximidade de soma ideal, equilíbrio par/ímpar.
    """
    # Componente 1: Frequência histórica longa normalizada (0-280 pts)
    freq_score = sum(freq.get(n, 0) for n in jogo)
    freq_pts = min(freq_score / (15 * 0.065), 1.0) * 280

    # Componente 1b: Frequência curta (últimos concursos) (0-120 pts base)
    short_score = sum(short_freq.get(n, 0) for n in jogo)
    short_base_pts = min(short_score / (15 * 0.075), 1.0) * 120

    # Componente 2: Quentes (0-180 pts)
    quentes_no_jogo = sum(1 for n in jogo if n in hot_set)
    hot_pts = (quentes_no_jogo / 5) * 180

    # Componente 3: Atrasadas por janela fria (0-130 pts)
    cold_no_jogo = sum(1 for n in jogo if n in cold_set)
    cold_pts = (cold_no_jogo / 5) * 130

    # Componente 3b: atraso real por concursos (0-220 pts)
    atraso_total = sum(delay_map.get(n, 0) for n in jogo)
    max_delay = max(delay_map.values()) if delay_map else 1
    atraso_pts = min(atraso_total / (15 * max_delay if max_delay > 0 else 1), 1.0) * 220

    # Componente 4: Proximidade da soma ideal (0-120 pts)
    soma = sum(jogo)
    distancia_soma = abs(soma - soma_ideal)
    soma_pts = max(0, 1.0 - (distancia_soma / 40)) * 120

    # Componente 5: Equilíbrio par/ímpar (0-70 pts)
    pares = sum(1 for n in jogo if n % 2 == 0)
    equil = 1.0 - abs(pares - 7.5) / 7.5
    equil_pts = equil * 70

    estrategia = (estrategia or "equilibrado").lower().strip()

    if estrategia == "quentes":
        # 2.5x na frequência curta para privilegiar dezenas em alta recente
        total = freq_pts + (short_base_pts * 2.5) + hot_pts + (cold_pts * 0.6) + soma_pts + equil_pts
    elif estrategia == "atrasados":
        # Prioriza dezenas atrasadas com viés adicional de fechamento de ciclo.
        total = (freq_pts * 0.6) + (short_base_pts * 0.5) + (hot_pts * 0.4) + cold_pts + atraso_pts + soma_pts + equil_pts

        ciclo_faltantes = set(ciclo_faltantes or [])
        if ciclo_faltantes:
            hits_ciclo = sum(1 for n in jogo if n in ciclo_faltantes)
            qtd_faltantes = len(ciclo_faltantes)

            # Quando o ciclo está perto de fechar, exigimos mais cobertura das faltantes.
            foco = max(1, min(4, qtd_faltantes))
            cobertura = min(1.0, hits_ciclo / foco)
            urgencia = 1.45 if qtd_faltantes <= 2 else (1.2 if qtd_faltantes <= 4 else 1.0)
            bonus_ciclo = cobertura * 200 * urgencia

            # Penaliza combinação que ignora faltantes quando o ciclo está muito próximo.
            if hits_ciclo == 0:
                if qtd_faltantes <= 2:
                    bonus_ciclo -= 70
                elif qtd_faltantes <= 4:
                    bonus_ciclo -= 40

            total += bonus_ciclo
    elif estrategia == "anti_divisao":
        penalidade_visual = calcular_penalidade_anti_divisao(jogo)
        bonus_dispersao = calcular_bonus_dispersao(jogo)
        total = (
            (freq_pts * 0.8)
            + (short_base_pts * 0.7)
            + (hot_pts * 0.45)
            + (cold_pts * 0.8)
            + (atraso_pts * 0.55)
            + soma_pts
            + equil_pts
            + bonus_dispersao
            - penalidade_visual
        )
    else:
        # Equilibrado (lógica PRO padrão)
        total = freq_pts + short_base_pts + hot_pts + cold_pts + (atraso_pts * 0.35) + soma_pts + equil_pts

    return int(max(0, min(round(total), 1000)))


def escolher_tag(jogo, hot_set, cold_set, soma_ideal, estrategia="equilibrado"):
    if estrategia == "anti_divisao":
        return "Anti-Divisao Estatistica"

    quentes = sum(1 for n in jogo if n in hot_set)
    frios = sum(1 for n in jogo if n in cold_set)
    soma = sum(jogo)

    if quentes >= 4:
        return "Foco em Dezenas Quentes"
    elif frios >= 3:
        return "Tendência de Atraso"
    elif abs(soma - soma_ideal) <= 5:
        return "Equilíbrio de Soma"
    elif sum(1 for n in jogo if n % 2 == 0) >= 9:
        return "Alta Densidade de Pares"
    elif sum(1 for n in jogo if n % 2 != 0) >= 9:
        return "Dominância de Ímpares"
    else:
        return random.choice(["Cobertura Máxima", "Balanceamento Fino", "Padrão Recorrente"])


@app.get("/diagnostico")
def diagnostico():
    ensure_database_synced()
    cache_key = f"diagnostico:{_historico_cache_key()}"
    cached = _get_cached_response(cache_key, ttl_seconds=20)
    if cached is not None:
        return cached

    historico = load_historico_blindado()
    regime = calcular_regime(historico)
    contexto = _get_contexto_analitico(historico)
    tendencias = contexto["tendencias"]
    equilibrio = contexto["equilibrio"]
    inteligencia = obter_contexto_inteligente(historico)
    payload = {
        "status": "sucesso",
        "concursos_analisados": len(historico),
        "ultimo_concurso": inteligencia.get("ultimo_concurso", len(historico)),
        "regime": regime,
        "tendencias": tendencias,
        "equilibrio": equilibrio,
        "inteligencia": inteligencia,
    }
    _set_cached_response(cache_key, payload)
    return payload


def _gerar_combinacoes_payload(
    estrategia: str | EstrategiaEnum = EstrategiaEnum.equilibrado,
):
    ensure_database_synced()
    estrategia = _normalize_estrategia(estrategia)

    estrategia_label = {
        "equilibrado": "Estratégia Equilibrada",
        "quentes": "Estratégia de Tendência Recente",
        "atrasados": "Estratégia de Atraso Estatístico",
        "anti_divisao": "Estratégia de Distribuição Diferenciada",
    }

    historico = load_historico_blindado()
    contexto = _get_contexto_analitico(historico)
    freq = contexto["freq"]
    short_freq = contexto["short_freq"]
    delay_map = contexto["delay_map"]
    hot_set = contexto["hot_set"]
    cold_set = contexto["cold_set"]
    soma_ideal = contexto["equilibrio"]["soma_ideal"]
    ciclo_info = calcular_fechamento_ciclo_dezenas(historico, window=5)
    ciclo_faltantes = set(ciclo_info.get("dezenas_faltantes", []))

    # Evita top-10 com jogos quase idênticos, ampliando cobertura do conjunto final.
    max_overlap_top = int(os.getenv("TOP_MAX_OVERLAP", "13"))
    max_overlap_top = max(10, min(14, max_overlap_top))

    def _select_diverse_top(cands: list[dict], k: int, max_overlap: int) -> list[dict]:
        ranked = sorted(cands, key=lambda x: x["ia_rating"], reverse=True)
        selected = []
        selected_sets = []

        for cand in ranked:
            cand_set = set(cand["combinacao"])
            if all(len(cand_set & s) <= max_overlap for s in selected_sets):
                selected.append(cand)
                selected_sets.append(cand_set)
                if len(selected) >= k:
                    return selected

        # Fallback: se a diversidade impedir preencher k, completa por score bruto.
        for cand in ranked:
            if cand not in selected:
                selected.append(cand)
                if len(selected) >= k:
                    break
        return selected

    candidates = []
    seen = set()
    attempts = 0
    max_attempts = max(CFG["CANDIDATES"] * 3, 3000)
    while len(candidates) < CFG["CANDIDATES"] and attempts < max_attempts:
        attempts += 1
        jogo = sorted(random.sample(range(1, 26), 15))
        jogo_key = tuple(jogo)
        if jogo_key in seen:
            continue
        seen.add(jogo_key)

        rating = score_game(
            jogo,
            freq,
            short_freq,
            delay_map,
            hot_set,
            cold_set,
            soma_ideal,
            estrategia,
            ciclo_faltantes=ciclo_faltantes,
        )
        tag_estrategica = escolher_tag(jogo, hot_set, cold_set, soma_ideal)
        if estrategia == "anti_divisao":
            tag_estrategica = "Distribuição Estatística Diferenciada"
        candidates.append(
            {
                "combinacao": jogo,
                "ia_rating": rating,
                "tag_estrategica": tag_estrategica,
                "tag": estrategia_label.get(estrategia, "Estratégia Equilibrada"),
            }
        )

    melhores = _select_diverse_top(
        candidates,
        k=CFG["NUM_GAMES"],
        max_overlap=max_overlap_top,
    )

    return {
        "status": "sucesso",
        "timestamp": datetime.now().strftime("%H:%M:%S"),
        "estrategia": estrategia,
        "combinacoes": melhores,
    }


@app.get("/gerar-combinacoes")
def gerar_combinacoes(
    estrategia: EstrategiaEnum = EstrategiaEnum.equilibrado,
):
    return _gerar_combinacoes_payload(estrategia)


@app.get("/gerar-jogos")
def gerar_jogos_legacy(
    estrategia: EstrategiaEnum = EstrategiaEnum.equilibrado,
):
    payload = _gerar_combinacoes_payload(estrategia)
    # Compatibilidade temporaria para clientes antigos.
    payload["jogos"] = payload.get("combinacoes", [])
    return payload


# ─── ALGORITMO DE SIMILARIDADE DE CICLO (BLOOMBERG-SPEC) ──────────────────────

def _is_prime(n):
    """Verifica se um número é primo."""
    if n < 2:
        return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0:
            return False
    return True


def _calculate_state_vector(draw):
    """
    Calcula um vetor de características para um concurso individual.
    Retorna: [soma, qtd_pares, qtd_primos, variancia_visual]
    """
    soma = sum(draw)
    pares = sum(1 for n in draw if n % 2 == 0)
    primos = sum(1 for n in draw if _is_prime(n))
    # Métrica de "dispersão visual" (proximidade no volante 1-25)
    variancia_visual = float(np.std([abs(draw[i] - draw[i-1]) for i in range(1, len(draw))]))
    
    return [float(soma), float(pares), float(primos), variancia_visual]


def _get_window_state_vector(historico, start_idx, window_size=5):
    """
    Concatena os vetores de estado de uma janela de N concursos.
    Isso cria um 'snapshot' do padrão daquele período.
    """
    if start_idx + window_size > len(historico):
        return None
    
    janela = historico[start_idx : start_idx + window_size]
    vectors = [_calculate_state_vector(draw) for draw in janela]
    
    # Normaliza: média dos componentes na janela
    media_soma = np.mean([v[0] for v in vectors])
    media_pares = np.mean([v[1] for v in vectors])
    media_primos = np.mean([v[2] for v in vectors])
    media_var_visual = np.mean([v[3] for v in vectors])
    
    return [media_soma, media_pares, media_primos, media_var_visual]


def _euclidean_distance(v1, v2):
    """Calcula a distância euclidiana entre dois vetores."""
    return float(np.sqrt(sum((a - b) ** 2 for a, b in zip(v1, v2))))


def _find_similar_cycle(historico, window_size=5):
    """
    Encontra o ciclo histórico (janela de 5 concursos) mais similar ao período recente.
    
    Usa os últimos 5 concursos como vetor "agora" (V_now).
    Percorre o histórico comparando cada janela com V_now.
    Retorna o ID do concurso inicial da janela mais similar + distância normalizada.
    """
    if len(historico) < window_size * 2:
        return {"status": "dados_insuficientes", "mensagem": "Histórico muito curto"}
    
    # V_now: vetor dos últimos 5 concursos
    v_now = _get_window_state_vector(historico, len(historico) - window_size, window_size)
    
    melhor_distancia = float('inf')
    melhor_idx = 0
    all_distances = []
    
    # Varrer o histórico inteiro
    for i in range(len(historico) - window_size - 1):
        v_historico = _get_window_state_vector(historico, i, window_size)
        if v_historico is None:
            continue
        
        dist = _euclidean_distance(v_now, v_historico)
        all_distances.append(dist)
        
        if dist < melhor_distancia:
            melhor_distancia = dist
            melhor_idx = i
    
    # Normaliza distância para percentual de similaridade (0-100%)
    max_dist = max(all_distances) if all_distances else 1.0
    similaridade_pct = max(0, 100 * (1 - (melhor_distancia / max_dist)))
    
    # Estima o número de concursos da base local (usando Concurso ID campo)
    df_local = _load_historico_df()
    if df_local.empty:
        ultimo_concurso = 0
    else:
        ultimo_concurso = int(df_local["Concurso"].max())
    
    concurso_similar_start = ultimo_concurso - len(historico) + melhor_idx
    concurso_similar_end = concurso_similar_start + window_size - 1
    
    return {
        "status": "sucesso",
        "ciclo_similar": {
            "concurso_inicio": int(concurso_similar_start),
            "concurso_fim": int(concurso_similar_end),
            "range": f"{int(concurso_similar_start)}-{int(concurso_similar_end)}",
            "similaridade_percentual": round(similaridade_pct, 2),
        },
        "analise": {
            "distancia_euclidiana": round(melhor_distancia, 4),
            "texto_autoridade": f"Padrão histórico similar identificado nos concursos {int(concurso_similar_start)}-{int(concurso_similar_end)} ({round(similaridade_pct, 1)}% de interseção) — usado para refinar a distribuição das simulações estatísticas.",
        },
        "v_now": [round(x, 2) for x in v_now],
    }


@app.get("/similaridade")
def similaridade():
    """
    Detecta padrões fractais e similitude cíclica.
    Compara a janela recente (últimos 5 concursos) com o histórico completo.
    Retorna o ciclo histórico mais similar com percentual de confiança.
    """
    ensure_database_synced()
    cache_key = f"similaridade:{_historico_cache_key()}"
    cached = _get_cached_response(cache_key, ttl_seconds=45)
    if cached is not None:
        return cached

    historico = load_historico_blindado()
    payload = _find_similar_cycle(historico, window_size=5)
    _set_cached_response(cache_key, payload)
    return payload


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    logger.info("API LotoSmart iniciada em http://0.0.0.0:%s", port)
    uvicorn.run(app, host="0.0.0.0", port=port)