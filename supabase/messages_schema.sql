-- ============================================
--  방명록(guestbook) 스키마 — Supabase (Postgres)
--  Supabase 대시보드 > SQL Editor 에 붙여넣고 실행하세요.
-- ============================================

-- 1) 테이블 생성
create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  name       text not null check (char_length(trim(name)) between 1 and 50),
  content    text not null check (char_length(trim(content)) between 1 and 500),
  created_at timestamptz not null default now()
);

-- 최신순 조회를 자주 할 것이므로 인덱스 추가
create index if not exists messages_created_at_idx
  on public.messages (created_at desc);

-- 2) RLS(Row Level Security) 활성화
alter table public.messages enable row level security;

-- 3) 정책: 누구나 읽기 가능 (SELECT)
create policy "messages_public_read"
  on public.messages
  for select
  to anon, authenticated
  using (true);

-- 4) 정책: 누구나 작성 가능 (INSERT)
create policy "messages_public_insert"
  on public.messages
  for insert
  to anon, authenticated
  with check (true);

-- 5) UPDATE / DELETE 정책은 만들지 않음
--    → 정책이 없으면 RLS가 자동으로 차단하므로
--      익명 사용자는 남의 글을 수정/삭제할 수 없음.
--    → 관리자가 지우고 싶으면 Supabase 대시보드에서
--      service_role 키로 직접 삭제 (RLS 우회됨).
