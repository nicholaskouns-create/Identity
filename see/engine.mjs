// SEE/1.0 · local-first evidence retrieval. Relevance is never a probability of truth.
export const SCHEMA = "SEE-EVIDENCE/1.0";
const STOP = new Set("a an the and or but if to of in on by for at with from is are was were be been being i you he she we they it this that these those my your our their me about what who how why does do did tell show say think know can could should would please not no as have has had".split(" "));
export function tokens(input) {
  return [...new Set(String(input||"").toLowerCase().normalize("NFKC").match(/[\p{L}\p{N}]{2,}/gu)||[])].filter(w=>!STOP.has(w));
}
export function newRecord(text,source="Personal note",kind="user-supplied",url="",id="") {
  const statement=String(text||"").trim().slice(0,2500);
  if(!statement) throw Error("An evidence statement is required.");
  if(!["user-supplied","repository","external","computed","inferred"].includes(kind)) throw Error("Invalid evidence category.");
  const link=String(url||"").trim();
  if(link && !/^https:\/\/[^ \n<>]+$/i.test(link)) throw Error("Only HTTPS source URLs are supported.");
  return {id:id||("SEE-"+crypto.randomUUID()),statement,source:String(source||"Personal note").slice(0,160),kind,url:link,created_at:new Date().toISOString()};
}
export function rank(question,records,limit=5) {
  const q=tokens(question); if(!q.length) return [];
  return records.map(r=>{
    const rt=tokens(r.statement+" "+r.source);
    const intersection=q.filter(t=>rt.includes(t)).length;
    const coverage=intersection/q.length;
    // Ranked retrieval, not confidence or truth.
    return {record:r,matching:intersection,coverage};
  }).filter(x=>x.matching>0).sort((a,b)=>b.matching-a.matching||b.coverage-a.coverage||a.record.id.localeCompare(b.record.id)).slice(0,limit);
}
export function tensions(records) {
  const out=[]; const neg=/\b(no|not|never|cannot|can't|didn't|doesn't|false|failed|unsupported|without)\b/i;
  for(let i=0;i<records.length;i++) for(let j=i+1;j<records.length;j++){
    const a=tokens(records[i].statement),b=tokens(records[j].statement);
    const shared=a.filter(w=>b.includes(w));
    if(shared.length>=2 && neg.test(records[i].statement)!==neg.test(records[j].statement))
      out.push({a:records[i].id,b:records[j].id,shared:shared.slice(0,5)});
  }
  return out.slice(0,30);
}
export function reflect(question,records) {
  const hits=rank(question,records);
  if(!hits.length)return {status:"INSUFFICIENT EVIDENCE",text:"I cannot infer that from the evidence currently in your mirror. Add a first-person statement, source, or record; See will distinguish what it can cite from what it cannot.",hits:[]};
  const lines=hits.map((h,i)=>"["+(i+1)+"] "+h.record.statement);
  return {status:"SOURCE-BOUND",text:"What I can reflect from the available records:\n\n"+lines.join("\n\n")+"\n\nThese are source statements, not independent verification. You can edit or contest any record.",hits};
}
export function exportArchive(records) {
  return JSON.stringify({schema:SCHEMA,exported_at:new Date().toISOString(),records},null,2);
}
export function importArchive(text) {
  let obj;
  try{obj=JSON.parse(text)}catch{throw Error("Invalid JSON.");}
  const rows=Array.isArray(obj)?obj:obj?.schema===SCHEMA?obj.records:null;
  if(!Array.isArray(rows)||rows.length>2000)throw Error("Expected SEE-EVIDENCE/1.0 archive or an array of ≤2000 records.");
  return rows.map((r,i)=>{
    if(typeof r==="string")return newRecord(r,"Imported text","user-supplied");
    if(!r||typeof r.statement!=="string")throw Error("Record "+(i+1)+" lacks a statement.");
    const kind=["user-supplied","repository","external","computed","inferred"].includes(r.kind)?r.kind:"user-supplied";
    return newRecord(r.statement,r.source,kind,r.url,String(r.id||""));
  });
}
export function sourceContext(hits) {
 return hits.map((h,i)=>"["+(i+1)+"] ("+h.record.kind+"; "+h.record.source+(h.record.url?"; "+h.record.url:"")+") "+h.record.statement).join("\n");
}