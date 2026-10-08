-- Kurye Kazanc 1.3: sunucu semasi (spec 2026-10-09 §3).
-- Dogrudan tablo erisimi yok; yazma SECURITY DEFINER fonksiyonlarla.

create extension if not exists pgtap with schema extensions;

create table if not exists public.shifts (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    client_record_id uuid not null,
    platform_code text not null check (platform_code ~ '^[a-z_]{2,32}$'),
    province text check (char_length(province) <= 64),
    district text check (char_length(district) <= 64),
    vehicle text not null check (vehicle in ('motorcycle','scooter','bicycle','car','onFoot')),
    weekday smallint not null check (weekday between 1 and 7),
    start_slot smallint not null check (start_slot between 0 and 95),
    duration_min integer not null check (duration_min between 1 and 1200),
    gross numeric(10,2) not null check (gross >= 0 and gross <= 100000),
    bonus numeric(10,2) not null default 0 check (bonus >= 0 and bonus <= 100000),
    packages integer check (packages is null or packages between 0 and 500),
    distance_km numeric(6,1) not null default 0 check (distance_km >= 0 and distance_km <= 1500),
    level text not null check (level in ('verified','ocrUnverified')),
    template_id text,
    template_version integer,
    text_hash text not null unique check (text_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz not null default now()
);
create index if not exists shifts_user_created on public.shifts (user_id, created_at);

create table if not exists public.ocr_templates (
    id text not null,
    platform_code text not null,
    version integer not null check (version >= 1),
    status text not null check (status in ('calibrating','active')),
    body jsonb not null,
    updated_at timestamptz not null default now(),
    primary key (id, version)
);

create table if not exists public.calibration_samples (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    platform_code text,
    template_id text,
    lines jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 200),
    created_at timestamptz not null default now()
);
create index if not exists calibration_user_created on public.calibration_samples (user_id, created_at);

create table if not exists public.backups (
    user_id uuid primary key references auth.users(id) on delete cascade,
    payload jsonb not null,
    updated_at timestamptz not null default now()
);

alter table public.shifts enable row level security;
alter table public.ocr_templates enable row level security;
alter table public.calibration_samples enable row level security;
alter table public.backups enable row level security;

-- Sablonlar herkese acik okunur
drop policy if exists templates_read on public.ocr_templates;
create policy templates_read on public.ocr_templates for select to anon, authenticated using (true);

-- Yedek: yalnizca sahibi ve anonim olmayan kullanici
drop policy if exists backups_owner_select on public.backups;
create policy backups_owner_select on public.backups for select to authenticated
    using (user_id = auth.uid());
drop policy if exists backups_owner_insert on public.backups;
create policy backups_owner_insert on public.backups for insert to authenticated
    with check (user_id = auth.uid() and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
drop policy if exists backups_owner_update on public.backups;
create policy backups_owner_update on public.backups for update to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid() and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
drop policy if exists backups_owner_delete on public.backups;
create policy backups_owner_delete on public.backups for delete to authenticated
    using (user_id = auth.uid());

-- shifts ve calibration_samples icin hicbir politika yok: dogrudan erisim kapali.
revoke all on public.shifts from anon, authenticated;
revoke all on public.calibration_samples from anon, authenticated;
grant select on public.ocr_templates to anon, authenticated;
grant select, insert, update, delete on public.backups to authenticated;

create or replace function public.submit_shift(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
    today_count integer;
begin
    if uid is null then
        return 'invalid';
    end if;
    select count(*) into today_count from public.shifts
        where user_id = uid and created_at >= date_trunc('day', now());
    if today_count >= 40 then
        return 'rate_limited';
    end if;
    begin
        insert into public.shifts (
            user_id, client_record_id, platform_code, province, district, vehicle, weekday, start_slot,
            duration_min, gross, bonus, packages, distance_km, level, template_id, template_version, text_hash
        ) values (
            uid,
            (payload ->> 'client_record_id')::uuid,
            payload ->> 'platform_code',
            nullif(payload ->> 'province', ''),
            nullif(payload ->> 'district', ''),
            payload ->> 'vehicle',
            (payload ->> 'weekday')::smallint,
            (payload ->> 'start_slot')::smallint,
            (payload ->> 'duration_min')::integer,
            (payload ->> 'gross')::numeric,
            coalesce((payload ->> 'bonus')::numeric, 0),
            (payload ->> 'packages')::integer,
            coalesce((payload ->> 'distance_km')::numeric, 0),
            payload ->> 'level',
            payload ->> 'template_id',
            (payload ->> 'template_version')::integer,
            payload ->> 'text_hash'
        );
    exception
        when unique_violation then
            return 'duplicate';
        when check_violation or not_null_violation or invalid_text_representation
             or numeric_value_out_of_range or invalid_parameter_value then
            return 'invalid';
    end;
    return 'ok';
end;
$$;

create or replace function public.submit_calibration(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
    today_count integer;
begin
    if uid is null then
        return 'invalid';
    end if;
    select count(*) into today_count from public.calibration_samples
        where user_id = uid and created_at >= date_trunc('day', now());
    if today_count >= 20 then
        return 'rate_limited';
    end if;
    begin
        insert into public.calibration_samples (user_id, platform_code, template_id, lines)
        values (uid, payload ->> 'platform_code', payload ->> 'template_id', payload -> 'lines');
    exception
        when check_violation or not_null_violation then
            return 'invalid';
    end;
    return 'ok';
end;
$$;

create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        return;
    end if;
    delete from public.shifts where user_id = uid;
    delete from public.calibration_samples where user_id = uid;
    delete from public.backups where user_id = uid;
end;
$$;

revoke all on function public.submit_shift(jsonb) from public, anon;
revoke all on function public.submit_calibration(jsonb) from public, anon;
revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.submit_shift(jsonb) to authenticated;
grant execute on function public.submit_calibration(jsonb) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
