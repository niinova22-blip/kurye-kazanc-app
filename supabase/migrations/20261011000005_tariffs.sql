-- Kurye Kazanc 1.6: surumlu hakedis tarifeleri ve dinamik tarife takibi (Katman B).
-- Ilke: kaynakta degisiklik tarifeyi kendiliginden degistirmez. Kontrol -> aday -> dogrulama/onay -> yayim.
-- Yayim ve geri cekme yalnizca bu dosyadaki fonksiyonlarla, tek islemde (atomik) ve tekrarlanabilir (idempotent).
-- Istemci (anon/authenticated) yalnizca yayindaki surumleri, kalemlerini ve degisiklik olaylarini okur.
-- Tekrar calistirilabilir.

create table if not exists public.tariff_platforms (
    platform_id text primary key,
    platform_name text not null,
    active_status boolean not null default true,
    supported_work_models text[] not null default '{esnaf}',
    last_successful_check_at timestamptz,
    next_scheduled_check_at timestamptz
);

create table if not exists public.tariff_versions (
    tariff_version_id text primary key,
    platform_id text not null references public.tariff_platforms (platform_id),
    work_model text not null default 'esnaf',
    region_id text,
    vehicle_type text,
    version_number integer not null check (version_number >= 1),
    revision integer not null default 0,
    effective_from date not null,
    effective_until date,
    created_at timestamptz not null default now(),
    source_type text not null check (source_type in ('official_announcement','official_channel','official_document','news',
        'user_upload','courier_reports','user_entered','seed')),
    verification_status text not null check (verification_status in ('verified','partial','unverified')),
    approval_status text not null check (approval_status in ('draft','pending_verification','needs_more_sources','approved',
        'published','rejected','expired','withdrawn')),
    approved_at timestamptz,
    approved_by text,
    change_summary text,
    settings jsonb not null default '{}'::jsonb,
    check (effective_until is null or effective_until > effective_from)
);
create unique index if not exists tariff_versions_scope_idx on public.tariff_versions
    (platform_id, work_model, coalesce(region_id, ''), coalesce(vehicle_type, ''), version_number);

create table if not exists public.tariff_items (
    tariff_item_id text primary key,
    tariff_version_id text not null references public.tariff_versions (tariff_version_id),
    item_key text not null,
    item_type text not null check (item_type in ('single_package','combined_package','per_km','hourly','fixed','daily_bonus',
        'weekly_bonus','monthly_bonus','surge_multiplier','fuel_equipment_support','tip','referral_bonus','deduction',
        'in_kind_support','other_payment')),
    label text not null,
    amount numeric(14,2) not null,
    amount_upper numeric(14,2),
    currency text not null default 'TRY',
    unit text not null,
    lower_threshold numeric(14,3),
    upper_threshold numeric(14,3),
    calculation_method text not null,
    eligibility_conditions jsonb not null default '{}'::jsonb,
    stacking_rule text not null default 'additive',
    item_group text,
    effective_from date,
    effective_until date,
    confidence_status text not null check (confidence_status in ('verified','user_entered','needs_verification')),
    is_cash boolean not null default true,
    note text,
    withdrawn boolean not null default false,
    supersedes_item_id text references public.tariff_items (tariff_item_id),
    candidate_id text,
    created_at timestamptz not null default now()
);
create index if not exists tariff_items_version_idx on public.tariff_items (tariff_version_id, item_key);

