-- pgTAP: platform kurallari erisim kurallari (001 dosyasindaki tests._user / _login / _logout yardimcilari).

create or replace function tests._seed_rule(rid text, ver integer, st text)
returns void language sql as $$
    insert into public.platform_rules (id, version, platform_code, category, kind, description, source_kind,
                                       last_checked_on, status, confidence)
    values (rid, ver, 'getir', 'slotSystem', 'info', 'test', 'secondary', current_date, st, 0.5)
$$;

create or replace function tests.test_rules_readable_by_anon_and_authenticated()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._seed_rule('test-rule', 1, 'unverified');
    perform tests._seed_rule('test-rule', 2, 'verified');
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is((select count(*)::integer from public.platform_rules where id = 'test-rule'), 2, 'anonim kullanici tum surumleri okur');
    perform tests._logout();
    perform set_config('role', 'anon', true);
    return next is((select max(version) from public.platform_rules where id = 'test-rule'), 2, 'anon okur');
    perform tests._logout();
end;
$$;

create or replace function tests.test_rules_not_writable_by_clients()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._login(a, false);
    return next throws_ok(
        $q$insert into public.platform_rules (id, version, platform_code, category, kind, description, source_kind,
             last_checked_on, status, confidence)
           values ('x', 1, 'getir', 'other', 'info', 'x', 'user', current_date, 'verified', 1)$q$,
        '42501', null, 'istemci kural yazamaz');
    return next throws_ok($q$update public.platform_rules set status = 'verified'$q$, '42501', null, 'istemci kural guncelleyemez');
    return next throws_ok($q$select * from public.rule_source_checks$q$, '42501', null, 'kaynak kontrolleri istemciye kapali');
    perform tests._logout();
end;
$$;

create or replace function tests.test_rule_checks_constraints()
returns setof text language plpgsql as $$
begin
    return next throws_ok(
        $q$insert into public.platform_rules (id, version, platform_code, category, kind, description, source_kind,
             last_checked_on, status, confidence) values ('c', 1, 'getir', 'other', 'info', 'c', 'blog', current_date, 'verified', 1)$q$,
        '23514', null, 'gecersiz kaynak turu reddedilir');
    return next throws_ok(
        $q$insert into public.platform_rules (id, version, platform_code, category, kind, description, source_kind,
             last_checked_on, status, confidence) values ('c', 1, 'getir', 'other', 'info', 'c', 'user', current_date, 'verified', 2)$q$,
        '23514', null, 'guven 0-1 disi reddedilir');
end;
$$;
