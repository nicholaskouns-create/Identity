"""Read-only, private metadata search for Mnemosyne's registered documents.

Trusted operator use only: MNEMOSYNE_DB_DSN=... python search.py QUERY
No public HTTP endpoint, API key, database credential, or document bytes are
exposed. Requires a PostgreSQL login with SELECT on the unexposed
mnemosyne_private.source_documents table. Search is metadata-only.
"""
import argparse
import json
import os
import re

SEARCH_SQL = """
SELECT id, title, source_sha256, evidence_class, recorded_at
FROM mnemosyne_private.source_documents
WHERE title ILIKE %s ESCAPE '!'
   OR coalesce(metadata->>'description', '') ILIKE %s ESCAPE '!'
   OR source_sha256 = %s
ORDER BY recorded_at DESC, id DESC
LIMIT %s
"""


def search_documents(connection, query, *, limit=20):
    if not isinstance(query, str):
        raise ValueError("Query must be text")
    term = query.strip()
    if not 1 <= len(term) <= 160 or any(ord(c) < 32 or ord(c) == 127 for c in term):
        raise ValueError("Query must contain 1–160 printable characters")
    if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= 100:
        raise ValueError("Limit must be an integer from 1 to 100")
    escaped = term.replace('!', '!!').replace('%', '!%').replace('_', '!_')
    pattern = '%' + escaped + '%'
    digest = term.lower() if re.fullmatch(r'[0-9a-fA-F]{64}', term) else None
    with connection.transaction():
        with connection.cursor() as cursor:
            cursor.execute('SET TRANSACTION READ ONLY')
            cursor.execute("SET LOCAL statement_timeout = '5000ms'")
            cursor.execute(SEARCH_SQL, (pattern, pattern, digest, limit))
            rows = cursor.fetchall()
    return [
        {'id': str(row[0]), 'title': row[1], 'source_sha256': row[2],
         'evidence_class': row[3], 'recorded_at': row[4].isoformat()}
        for row in rows
    ]


def main(argv=None):
    parser = argparse.ArgumentParser(description='Private Mnemosyne document metadata search')
    parser.add_argument('query', help='Title, description or exact SHA-256 digest')
    parser.add_argument('--limit', type=int, default=20)
    args = parser.parse_args(argv)
    dsn = os.environ.get('MNEMOSYNE_DB_DSN')
    if not dsn:
        raise RuntimeError('MNEMOSYNE_DB_DSN required in trusted environment')
    try:
        import psycopg
    except ImportError as exc:
        raise RuntimeError('Install psycopg[binary] in trusted worker environment') from exc
    with psycopg.connect(dsn) as connection:
        result = search_documents(connection, args.query, limit=args.limit)
    print(json.dumps({'count': len(result), 'documents': result}, ensure_ascii=False))


if __name__ == '__main__':
    main()
