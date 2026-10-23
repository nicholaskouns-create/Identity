"""Offline, deterministic migration from a JSON SQL export to Mnemosyne archive.

Input format: {"tables":{"public.source_artifacts":[{...}], ...}}
No database credentials, network calls, or implicit publication.
"""
import argparse,hashlib,json,uuid
from datetime import datetime,timezone
from pathlib import Path

FORMAT="mnemosyne-archive-v1"
def canonical(r):
    return json.dumps([r[k] for k in ("id","title","kind","content","created_at")],ensure_ascii=False,separators=(",",":"))
def convert(source):
    if not isinstance(source,dict) or not isinstance(source.get("tables"),dict):
        raise ValueError("Expected tables object")
    records=[]
    for table,rows in sorted(source["tables"].items()):
        if not isinstance(rows,list): raise ValueError("Table rows must be a list")
        for index,row in enumerate(rows):
            if not isinstance(row,dict):raise ValueError("Row must be an object")
            source_key=str(row.get("id",index))
            title=f"{table} · {source_key}"
            kind=str(row.get("status") or row.get("evidence_class") or "unverified")
            if kind not in {"proven","numerically_tested","hypothesis","refuted","unverified","historical"}:kind="unverified"
            record={"id":str(uuid.uuid5(uuid.NAMESPACE_URL,f"mnemosyne:{table}:{source_key}")),
                    "title":title,"kind":kind,
                    "content":json.dumps({"source_table":table,"source_row":row},ensure_ascii=False,sort_keys=True,separators=(",",":")),
                    "created_at":str(row.get("created_at") or row.get("recorded_at") or "1970-01-01T00:00:00Z")}
            record["sha256"]=hashlib.sha256(canonical(record).encode("utf-8")).hexdigest()
            records.append(record)
    return {"format":FORMAT,"records":records,"manifest":{"source_tables":{k:len(v) for k,v in sorted(source["tables"].items())},"record_count":len(records)}}
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("input",type=Path)
    ap.add_argument("output",type=Path)
    args=ap.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[1]):
        raise SystemExit("Refusing to write exported records inside repository")
    data=convert(json.loads(args.input.read_text(encoding="utf-8")))
    args.output.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"CONVERTED {data['manifest']['record_count']} records; output is PRIVATE, do not commit")
if __name__=="__main__":main()
