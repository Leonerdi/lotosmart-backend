import pandas as pd
import numpy as np
import random
import os
import logging
import time
import threading
import requests
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta, timezone
from collections import Counter, deque
from itertools import combinations

try:
    from zoneinfo import ZoneInfo
except Exception:  # pragma: no cover - fallback defensivo
    ZoneInfo = None

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
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
}

CSV_PATH = "historico.csv"
API_BASE = "https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil"
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

_api_session = requests.Session()
_api_session.headers.update(API_HEADERS)

_sync_lock = threading.Lock()
_cache_lock = threading.Lock()
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


def _historico_cache_key() -> tuple:
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


@app.middleware("http")
async def request_metrics_middleware(request, call_next):
    start = time.perf_counter()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = int(response.status_code)
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
    if not os.path.exists(CSV_PATH):
        return pd.DataFrame(columns=CSV_COLUMNS)

    try:
        df = pd.read_csv(CSV_PATH)
        df = _padronizar_colunas_historico(df)

        # Se houver colunas extras, preservamos apenas o formato esperado.
        for col in CSV_COLUMNS:
            if col not in df.columns:
                df[col] = np.nan

        df = df[CSV_COLUMNS]
        df["Concurso"] = pd.to_numeric(df["Concurso"], errors="coerce")
        df = df.dropna(subset=["Concurso"])
        df["Concurso"] = df["Concurso"].astype(int)
        return df
    except Exception as e:
        logger.exception("Falha ao carregar historico.csv. Seguindo com base vazia. Erro: %s", e)
        return pd.DataFrame(columns=CSV_COLUMNS)


def _fetch_api_json(url: str) -> dict:
    """Busca JSON com timeout e validação HTTP."""
    response = _api_session.get(url, timeout=10)
    response.raise_for_status()
    return response.json()


def _fetch_latest_payload() -> dict:
    """Busca o concurso mais recente com fallback entre contratos da API da Caixa."""
    errors = []
    for url in (API_BASE, f"{API_BASE}/ultimo"):
        try:
            return _fetch_api_json(url)
        except requests.RequestException as e:
            errors.append(f"{url}: {e}")
    raise requests.HTTPError(" | ".join(errors))


def _try_fetch_concurso_payload(concurso: int) -> dict | None:
    """Tenta buscar um concurso específico; retorna None quando não existe."""
    try:
        return _fetch_api_json(f"{API_BASE}/{concurso}")
    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else None
        if status in (400, 404, 500, 502, 503, 504):
            return None
        raise


def _resolve_latest_concurso(ultimo_local: int) -> int:
    """Resolve o último concurso real com sondagem incremental para evitar cache defasado."""
    base_payload = _fetch_latest_payload()
    latest = int(base_payload["numero"])

    # Algumas APIs podem devolver um "último" atrasado por cache. Sondamos alguns
    # concursos à frente para capturar publicação recém-disponível.
    probe = max(latest, ultimo_local)
    max_probe_ahead = 12
    for i in range(1, max_probe_ahead + 1):
        payload = _try_fetch_concurso_payload(probe + i)
        if payload is None:
            break
        latest = int(payload["numero"])

    return latest


def _row_from_api_payload(payload: dict) -> dict:
    """Converte payload da API externa no formato Concurso, Bola1..Bola15."""
    numero = int(payload["numero"])
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
    Sincroniza o historico.csv com os concursos mais recentes da API.
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
        for concurso in range(ultimo_local + 1, ultimo_api + 1):
            try:
                payload = _fetch_api_json(f"{API_BASE}/{concurso}")
                novos_rows.append(_row_from_api_payload(payload))
            except Exception as e:
                # Falha pontual não derruba o sync completo.
                logger.warning("Sync: falha ao buscar concurso %s: %s", concurso, e)

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

        df_total.to_csv(CSV_PATH, index=False)
        _invalidate_runtime_cache()

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

    if not os.path.exists(CSV_PATH):
        print(f"AVISO: {CSV_PATH} não encontrado. Usando dados temporários.")
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
        print(f"Erro ao processar o CSV local: {e}")
        historico_tmp = [sorted(random.sample(range(1, 26), 15)) for _ in range(300)]
        with _cache_lock:
            _runtime_cache["historico"] = {"key": cache_key, "data": historico_tmp}
        return historico_tmp


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
    result = ensure_database_synced(force=True)
    logger.info("Startup sync result: %s", result)


@app.get("/admin/sync")
def admin_sync():
    """Força sincronização manual sem derrubar o serviço em caso de erro."""
    return ensure_database_synced(force=True)


@app.get("/healthz")
def healthz():
    """Healthcheck leve para orquestrador e monitoramento."""
    return {
        "status": "ok",
        "sync_status": _last_sync_result.get("status", "unknown"),
        "csv_disponivel": os.path.exists(CSV_PATH),
        "metrics": _snapshot_metrics(),
    }


@app.get("/ops/metrics")
def ops_metrics():
    """Métricas operacionais básicas para gatilhos de escala."""
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


def score_game(jogo, freq, short_freq, delay_map, hot_set, cold_set, soma_ideal, estrategia="equilibrado"):
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
        # Inverte a lógica para priorizar dezenas mais atrasadas
        total = (freq_pts * 0.6) + (short_base_pts * 0.5) + (hot_pts * 0.4) + cold_pts + atraso_pts + soma_pts + equil_pts
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


@app.get("/gerar-jogos")
def gerar(estrategia: str = "equilibrado"):
    ensure_database_synced()
    estrategia = (estrategia or "equilibrado").lower().strip()
    if estrategia not in {"equilibrado", "quentes", "atrasados", "anti_divisao"}:
        estrategia = "equilibrado"

    historico = load_historico_blindado()
    contexto = _get_contexto_analitico(historico)
    freq = contexto["freq"]
    short_freq = contexto["short_freq"]
    delay_map = contexto["delay_map"]
    hot_set = contexto["hot_set"]
    cold_set = contexto["cold_set"]
    soma_ideal = contexto["equilibrio"]["soma_ideal"]

    candidates = []
    for _ in range(CFG["CANDIDATES"]):
        jogo = sorted(random.sample(range(1, 26), 15))
        rating = score_game(
            jogo,
            freq,
            short_freq,
            delay_map,
            hot_set,
            cold_set,
            soma_ideal,
            estrategia,
        )
        tag_estrategica = escolher_tag(jogo, hot_set, cold_set, soma_ideal)
        if estrategia == "anti_divisao":
            tag_estrategica = "Anti-Divisao Estatistica"
        candidates.append(
            {
                "jogo": jogo,
                "ia_rating": rating,
                "tag_estrategica": tag_estrategica,
                "tag": f"Estratégia Aplicada: {estrategia.capitalize()}",
            }
        )

    melhores = sorted(candidates, key=lambda x: x["ia_rating"], reverse=True)[:CFG["NUM_GAMES"]]

    return {
        "status": "sucesso",
        "timestamp": datetime.now().strftime("%H:%M:%S"),
        "estrategia": estrategia,
        "jogos": melhores,
    }


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
            "texto_autoridade": f"Padrão Fractal detectado: Similaridade de {round(similaridade_pct, 1)}% com o Ciclo dos Concursos {int(concurso_similar_start)}-{int(concurso_similar_end)}.",
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
    print(f"API LotoSmart iniciada em http://0.0.0.0:{port}")
    uvicorn.run(app, host="0.0.0.0", port=port)