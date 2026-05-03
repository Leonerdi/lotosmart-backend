import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

NEON_URL = 'postgresql://neondb_owner:npg_eRD4sabfq1VZ@ep-twilight-cherry-acdqd6sy.sa-east-1.aws.neon.tech/neondb?sslmode=require'

df = pd.read_csv('historico.csv')
rows = [tuple(int(row[c]) for c in df.columns) for _, row in df.iterrows()]

print(f'Conectando ao Neon...')
conn = psycopg2.connect(NEON_URL, connect_timeout=15)
cur = conn.cursor()

print(f'Importando {len(rows)} registros...')
execute_values(
    cur,
    'INSERT INTO historico_lotofacil (concurso,bola1,bola2,bola3,bola4,bola5,bola6,bola7,bola8,bola9,bola10,bola11,bola12,bola13,bola14,bola15) VALUES %s ON CONFLICT (concurso) DO NOTHING',
    rows,
    page_size=500
)
conn.commit()

cur.execute('SELECT COUNT(*) FROM historico_lotofacil')
count = cur.fetchone()[0]
cur.close()
conn.close()
print(f'✓ Importados com sucesso. Total no Neon: {count} registros')