create table if not exists public.tariff_sources (
    source_id text primary key,
    platform_id text not null references public.tariff_platforms (platform_id),
    tariff_version_id text references public.tariff_versions (tariff_version_id),
    url text,
    document_ref text,
    source_type text not null check (source_type in ('official_announcement','official_channel','official_document','news',
        'user_upload','courier_reports')),
    -- 1 resmi duyuru ... 6 kurye bildirimi (kaynak oncelik sirasi)
    priority integer not null check (priority between 1 and 6),
    check_interval_minutes integer not null default 1440 check (check_interval_minutes >= 60),
    -- [{"item_key": "...", "pattern": "regex (1. grup tutar)", "field": "amount"}]; bos ise yalnizca icerik ozeti izlenir
    extraction_profile jsonb not null default '[]'::jsonb,
    active boolean not null default true,
    first_seen_at timestamptz not null default now(),
    published_on date,
    effective_on date,
    last_checked_at timestamptz,
    last_success_at timestamptz,
    summary text,
    content_hash text,
    reliability text not null default 'unknown' check (reliability in ('high','medium','low','unknown')),
    previous_source_id text references public.tariff_sources (source_id),
    -- Ayni kaynagi ayni anda iki calisma kontrol etmesin
    lock_until timestamptz,
    check (url is not null or document_ref is not null)
);

create table if not exists public.tariff_source_checks (
    check_id bigint generated always as identity primary key,
    source_id text not null references public.tariff_sources (source_id),
    checked_at timestamptz not null default now(),
    result text not null check (result in ('changed','unchanged','unreachable','unreadable','needs_verification','new_candidate')),
    http_status integer,
    content_hash text,
    previous_hash text,
    extracted jsonb,
    ocr_confidence numeric,
    candidate_id text,
    note text,
    run_id text
);
create index if not exists tariff_source_checks_source_idx on public.tariff_source_checks (source_id, checked_at desc);

create table if not exists public.tariff_candidates (
    candidate_id text primary key default gen_random_uuid()::text,
    platform_id text not null references public.tariff_platforms (platform_id),
    tariff_version_id text not null references public.tariff_versions (tariff_version_id),
    -- Ayni degisiklik iki kez aday / yayim olmaz
    fingerprint text not null unique,
    status text not null check (status in ('draft','pending_verification','needs_more_sources','approved','published',
        'rejected','expired','withdrawn')),
    changes jsonb not null,
    effective_from date,
    effective_date_certain boolean not null default false,
    source_ids text[] not null default '{}',
    source_types text[] not null default '{}',
    ocr_confidence numeric,
    requires_human boolean not null default true,
    reasons text[] not null default '{}',
    verification text not null default 'needs_verification' check (verification in ('verified','needs_verification')),
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    decided_by text,
    decided_at timestamptz,
    published_at timestamptz
);

-- Yayim/geri cekme sirasinda dokunulan kalemler: geri cekmede onceki gecerlilik geri yuklenir.
create table if not exists public.tariff_item_revisions (
    candidate_id text not null references public.tariff_candidates (candidate_id),
    tariff_item_id text not null references public.tariff_items (tariff_item_id),
    action text not null check (action in ('closed','inserted')),
    previous_effective_until date,
    primary key (candidate_id, tariff_item_id)
);

create table if not exists public.tariff_audit_log (
    audit_id bigint generated always as identity primary key,
    at timestamptz not null default now(),
    actor text not null,
    action text not null,
    entity text not null,
    entity_id text not null,
    before jsonb,
    after jsonb,
    note text
);

create table if not exists public.tariff_change_events (
    event_id bigint generated always as identity primary key,
    platform_id text not null references public.tariff_platforms (platform_id),
    tariff_version_id text not null references public.tariff_versions (tariff_version_id),
    candidate_id text,
    kind text not null check (kind in ('published','withdrawn')),
    effective_from date,
    verification text not null check (verification in ('verified','needs_verification')),
    source_type text,
    source_url text,
    changes jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now()
);

-- Istege bagli ekonomik gostergeler: yalnizca uyari uretir, tarife tablolarina hic yazmaz.
create table if not exists public.economic_indicators (
    indicator_id bigint generated always as identity primary key,
    kind text not null check (kind in ('minimum_wage','cpi','fuel_price')),
    value numeric not null,
    unit text not null,
    period text,
    source_url text,
    fetched_at timestamptz not null default now(),
    note text
);

-- Takip ayarlari (yapilandirilabilir siklik ve otomatik yayim esikleri).
create table if not exists public.tariff_config (
    key text primary key,
    value jsonb not null
);
insert into public.tariff_config (key, value) values
    ('auto_publish_official', 'false'::jsonb),
    ('min_ocr_confidence', '0.9'::jsonb),
    ('large_change_pct', '25'::jsonb),
    ('per_host_delay_ms', '5000'::jsonb),
    ('candidate_expiry_days', '60'::jsonb)
