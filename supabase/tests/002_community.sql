-- pgTAP: topluluk fonksiyonlari (001 dosyasindaki tests._user / _login / _logout / _payload yardimcilarini kullanir).
-- Test verisi benzersiz il/ilce adlariyla yazilir; her test geri alinir.

create or replace function tests._seed_shift(uid uuid, prov text, dist text, plat text, wd integer, slot integer,
                                              dur integer, gross numeric, age interval default interval '1 day')
returns void language sql as $$
    insert into public.shifts (user_id, client_record_id, platform_code, province, district, vehicle, weekday,
                               start_slot, duration_min, gross, bonus, packages, level, text_hash, created_at)
    values (uid, gen_random_uuid(), plat, prov, dist, 'motorcycle', wd, slot, dur, gross, 0, 10, 'ocrUnverified',
            encode(sha256(gen_random_uuid()::text::bytea), 'hex'), now() - age)
$$;

-- n kurye, her biri ayni hucreye (hafta gunu wd, slot) bir vardiya yazar.
create or replace function tests._seed_couriers(n integer, prov text, dist text, plat text, wd integer,
                                                 slot integer, dur integer, gross numeric,
                                                 age interval default interval '1 day')
returns void language plpgsql as $$
declare
    u uuid;
begin
    for i in 1..n loop
        u := gen_random_uuid();
        perform tests._user(u, true);
        perform tests._seed_shift(u, prov, dist, plat, wd, slot, dur, gross, age);
    end loop;
end;
$$;

create or replace function tests.test_heatmap_hides_under_five_couriers()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._seed_couriers(4, 'TestIl', 'Dar', 'getir', 2, 72, 60, 300);
    perform tests._login(a, true);
    return next is(public.community_heatmap('TestIl', 'Dar'), '[]'::jsonb, '4 kurye: hucre donmez');
    perform tests._logout();
    perform tests._seed_couriers(1, 'TestIl', 'Dar', 'getir', 2, 72, 60, 300);
    perform tests._login(a, true);
    return next is(jsonb_array_length(public.community_heatmap('TestIl', 'Dar')), 1, '5 kurye: hucre gorunur');
    perform tests._logout();
end;
$$;

create or replace function tests.test_heatmap_cell_value_and_case_insensitive()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    cell jsonb;
begin
    perform tests._user(a, true);
    -- Sali 18:00 (slot 72), 2 saat, 500 TL => 250 TL/saat; saat 18 ve 19
    perform tests._seed_couriers(5, 'TestIl', 'Genis', 'getir', 2, 72, 120, 500);
    perform tests._login(a, true);
    cell := public.community_heatmap('testil', 'GENIS') -> 0;
    return next is(jsonb_array_length(public.community_heatmap('testil', 'GENIS')), 2, 'buyuk/kucuk harf duyarsiz, 2 saat hucresi');
    return next is((cell ->> 'weekday')::int, 2, 'hafta gunu');
    return next is((cell ->> 'hour')::int, 18, 'ilk saat');
    return next is((cell ->> 'per_hour')::numeric, 250.00, 'TL/saat');
    return next is((cell ->> 'couriers')::int, 5, 'kurye sayisi');
    return next is((cell ->> 'shifts')::int, 5, 'vardiya sayisi');
    perform tests._logout();
end;
$$;

create or replace function tests.test_heatmap_midnight_rollover_sunday_to_monday()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    hm jsonb;
begin
    perform tests._user(a, true);
    -- Pazar (7) 23:00, 2 saat, 200 TL => Pazar 23 ve Pazartesi 0; saat basina 100
    perform tests._seed_couriers(5, 'TestIl', 'Gece', 'getir', 7, 92, 120, 200);
    perform tests._login(a, true);
    hm := public.community_heatmap('TestIl', 'Gece');
    return next is(jsonb_array_length(hm), 2, 'iki hucre');
    return next is((hm -> 0 ->> 'weekday')::int, 1, 'Pazartesi (sirali ilk)');
    return next is((hm -> 0 ->> 'hour')::int, 0, 'saat 0');
    return next is((hm -> 1 ->> 'weekday')::int, 7, 'Pazar');
    return next is((hm -> 1 ->> 'hour')::int, 23, 'saat 23');
    return next is((hm -> 1 ->> 'per_hour')::numeric, 100.00, 'saat basina pay');
    perform tests._logout();
end;
$$;

create or replace function tests.test_heatmap_partial_hour_is_minute_weighted()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    hm jsonb;
begin
    perform tests._user(a, true);
    -- Carsamba 10:30 (slot 42), 90 dk, 300 TL: 10. saatte 30 dk (100 TL), 11. saatte 60 dk (200 TL);
    -- hucre = pay / (dk/60) => 200 ve 200
    perform tests._seed_couriers(5, 'TestIl', 'Yarim', 'getir', 3, 42, 90, 300);
    perform tests._login(a, true);
    hm := public.community_heatmap('TestIl', 'Yarim');
    return next is(jsonb_array_length(hm), 2, '10 ve 11. saat');
    return next is((hm -> 0 ->> 'per_hour')::numeric, 200.00, 'kismi saat dakika agirlikli');
    return next is((hm -> 1 ->> 'per_hour')::numeric, 200.00, 'tam saat');
    perform tests._logout();
