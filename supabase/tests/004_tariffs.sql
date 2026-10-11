-- pgTAP: hakedis tarifeleri erisim kurallari ve aday durum makinesi (canli Supabase; 001'deki _user/_login/_logout).
-- Ayrintili akis testleri yerelde: cd scripts/server && npm test (PGlite, ayni goc dosyasi).

create or replace function tests.test_tariffs_published_readable_only()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    insert into public.tariff_platforms (platform_id, platform_name) values ('test_pf', 'Test') on conflict do nothing;
    insert into public.tariff_versions (tariff_version_id, platform_id, version_number, effective_from, source_type,
        verification_status, approval_status)
    values ('test-pub', 'test_pf', 1, '2026-01-01', 'seed', 'unverified', 'published'),
           ('test-draft', 'test_pf', 2, '2026-01-01', 'seed', 'unverified', 'draft');
    insert into public.tariff_items (tariff_item_id, tariff_version_id, item_key, item_type, label, amount, unit, calculation_method,
        confidence_status)
    values ('test-i1', 'test-pub', 'package.day', 'single_package', 'Paket', 50, 'package', 'per_unit', 'needs_verification'),
           ('test-i2', 'test-draft', 'package.day', 'single_package', 'Paket', 99, 'package', 'per_unit', 'needs_verification');
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is((select count(*)::integer from public.tariff_versions where platform_id = 'test_pf'), 1, 'yalnizca yayindaki surum gorunur');
    return next is((select count(*)::integer from public.tariff_items where tariff_version_id like 'test-%'), 1, 'taslak kalemi gorunmez');
    perform tests._logout();
end;
$$;

create or replace function tests.test_tariffs_not_writable_by_clients()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._login(a, false);
    return next throws_ok($q$update public.tariff_items set amount = 1$q$, '42501', null, 'istemci kalem guncelleyemez');
    return next throws_ok($q$select * from public.tariff_candidates$q$, '42501', null, 'adaylar istemciye kapali');
    return next throws_ok($q$select * from public.tariff_audit_log$q$, '42501', null, 'denetim kaydi istemciye kapali');
    return next throws_ok($q$select public.publish_tariff_candidate('x', 'y')$q$, '42501', null, 'istemci yayimlayamaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_tariff_candidate_transitions()
returns setof text language plpgsql as $$
begin
    return next ok(public.tariff_candidate_transition_ok('pending_verification', 'approved'), 'dogrulama -> onay');
    return next ok(not public.tariff_candidate_transition_ok('rejected', 'approved'), 'ret -> onay yok');
    return next ok(not public.tariff_candidate_transition_ok('draft', 'published'), 'taslak dogrudan yayimlanmaz');
end;
$$;