on conflict (key) do nothing;

-- Aday durum gecisleri veritabaninda zorlanir.
create or replace function public.tariff_candidate_transition_ok(old_status text, new_status text)
returns boolean language sql immutable as $$
    select old_status = new_status or (old_status, new_status) in (
        ('draft','pending_verification'), ('draft','needs_more_sources'), ('draft','approved'), ('draft','rejected'),
        ('pending_verification','approved'), ('pending_verification','rejected'), ('pending_verification','needs_more_sources'),
        ('pending_verification','expired'),
        ('needs_more_sources','pending_verification'), ('needs_more_sources','approved'), ('needs_more_sources','rejected'),
        ('needs_more_sources','expired'),
        ('approved','published'), ('approved','rejected'), ('approved','pending_verification'), ('approved','expired'),
        ('published','withdrawn'), ('published','expired')
    )
$$;

create or replace function public.tariff_candidates_guard()
returns trigger language plpgsql as $$
begin
    if not public.tariff_candidate_transition_ok(old.status, new.status) then
        raise exception 'gecersiz aday durum gecisi: % -> %', old.status, new.status using errcode = '22023';
    end if;
    if old.status = 'published' and new.status = 'published' and new.changes is distinct from old.changes then
        raise exception 'yayimlanmis aday degistirilemez' using errcode = '22023';
    end if;
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists tariff_candidates_guard on public.tariff_candidates;
create trigger tariff_candidates_guard before update on public.tariff_candidates
    for each row execute function public.tariff_candidates_guard();