end;
$$;

create or replace function tests.test_heatmap_window_excludes_old_shifts()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._seed_couriers(5, 'TestIl', 'Eski', 'getir', 2, 72, 60, 300, interval '60 days');
    perform tests._login(a, true);
    return next is(public.community_heatmap('TestIl', 'Eski'), '[]'::jsonb, '56 gunden eski vardiyalar sayilmaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_summary_k_anonymity_and_shape()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    s jsonb;
begin
    perform tests._user(a, true);
    -- getir: 5 kurye (Sali 18:00, 60 dk, 300 TL); trendyol_go: 3 kurye (100 TL); ilce toplami 8 kurye
    perform tests._seed_couriers(5, 'TestIl', 'Ozet', 'getir', 2, 72, 60, 300);
    perform tests._seed_couriers(3, 'TestIl', 'Ozet', 'trendyol_go', 2, 72, 60, 100);
    perform tests._login(a, true);
    s := public.community_summary('TestIl', 'Ozet');
    return next is((s ->> 'couriers')::int, 8, 'ilce kurye sayisi');
    return next is((s ->> 'per_hour')::numeric, 225.00, 'ilce ortalamasi (1800/8)');
    return next is(jsonb_array_length(s -> 'platforms'), 1, 'yalnizca >= 5 kuryeli platform');
    return next is(s -> 'platforms' -> 0 ->> 'code', 'getir', 'platform kodu');
    return next is((s -> 'platforms' -> 0 ->> 'per_hour')::numeric, 300.00, 'platform TL/saat');
    return next is((s -> 'platforms' -> 0 ->> 'per_package')::numeric, 30.00, 'platform TL/paket (10 paket)');
    return next is(jsonb_array_length(s -> 'best'), 1, 'en iyi hucre');
    return next is((s -> 'best' -> 0 ->> 'per_hour')::numeric, 225.00, 'en iyi hucre TL/saat');
    perform tests._logout();
end;
$$;

create or replace function tests.test_summary_small_district_has_no_aggregates()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    s jsonb;
begin
    perform tests._user(a, true);
    perform tests._seed_couriers(4, 'TestIl', 'Kucuk', 'getir', 2, 72, 60, 300);
    perform tests._login(a, true);
    s := public.community_summary('TestIl', 'Kucuk');
    return next ok(not (s ? 'per_hour') and not (s ? 'couriers'), '4 kurye: toplam alanlari yok');
    return next is(s -> 'platforms', '[]'::jsonb, 'platform yok');
    return next is(s -> 'best', '[]'::jsonb, 'en iyi hucre yok');
    perform tests._logout();
end;
$$;

create or replace function tests.test_summary_best_is_top_three()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    s jsonb;
begin
    perform tests._user(a, true);
    perform tests._seed_couriers(5, 'TestIl', 'Uc', 'getir', 1, 72, 60, 100);
    perform tests._seed_couriers(5, 'TestIl', 'Uc', 'getir', 2, 72, 60, 400);
    perform tests._seed_couriers(5, 'TestIl', 'Uc', 'getir', 3, 72, 60, 300);
    perform tests._seed_couriers(5, 'TestIl', 'Uc', 'getir', 4, 72, 60, 200);
    perform tests._login(a, true);
    s := public.community_summary('TestIl', 'Uc');
    return next is(jsonb_array_length(s -> 'best'), 3, 'en fazla 3');
    return next is((s -> 'best' -> 0 ->> 'weekday')::int, 2, 'en yuksek once');
    return next is((s -> 'best' -> 2 ->> 'weekday')::int, 4, 'ucuncu');
    perform tests._logout();
end;
$$;

create or replace function tests.test_community_grants()
returns setof text language plpgsql as $$
begin
    perform set_config('role', 'anon', true);
    return next throws_ok($q$select public.community_heatmap('a','b')$q$, '42501', null, 'anon isi haritasi calistiramaz');
    return next throws_ok($q$select public.community_summary('a','b')$q$, '42501', null, 'anon ozet calistiramaz');
    perform tests._logout();
    perform set_config('role', 'authenticated', true);
    return next throws_ok($q$select * from public.community_cells('a','b')$q$, '42501', null, 'ic fonksiyon dogrudan calistirilamaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_submit_shift_cannot_set_is_synthetic()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_shift(tests._payload(repeat('9', 64)) || '{"is_synthetic":true}'::jsonb), 'ok', 'gonderim kabul');
    perform tests._logout();
    return next is((select is_synthetic from public.shifts where text_hash = repeat('9', 64)), false, 'is_synthetic her zaman false');
end;
$$;
