-- Kurye Kazanc 1.4b: topluluk isi haritasi ve ozeti (spec 2026-10-10 §2).
-- k-anonimlik: hicbir hucre / ozet, en az 5 FARKLI kurye olmadan donmez.
-- Tekrar calistirilabilir.

alter table public.shifts add column if not exists is_synthetic boolean not null default false;
-- submit_shift sutunlari acikca listeler ve is_synthetic'i yazmaz: istemci payload'u ne gonderirse gondersin false kalir.

-- Ic yardimci: (hafta gunu, saat) hucreleri. Yalnizca diger SECURITY DEFINER fonksiyonlar cagirir.
-- weekday: 1 = Pazartesi ... 7 = Pazar. Vardiya, kapsadigi saatlere dakika agirlikli dagitilir;
-- gece yarisini asan kisim ertesi gune (7 -> 1) gecer. Saat sinirlari uzerinden hesaplanir (dakika uretilmez).
create or replace function public.community_cells(p_province text, p_district text)
returns table (weekday smallint, hour smallint, per_hour numeric, couriers integer, shifts integer)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
    with scoped as (
        select s.id, s.user_id,
               ((s.weekday - 1) * 1440 + s.start_slot * 15) as base,
               s.duration_min as dur,
               (s.gross + s.bonus) as earn
        from public.shifts s
        where s.created_at >= now() - interval '56 days'
          and (s.province = p_province or lower(s.province) = lower(p_province))
          and (s.district = p_district or lower(s.district) = lower(p_district))
    ),
    pieces as (
        select sc.id, sc.user_id, sc.dur, sc.earn,
               (h % 168) as slot,
               (least(sc.base + sc.dur, (h + 1) * 60) - greatest(sc.base, h * 60)) as ov
        from scoped sc
        cross join lateral generate_series(sc.base / 60, (sc.base + sc.dur - 1) / 60) as h
    )
    select ((slot / 24) + 1)::smallint,
           (slot % 24)::smallint,
           round(sum(earn * ov / dur) / (sum(ov) / 60.0), 2),
           count(distinct user_id)::integer,
           count(distinct id)::integer
    from pieces
    group by slot
    having count(distinct user_id) >= 5
$$;

-- JSON dizi: [{weekday, hour, per_hour, couriers, shifts}, ...] (yalnizca >= 5 kuryeli hucreler),
-- weekday/hour sirali. Bos ise [].
create or replace function public.community_heatmap(p_province text, p_district text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'weekday', c.weekday, 'hour', c.hour, 'per_hour', c.per_hour,
               'couriers', c.couriers, 'shifts', c.shifts)
               order by c.weekday, c.hour), '[]'::jsonb)
    from public.community_cells(p_province, p_district) c
$$;

-- {per_hour, couriers, platforms:[{code, per_hour, per_package, couriers}], best:[{weekday,hour,per_hour,couriers,shifts}]}
-- per_hour/couriers yalnizca ilcede >= 5 kurye varsa bulunur; platform satirlari tek tek suzulur.
create or replace function public.community_summary(p_province text, p_district text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
    total_couriers integer;
    total_per_hour numeric;
    result jsonb;
begin
    select count(distinct s.user_id),
           round(sum(s.gross + s.bonus) / nullif(sum(s.duration_min) / 60.0, 0), 2)
      into total_couriers, total_per_hour
      from public.shifts s
     where s.created_at >= now() - interval '56 days'
       and (s.province = p_province or lower(s.province) = lower(p_province))
       and (s.district = p_district or lower(s.district) = lower(p_district));

    result := jsonb_build_object(
        'platforms', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'code', t.platform_code, 'per_hour', t.per_hour,
                       'per_package', t.per_package, 'couriers', t.couriers)
                       order by t.per_hour desc, t.platform_code)
            from (
                select s.platform_code,
                       round(sum(s.gross + s.bonus) / nullif(sum(s.duration_min) / 60.0, 0), 2) as per_hour,
                       round(sum(s.gross + s.bonus) filter (where s.packages > 0)
                             / nullif(sum(s.packages) filter (where s.packages > 0), 0), 2) as per_package,
                       count(distinct s.user_id)::integer as couriers
                from public.shifts s
                where s.created_at >= now() - interval '56 days'
                  and (s.province = p_province or lower(s.province) = lower(p_province))
                  and (s.district = p_district or lower(s.district) = lower(p_district))
                group by s.platform_code
                having count(distinct s.user_id) >= 5
            ) t), '[]'::jsonb),
        'best', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'weekday', b.weekday, 'hour', b.hour, 'per_hour', b.per_hour,
                       'couriers', b.couriers, 'shifts', b.shifts)
                       order by b.per_hour desc, b.weekday, b.hour)
            from (
                select c.weekday, c.hour, c.per_hour, c.couriers, c.shifts
                from public.community_cells(p_province, p_district) c
                order by c.per_hour desc, c.weekday, c.hour
                limit 3
            ) b), '[]'::jsonb)
    );
    if total_couriers >= 5 then
        result := result || jsonb_build_object('per_hour', total_per_hour, 'couriers', total_couriers);
    end if;
    return result;
end;
$$;

revoke all on function public.community_cells(text, text) from public, anon, authenticated;
revoke all on function public.community_heatmap(text, text) from public, anon;
revoke all on function public.community_summary(text, text) from public, anon;
grant execute on function public.community_heatmap(text, text) to authenticated;
grant execute on function public.community_summary(text, text) to authenticated;
