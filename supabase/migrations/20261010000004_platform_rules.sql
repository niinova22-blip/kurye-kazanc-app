-- Kurye Kazanc 1.5: planlama motoru kurallari (spec docs/superpowers/specs/2026-10-10-planlama-motoru-design.md §2).
-- Kurallar kaynakli ve surumlu: degisiklik ayni id ile yeni version satiri olarak eklenir, eski satir silinmez (gecmis).
-- Kaynak degisikligi otomatik kabul edilmez: check_sources.mjs yalnizca rule_source_checks'e "pending" yazar,
-- yonetici approve_rule.mjs ile yeni surumu ekler. Tekrar calistirilabilir.

create table if not exists public.platform_rules (
    id text not null,
    version integer not null check (version >= 1),
    platform_code text not null,
    category text not null,
    kind text not null,
    params jsonb not null default '{}'::jsonb,
    description text not null,
    source_url text,
    source_kind text not null check (source_kind in ('official','secondary','user')),
    published_on date,
    last_checked_on date not null,
    valid_from date,
    valid_to date,
    status text not null check (status in ('verified','unverified','disputed','stale')),
    confidence numeric not null check (confidence >= 0 and confidence <= 1),
    courier_model text not null default 'any' check (courier_model in ('esnaf','intermediary','payroll','any')),
    region text,
    previous_id text,
    approved_by text,
    created_at timestamptz not null default now(),
    primary key (id, version)
);

create table if not exists public.rule_source_checks (
    id bigint generated always as identity primary key,
    source_url text not null,
    rule_ids text[] not null default '{}',
    checked_at timestamptz not null default now(),
    http_status integer,
    content_hash text,
    previous_hash text,
    changed boolean not null default false,
    review_status text not null default 'pending' check (review_status in ('pending','approved','ignored','unchanged','error')),
    note text
);
create index if not exists rule_source_checks_url_idx on public.rule_source_checks (source_url, checked_at desc);

alter table public.platform_rules enable row level security;
alter table public.rule_source_checks enable row level security;

-- Kurallar herkese acik okunur (istemci en yuksek version'i kullanir). Yazma yalnizca servis rolu / yonetim betikleri.
drop policy if exists platform_rules_read on public.platform_rules;
create policy platform_rules_read on public.platform_rules for select to anon, authenticated using (true);

revoke all on public.platform_rules, public.rule_source_checks from anon, authenticated;
grant select on public.platform_rules to anon, authenticated;
