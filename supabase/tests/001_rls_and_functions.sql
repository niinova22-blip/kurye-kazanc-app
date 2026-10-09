-- pgTAP testleri: node scripts/server/test.mjs ile calistirilir.
create schema if not exists tests;
-- Testler rol degistirdikten sonra (authenticated/anon) yardimci fonksiyonlari cagirir.
grant usage on schema tests to anon, authenticated;

create or replace function tests._login(uid uuid, anonymous boolean)
returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims',
        json_build_object('sub', uid, 'role', 'authenticated', 'is_anonymous', anonymous)::text, true);
    perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function tests._logout()
returns void language plpgsql as $$
begin
    perform set_config('role', 'none', true);
    perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function tests._user(uid uuid, anonymous boolean)
returns void language plpgsql as $$
begin
    insert into auth.users (id, instance_id, aud, role, email, is_anonymous, created_at, updated_at)
    values (uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            case when anonymous then null else uid::text || '@test.local' end, anonymous, now(), now())
    on conflict (id) do nothing;
end;
$$;

create or replace function tests._payload(hash text)
returns jsonb language sql as $$
    select jsonb_build_object(
        'client_record_id', gen_random_uuid(), 'platform_code', 'getir', 'province', 'İstanbul',
        'district', 'Kadıköy', 'vehicle', 'motorcycle', 'weekday', 1, 'start_slot', 74,
        'duration_min', 153, 'gross', 900, 'bonus', 100, 'packages', 12, 'distance_km', 41.5,
        'level', 'ocrUnverified', 'template_id', 'getir.earnings', 'template_version', 1,
        'text_hash', hash)
$$;

create or replace function tests.test_submit_shift_ok_and_duplicate()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    h text := repeat('a', 64);
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_shift(tests._payload(h)), 'ok', 'ilk gonderim kabul');
    return next is(public.submit_shift(tests._payload(h)), 'duplicate', 'ayni text_hash reddedilir');
    perform tests._logout();
end;
$$;

create or replace function tests.test_submit_shift_rejects_invalid()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_shift(tests._payload(repeat('b', 64)) || '{"level":"manual"}'::jsonb), 'invalid', 'manual seviye gonderilemez');
    return next is(public.submit_shift(tests._payload('kisa')), 'invalid', 'gecersiz hash');
    return next is(public.submit_shift(tests._payload(repeat('c', 64)) || '{"weekday":9}'::jsonb), 'invalid', 'gecersiz hafta gunu');
    perform tests._logout();
end;
$$;

create or replace function tests.test_rate_limit()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    i integer;
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    for i in 1..40 loop
        perform public.submit_shift(tests._payload(lpad(to_hex(i), 64, '0')));
    end loop;
    return next is(public.submit_shift(tests._payload(repeat('d', 64))), 'rate_limited', 'gunde 40 sinir');
    perform tests._logout();
end;
$$;

create or replace function tests.test_shifts_not_readable()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    perform public.submit_shift(tests._payload(repeat('e', 64)));
    return next throws_ok('select count(*) from public.shifts', '42501', null, 'shifts dogrudan okunamaz');
    return next throws_ok('select count(*) from public.calibration_samples', '42501', null, 'kalibrasyon okunamaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_backups_owner_only()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    b uuid := gen_random_uuid();
    anon uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._user(b, false);
    perform tests._user(anon, true);

    perform tests._login(a, false);
    insert into public.backups (user_id, payload) values (a, '{"v":1}');
    perform tests._login(b, false);
    return next is((select count(*)::int from public.backups), 0, 'B, A''nin yedegini goremez');
    return next throws_ok(
        format('insert into public.backups (user_id, payload) values (%L, %L)', a, '{"x":1}'),
        '42501', null, 'B, A adina yazamaz');
    perform tests._login(anon, true);
    return next throws_ok(
        format('insert into public.backups (user_id, payload) values (%L, %L)', anon, '{"x":1}'),
        '42501', null, 'anonim kullanici yedek yazamaz');
    perform tests._login(a, false);
    return next is((select count(*)::int from public.backups), 1, 'A kendi yedegini gorur');
    perform tests._logout();
end;
$$;

create or replace function tests.test_delete_my_data()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    b uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._user(b, false);
    perform tests._login(b, false);
    perform public.submit_shift(tests._payload(repeat('f', 64)));
    perform tests._login(a, false);
    perform public.submit_shift(tests._payload(repeat('1', 64)));
    insert into public.backups (user_id, payload) values (a, '{"v":1}');
    perform public.delete_my_data();
    perform tests._logout();
    return next is((select count(*)::int from public.shifts where user_id = a), 0, 'A vardiyalari silindi');
    return next is((select count(*)::int from public.backups where user_id = a), 0, 'A yedegi silindi');
    return next is((select count(*)::int from public.shifts where user_id = b), 1, 'B dokunulmadi');
end;
$$;

create or replace function tests.test_templates_public_read()
returns setof text language plpgsql as $$
begin
    insert into public.ocr_templates (id, platform_code, version, status, body)
    values ('test.earnings', 'test', 1, 'calibrating', '{}')
    on conflict do nothing;
    perform set_config('role', 'anon', true);
    return next ok((select count(*) from public.ocr_templates where id = 'test.earnings') = 1, 'anon sablon okur');
    return next throws_ok($q$insert into public.ocr_templates (id, platform_code, version, status, body) values ('x','x',1,'active','{}')$q$,
        '42501', null, 'anon sablon yazamaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_submit_calibration()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    i integer;
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_calibration('{"platform_code":"getir","template_id":"getir.earnings","lines":["a","b"]}'::jsonb), 'ok', 'kalibrasyon kabul');
    return next is(public.submit_calibration('{"platform_code":"getir","lines":[]}'::jsonb), 'invalid', 'bos dizi gecersiz');
    return next is(public.submit_calibration('{"platform_code":"getir","lines":"x"}'::jsonb), 'invalid', 'dizi olmayan lines gecersiz');
    for i in 1..19 loop
        perform public.submit_calibration('{"lines":["a"]}'::jsonb);
    end loop;
    return next is(public.submit_calibration('{"lines":["a"]}'::jsonb), 'rate_limited', 'gunde 20 sinir');
    perform tests._logout();
end;
$$;

create or replace function tests.test_anon_cannot_execute_submit_shift()
returns setof text language plpgsql as $$
begin
    perform set_config('role', 'anon', true);
    return next throws_ok($q$select public.submit_shift('{}'::jsonb)$q$, '42501', null, 'anon submit_shift calistiramaz');
    perform tests._logout();
end;
$$;
