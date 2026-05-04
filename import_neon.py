import os

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values


NEON_URL = os.getenv("NEON_URL", "").strip()

if not NEON_URL:
    raise RuntimeError("Defina NEON_URL no ambiente antes de executar este script.")

df = pd.read_csv("historico.csv")
rows = [tuple(int(row[column]) for column in df.columns) for _, row in df.iterrows()]

print("Conectando ao Neon...")
conn = psycopg2.connect(NEON_URL, connect_timeout=15)
cur = conn.cursor()

print(f"Importando {len(rows)} registros...")
execute_values(
    cur,
    "INSERT INTO historico_lotofacil (concurso,bola1,bola2,bola3,bola4,bola5,bola6,bola7,bola8,bola9,bola10,bola11,bola12,bola13,bola14,bola15) VALUES %s ON CONFLICT (concurso) DO NOTHING",
    rows,
    page_size=500,
)
conn.commit()

cur.execute("SELECT COUNT(*) FROM historico_lotofacil")
count = cur.fetchone()[0]
cur.close()
conn.close()
print(f"Importados com sucesso. Total no Neon: {count} registros")
