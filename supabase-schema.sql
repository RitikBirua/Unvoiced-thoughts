-- Unvoiced Thoughts — database schema
-- Run this once in Supabase Dashboard → SQL Editor → New query → paste → Run

create extension if not exists "pgcrypto";

-- ============ POSTS ============
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  body text not null default '',
  tags text not null default '',
  status text not null default 'draft' check (status in ('draft','published')),
  author_id uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table posts enable row level security;

-- Anyone can read published posts. The author can also read their own drafts.
create policy "public can read published posts"
  on posts for select
  using (status = 'published' or auth.uid() = author_id);

-- Only a logged-in author can create posts, and only under their own id.
create policy "author can insert own posts"
  on posts for insert
  with check (auth.uid() = author_id);

-- Only the author can edit their own posts.
create policy "author can update own posts"
  on posts for update
  using (auth.uid() = author_id);

-- Only the author can delete their own posts.
create policy "author can delete own posts"
  on posts for delete
  using (auth.uid() = author_id);

-- ============ COMMENTS ============
create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  name text not null default 'Anonymous',
  body text not null,
  created_at timestamptz not null default now()
);

alter table comments enable row level security;

-- Anyone can read comments.
create policy "public can read comments"
  on comments for select
  using (true);

-- Anyone (including anonymous readers) can post a comment, within basic length limits.
create policy "anyone can add a comment"
  on comments for insert
  with check (char_length(body) > 0 and char_length(body) <= 2000 and char_length(name) <= 80);

-- Only the author of the parent post can delete a comment (moderation).
create policy "author can moderate comments"
  on comments for delete
  using (
    exists (
      select 1 from posts
      where posts.id = comments.post_id
      and posts.author_id = auth.uid()
    )
  );

-- Baseline grants (RLS policies above are what actually enforce access)
grant usage on schema public to anon, authenticated;
grant select, insert on comments to anon, authenticated;
grant select, insert, update, delete on posts to authenticated;
grant select on posts to anon;
