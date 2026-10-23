-- Applied to existing project. No public storage policies are created.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('mnemosyne-private','mnemosyne-private',false,52428800,
array['application/pdf','text/plain','text/markdown','application/json','text/html','application/octet-stream'])
on conflict (id) do nothing;
insert into mnemosyne_private.proof_records(claim,status,code_commit)
values ('For H=V₂⊗³ and Γ=I−K²/99144, ||Γⁿ−P||₂=(15/17)ⁿ for n≥0.',
'proven','c7dbedb7dc797d9ffee5bde430177c0b202c6d51');
insert into mnemosyne_private.provenance_links(source_uri,target_uri,relation)
values
('https://github.com/nicholaskouns-create/E47-Kartekeya','https://github.com/nicholaskouns-create/Identity','mathematical_source'),
('https://github.com/nicholaskouns-create/Time','https://github.com/nicholaskouns-create/Identity','clock_source'),
('https://github.com/nicholaskouns-create/tower','https://github.com/nicholaskouns-create/Identity','tower_source');