-- Aday karari (onay / ret / ek kaynak / dogrulamaya geri). Denetim kaydina islenir.
create or replace function public.decide_tariff_candidate(p_candidate text, p_status text, p_actor text, p_note text default null,
                                                          p_effective_from date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
    c public.tariff_candidates;
begin
    if coalesce(trim(p_actor), '') = '' then raise exception 'karar veren belirtilmeli' using errcode = '22023'; end if;
    select * into c from public.tariff_candidates where candidate_id = p_candidate for update;
    if not found then raise exception 'aday yok: %', p_candidate using errcode = 'P0002'; end if;
    if p_status not in ('pending_verification','needs_more_sources','approved','rejected') then
        raise exception 'karar durumu gecersiz: %', p_status using errcode = '22023';
    end if;
    if p_status = 'approved' and coalesce(p_effective_from, c.effective_from) is null then
        raise exception 'onay icin yururluk tarihi gerekli' using errcode = '22023';
    end if;
    update public.tariff_candidates
       set status = p_status,
           effective_from = coalesce(p_effective_from, effective_from),
           effective_date_certain = effective_date_certain or p_effective_from is not null,
           decided_by = p_actor, decided_at = now(),
           note = coalesce(p_note, note)
     where candidate_id = p_candidate;
    insert into public.tariff_audit_log (actor, action, entity, entity_id, before, after, note)
    values (p_actor, 'candidate_' || p_status, 'tariff_candidate', p_candidate,
            jsonb_build_object('status', c.status, 'effective_from', c.effective_from),
            jsonb_build_object('status', p_status, 'effective_from', coalesce(p_effective_from, c.effective_from)), p_note);
    return jsonb_build_object('candidate_id', p_candidate, 'status', p_status);
end;
$$;

-- Onayli adayi yayimlar: degisen kalemin eskisi yururluk tarihinde kapanir, yenisi o tarihten acilir (kalem bazli surum).
-- Ayni aday ikinci kez yayimlanmaz; onaysiz aday yayimlanamaz. Tek islemde: yarim kalan yayim olmaz.
create or replace function public.publish_tariff_candidate(p_candidate text, p_actor text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
    c public.tariff_candidates;
    v public.tariff_versions;
    ch jsonb;
    old_item public.tariff_items;
    new_id text;
    item jsonb;
    conf text;
    rev integer;
    src_url text;
begin
    if coalesce(trim(p_actor), '') = '' then raise exception 'yayimlayan belirtilmeli' using errcode = '22023'; end if;
    select * into c from public.tariff_candidates where candidate_id = p_candidate for update;
    if not found then raise exception 'aday yok: %', p_candidate using errcode = 'P0002'; end if;
    if c.status = 'published' then
        return jsonb_build_object('candidate_id', p_candidate, 'status', 'already_published');
    end if;
    if c.status <> 'approved' then
        raise exception 'onaylanmamis aday yayimlanamaz (durum: %)', c.status using errcode = '22023';
    end if;
    if c.effective_from is null then raise exception 'yururluk tarihi yok' using errcode = '22023'; end if;
    select * into v from public.tariff_versions where tariff_version_id = c.tariff_version_id for update;
    if v.approval_status <> 'published' then
        raise exception 'temel surum yayinda degil (%)', v.approval_status using errcode = '22023';
    end if;
    rev := v.revision + 1;
    conf := case when c.verification = 'verified' then 'verified' else 'needs_verification' end;

    for ch in select * from jsonb_array_elements(c.changes) loop
        select * into old_item from public.tariff_items i
         where i.tariff_version_id = v.tariff_version_id and i.item_key = ch->>'item_key' and not i.withdrawn
           and (i.effective_until is null or i.effective_until > c.effective_from)
         order by i.effective_from desc nulls last limit 1;
        if (ch->>'kind') in ('changed','removed') and old_item.tariff_item_id is not null then
            insert into public.tariff_item_revisions (candidate_id, tariff_item_id, action, previous_effective_until)
            values (p_candidate, old_item.tariff_item_id, 'closed', old_item.effective_until);
            update public.tariff_items set effective_until = c.effective_from where tariff_item_id = old_item.tariff_item_id;
        end if;
        if (ch->>'kind') = 'changed' and old_item.tariff_item_id is not null then
            new_id := v.tariff_version_id || '-' || (ch->>'item_key') || '-r' || rev;
            insert into public.tariff_items (tariff_item_id, tariff_version_id, item_key, item_type, label, amount, amount_upper,
                currency, unit, lower_threshold, upper_threshold, calculation_method, eligibility_conditions, stacking_rule,
                item_group, effective_from, effective_until, confidence_status, is_cash, note, supersedes_item_id, candidate_id)
            values (new_id, v.tariff_version_id, old_item.item_key, old_item.item_type, old_item.label,
                coalesce((ch->>'new_amount')::numeric, old_item.amount),
                case when ch ? 'new_amount_upper' then (ch->>'new_amount_upper')::numeric else old_item.amount_upper end,
                old_item.currency, old_item.unit,
                case when ch ? 'new_lower_threshold' then (ch->>'new_lower_threshold')::numeric else old_item.lower_threshold end,
                case when ch ? 'new_upper_threshold' then (ch->>'new_upper_threshold')::numeric else old_item.upper_threshold end,
                old_item.calculation_method, old_item.eligibility_conditions, old_item.stacking_rule, old_item.item_group,
                c.effective_from, old_item.effective_until, conf, old_item.is_cash, old_item.note, old_item.tariff_item_id,
                p_candidate);
            insert into public.tariff_item_revisions (candidate_id, tariff_item_id, action) values (p_candidate, new_id, 'inserted');
        elsif (ch->>'kind') = 'added' then
            item := ch->'item';
            new_id := v.tariff_version_id || '-' || (ch->>'item_key') || '-r' || rev;
            insert into public.tariff_items (tariff_item_id, tariff_version_id, item_key, item_type, label, amount, amount_upper,
                unit, lower_threshold, upper_threshold, calculation_method, eligibility_conditions, stacking_rule, item_group,
                effective_from, confidence_status, is_cash, note, candidate_id)
            values (new_id, v.tariff_version_id, ch->>'item_key', item->>'item_type', coalesce(ch->>'label', item->>'label'),
                (ch->>'new_amount')::numeric, (ch->>'new_amount_upper')::numeric, coalesce(item->>'unit', 'flat'),
                (ch->>'new_lower_threshold')::numeric, (ch->>'new_upper_threshold')::numeric,
                coalesce(item->>'calculation_method', 'flat'), coalesce(item->'eligibility_conditions', '{}'::jsonb),
                coalesce(item->>'stacking_rule', 'additive'), item->>'item_group', c.effective_from, conf,
                coalesce((item->>'is_cash')::boolean, true), item->>'note', p_candidate);
            insert into public.tariff_item_revisions (candidate_id, tariff_item_id, action) values (p_candidate, new_id, 'inserted');
        end if;
        old_item := null;
    end loop;

    update public.tariff_versions
       set revision = rev,
           change_summary = coalesce(c.note, 'Kalem güncellemesi') || ' (' || to_char(c.effective_from, 'YYYY-MM-DD') || ')'
     where tariff_version_id = v.tariff_version_id;
    update public.tariff_candidates set status = 'published', published_at = now() where candidate_id = p_candidate;
    select url into src_url from public.tariff_sources where source_id = any (c.source_ids) order by priority limit 1;
    insert into public.tariff_change_events (platform_id, tariff_version_id, candidate_id, kind, effective_from, verification,
        source_type, source_url, changes)
    values (c.platform_id, v.tariff_version_id, p_candidate, 'published', c.effective_from, c.verification,
        c.source_types[1], src_url, c.changes);
    insert into public.tariff_audit_log (actor, action, entity, entity_id, before, after, note)
    values (p_actor, 'publish', 'tariff_candidate', p_candidate, jsonb_build_object('revision', v.revision),
            jsonb_build_object('revision', rev, 'effective_from', c.effective_from, 'changes', c.changes), null);
    return jsonb_build_object('candidate_id', p_candidate, 'status', 'published', 'revision', rev);
end;
$$;

-- Yayimlanmis degisikligi geri ceker: eklenen kalemler hesaplamadan cikar, kapatilan kalemler eski gecerliligine doner.
-- Gecmis kayitlar uygulamada dondurulmus sonuclarini korur.
create or replace function public.withdraw_tariff_candidate(p_candidate text, p_actor text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
    c public.tariff_candidates;
    r record;
    rev integer;
begin
    if coalesce(trim(p_actor), '') = '' or coalesce(trim(p_reason), '') = '' then
        raise exception 'geri ceken ve neden belirtilmeli' using errcode = '22023';
    end if;
    select * into c from public.tariff_candidates where candidate_id = p_candidate for update;
    if not found then raise exception 'aday yok: %', p_candidate using errcode = 'P0002'; end if;
    if c.status = 'withdrawn' then return jsonb_build_object('candidate_id', p_candidate, 'status', 'already_withdrawn'); end if;
    if c.status <> 'published' then raise exception 'yalnizca yayimlanmis aday geri cekilir' using errcode = '22023'; end if;
    for r in select * from public.tariff_item_revisions where candidate_id = p_candidate loop
        if r.action = 'inserted' then
            update public.tariff_items set withdrawn = true where tariff_item_id = r.tariff_item_id;
        else
            update public.tariff_items set effective_until = r.previous_effective_until where tariff_item_id = r.tariff_item_id;
        end if;
    end loop;
    update public.tariff_versions set revision = revision + 1 where tariff_version_id = c.tariff_version_id returning revision into rev;
    update public.tariff_candidates set status = 'withdrawn', note = p_reason where candidate_id = p_candidate;
    insert into public.tariff_change_events (platform_id, tariff_version_id, candidate_id, kind, effective_from, verification,
        source_type, changes)
    values (c.platform_id, c.tariff_version_id, p_candidate, 'withdrawn', c.effective_from, c.verification, c.source_types[1], c.changes);
    insert into public.tariff_audit_log (actor, action, entity, entity_id, before, after, note)
    values (p_actor, 'withdraw', 'tariff_candidate', p_candidate, jsonb_build_object('status', 'published'),
            jsonb_build_object('status', 'withdrawn', 'revision', rev), p_reason);
    return jsonb_build_object('candidate_id', p_candidate, 'status', 'withdrawn', 'revision', rev);
end;
$$;

-- Tum surumu geri ceker (yanlis yayimlanan surum). Onceki surum gecerli kalir.
create or replace function public.withdraw_tariff_version(p_version text, p_actor text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
    v public.tariff_versions;
begin
    if coalesce(trim(p_actor), '') = '' or coalesce(trim(p_reason), '') = '' then
        raise exception 'geri ceken ve neden belirtilmeli' using errcode = '22023';
    end if;
    select * into v from public.tariff_versions where tariff_version_id = p_version for update;
    if not found then raise exception 'surum yok: %', p_version using errcode = 'P0002'; end if;
    if v.approval_status = 'withdrawn' then return jsonb_build_object('tariff_version_id', p_version, 'status', 'already_withdrawn'); end if;
    update public.tariff_versions set approval_status = 'withdrawn' where tariff_version_id = p_version;
    insert into public.tariff_change_events (platform_id, tariff_version_id, kind, effective_from, verification)
    values (v.platform_id, p_version, 'withdrawn', v.effective_from,
            case when v.verification_status = 'verified' then 'verified' else 'needs_verification' end);
    insert into public.tariff_audit_log (actor, action, entity, entity_id, before, after, note)
    values (p_actor, 'withdraw_version', 'tariff_version', p_version, jsonb_build_object('approval_status', v.approval_status),
            jsonb_build_object('approval_status', 'withdrawn'), p_reason);
    return jsonb_build_object('tariff_version_id', p_version, 'status', 'withdrawn');
end;
$$;

-- Erisim: istemci yalnizca yayindaki tarifeyi okur; yazma ve yonetim fonksiyonlari yalnizca servis rolu / yonetim betikleri.
alter table public.tariff_platforms enable row level security;
alter table public.tariff_versions enable row level security;
alter table public.tariff_items enable row level security;
alter table public.tariff_sources enable row level security;
alter table public.tariff_source_checks enable row level security;
alter table public.tariff_candidates enable row level security;
alter table public.tariff_item_revisions enable row level security;
alter table public.tariff_audit_log enable row level security;
alter table public.tariff_change_events enable row level security;
alter table public.economic_indicators enable row level security;
alter table public.tariff_config enable row level security;

revoke all on public.tariff_platforms, public.tariff_versions, public.tariff_items, public.tariff_sources,
    public.tariff_source_checks, public.tariff_candidates, public.tariff_item_revisions, public.tariff_audit_log,
    public.tariff_change_events, public.economic_indicators, public.tariff_config from anon, authenticated;
grant select on public.tariff_platforms, public.tariff_versions, public.tariff_items, public.tariff_change_events
    to anon, authenticated;

drop policy if exists tariff_platforms_read on public.tariff_platforms;
create policy tariff_platforms_read on public.tariff_platforms for select to anon, authenticated using (true);
drop policy if exists tariff_versions_read on public.tariff_versions;
create policy tariff_versions_read on public.tariff_versions for select to anon, authenticated
    using (approval_status in ('published','expired'));
drop policy if exists tariff_items_read on public.tariff_items;
create policy tariff_items_read on public.tariff_items for select to anon, authenticated
    using (exists (select 1 from public.tariff_versions v where v.tariff_version_id = tariff_items.tariff_version_id
                   and v.approval_status in ('published','expired')));
drop policy if exists tariff_events_read on public.tariff_change_events;
create policy tariff_events_read on public.tariff_change_events for select to anon, authenticated using (true);

revoke all on function public.decide_tariff_candidate(text, text, text, text, date) from public, anon, authenticated;
revoke all on function public.publish_tariff_candidate(text, text) from public, anon, authenticated;
revoke all on function public.withdraw_tariff_candidate(text, text, text) from public, anon, authenticated;
revoke all on function public.withdraw_tariff_version(text, text, text) from public, anon, authenticated;
