-- 0026: Devotional catalog + deterministic preference loop (G19 follow-up).
--
-- (1) Makes today_devotional() / next_devotional() PREFERENCE-AWARE and
--     per-user, entirely deterministically:
--       * "Not for me" devotionals never resurface (hard filter).
--       * Focus match (devotional.focus_slug ∈ the user's chosen focus
--         areas, label→slug via focus_areas) is the strongest boost.
--       * Style affinity learned from devotional_feedback (net helpful −
--         unhelpful per style) nudges liked styles up, disliked styles down.
--       * Already-rated devotionals get a small freshness penalty.
--       * Ties rotate on a per-user per-day stable hash — same devotional
--         all day, a different one tomorrow, different per user.
--     Same signatures + return types as 0016/0017, so the app's decoding
--     is untouched. Zero AI.
--
-- (2) Seeds a real authored catalog (30 devotionals covering all 24 focus
--     areas and all five styles) so the surface no longer ships hollow.
--     Idempotent: guarded on title like 0016's seed.

-- ============================================================
-- 1. Preference-aware deterministic picker
-- ============================================================

create or replace function public._pick_devotional(p_exclude uuid[] default '{}')
returns setof public.devotionals
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select coalesce(p.focus_areas, '{}'::text[]) as labels
    from public.profiles p
    where p.id = auth.uid()
  ),
  my_slugs as (
    select fa.slug
    from public.focus_areas fa, me
    where fa.label = any(me.labels)
  ),
  style_affinity as (
    -- Net helpful-minus-unhelpful per style, learned from this user's
    -- feedback on built-in devotionals.
    select d.style, sum(case when f.helpful then 1 else -1 end) as net
    from public.devotional_feedback f
    join public.devotionals d on d.id = f.devotional_id
    where f.user_id = auth.uid() and f.source = 'builtin'
    group by d.style
  )
  select d.*
  from public.devotionals d
  left join style_affinity sa on sa.style = d.style
  left join public.devotional_feedback fb
    on fb.user_id = auth.uid() and fb.devotional_id = d.id
  where d.is_published
    and not (d.id = any(coalesce(p_exclude, '{}'::uuid[])))
    and coalesce(fb.helpful, true)   -- "Not for me" never comes back
  order by
    (
      30 * (d.focus_slug is not null
              and d.focus_slug in (select slug from my_slugs))::int
      + 10 * (coalesce(sa.net, 0) > 0)::int
      - 10 * (coalesce(sa.net, 0) < 0)::int
      -  5 * (fb.id is not null)::int
    ) desc,
    md5(d.id::text || coalesce(auth.uid()::text, '') || current_date::text)
  limit 1;
$$;

revoke all on function public._pick_devotional(uuid[]) from public;
revoke all on function public._pick_devotional(uuid[]) from anon;
grant execute on function public._pick_devotional(uuid[]) to authenticated;

-- Same signatures as 0016/0017 — the app keeps calling these unchanged.
create or replace function public.today_devotional()
returns setof public.devotionals
language sql stable security definer set search_path = public
as $$
  select * from public._pick_devotional('{}'::uuid[]);
$$;
grant execute on function public.today_devotional() to authenticated;

create or replace function public.next_devotional(p_exclude uuid[] default '{}')
returns setof public.devotionals
language sql stable security definer set search_path = public
as $$
  select * from public._pick_devotional(p_exclude);
$$;
grant execute on function public.next_devotional(uuid[]) to authenticated;

-- ============================================================
-- 2. Authored catalog seed (30, all focus areas + all styles)
-- ============================================================

insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Tomorrow can wait',
   'Matthew 6:34', 'Matthew', 6, 34, null,
   'Jesus ends His teaching on worry with startling practicality: each day has enough trouble of its own. He is not dismissing your concerns about next month — He is giving you permission to not carry them today. Anxiety almost always lives in tomorrow: the appointment, the bill, the conversation that hasn''t happened yet. But grace is given like manna, one day''s portion at a time. You have what you need for today. When tomorrow comes, so will its portion.',
   'What tomorrow-problem are you carrying today, and what would it mean to set it down until it actually arrives?',
   'practical', 'anxiety', array['worry','today','trust']),
  ('Casting, not carrying',
   '1 Peter 5:7', '1 Peter', 5, 7, null,
   'Peter chooses a fisherman''s word: cast. Not "mention your anxiety to God," not "hold it more calmly" — throw it, the way a net leaves your hands entirely. The reason given is not that God is powerful, though He is. It is that He cares for you. You are not handing your worries to a system but to Someone whose concern for you is personal and constant. Most of us cast our care and then quietly reel it back in. Practice leaving it thrown.',
   'Which worry do you keep reeling back in after praying about it?',
   'encouragement', 'anxiety', array['care','prayer','release']),
  ('Green pastures are His idea',
   'Psalm 23:1-3', 'Psalms', 23, 1, 3,
   'The shepherd MAKES me lie down, David writes. Sheep will graze themselves sick; rest has to be imposed by someone wiser. Notice that everything in these verses is the shepherd''s initiative — he leads, he restores, he guides. Your soul was never designed to restore itself. If you have been running on fumes, hear the invitation underneath the psalm: rest is not a reward for finishing everything. It is a provision from a Shepherd who knows what you need before you admit it.',
   'What would "lying down in green pastures" actually look like in your week?',
   'reflective', 'rest_peace', array['rest','shepherd','restoration']),
  ('The easy yoke',
   'Matthew 11:28-30', 'Matthew', 11, 28, 30,
   'Jesus does not offer the weary a hammock; He offers a yoke — His own. A yoke joins two animals so the stronger bears the load with the weaker. That is the surprise of this invitation: rest is not found in escaping work but in being paired with Someone gentle and humble who pulls alongside you. Much of our exhaustion comes from yokes Jesus never gave us: proving ourselves, pleasing everyone, controlling outcomes. His yoke fits. Come, and trade.',
   'Which yoke you''re wearing right now did Jesus never actually give you?',
   'encouragement', 'rest_peace', array['weariness','burden','gentleness']),
  ('Close to the brokenhearted',
   'Psalm 34:18', 'Psalms', 34, 18, null,
   'Grief convinces us that God has moved away — the silence feels like distance. This verse says the opposite: brokenness is where He draws NEAREST. David wrote it while running for his life, not from a comfortable study. God''s closeness to the crushed in spirit is not a feeling you must generate; it is a fact you are invited to lean on when feelings say otherwise. You do not have to be finished grieving to be held. You only have to be broken, and you already are.',
   'Where have you mistaken God''s silence for God''s absence?',
   'encouragement', 'grief', array['loss','comfort','presence']),
  ('Jesus wept',
   'John 11:35', 'John', 11, 35, null,
   'Jesus stood at Lazarus'' tomb knowing resurrection was minutes away — and still He wept. He did not skip grief because He knew the ending. That changes what faithful grieving looks like: tears are not a failure of faith. The shortest verse in the Bible is also one of the most freeing. You are allowed to weep over what death and loss have broken, even while you hope. Your tears keep company with His.',
   'Have you been rushing your grief because you felt a Christian should be "past it" by now?',
   'reflective', 'grief', array['tears','lament','hope']),
  ('As God forgave you',
   'Ephesians 4:32', 'Ephesians', 4, 32, null,
   'Paul grounds forgiveness not in the offender deserving it, but in what you have already received: forgive as God in Christ forgave you. That order matters. You are not generating mercy from scratch — you are passing on mercy that was extended to you at enormous cost. Forgiveness rarely arrives as a feeling first. It usually starts as a decision to stop collecting the debt, made before the heart catches up. Begin there, and let God work backward into the feelings.',
   'What debt are you still quietly collecting from someone — and what would it mean to tear up the ledger?',
   'practical', 'forgiveness', array['mercy','kindness','release'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Seventy times seven',
   'Matthew 18:21-22', 'Matthew', 18, 21, 22,
   'Peter thought seven was generous — the rabbis taught three. Jesus'' answer, seventy times seven, is not a higher ceiling to track but the end of counting altogether. Notice what the absurd number implies: forgiveness is not a single heroic act but a practice, repeated as often as the wound reopens. Forgiving someone again today for the same thing you forgave yesterday is not failure. It is exactly what Jesus described. Keep no count; God keeps none against you.',
   'Who requires a "seventy times seven" forgiveness from you right now — possibly for the same old wound?',
   'study', 'forgiveness', array['mercy','counting','practice']),
  ('His workmanship',
   'Ephesians 2:10', 'Ephesians', 2, 10, null,
   'You are God''s workmanship — the Greek word is poiema, where we get "poem." Created in Christ Jesus for good works, which God prepared in advance. Purpose, then, is less something you must invent and more something you walk into: works already laid out along your path like stones set before you arrived. Today''s version is rarely grand. It is the conversation in front of you, the task in your hands, done as someone crafted for exactly this.',
   'What "prepared-in-advance" good work might already be sitting in your path today?',
   'reflective', 'purpose', array['identity','calling','good works']),
  ('Plans, spoken in exile',
   'Jeremiah 29:11', 'Jeremiah', 29, 11, null,
   'This beloved verse was written to people entering seventy years of exile — most would die in Babylon. God''s "plans to prosper you" came WITH instructions to build houses, plant gardens, and seek the good of the city where they did not want to be. That context does not shrink the promise; it strengthens it. God''s good future does not require your circumstances to change first. Hope and a future can be built right here, in the middle of the situation you didn''t choose.',
   'What would "planting a garden in Babylon" look like in the situation you wish were different?',
   'study', 'purpose', array['hope','exile','patience']),
  ('As far as it depends on you',
   'Romans 12:18', 'Romans', 12, 18, null,
   'Paul is bracingly realistic: IF possible, AS FAR as it depends on you, live at peace with everyone. Scripture acknowledges that some peace is not in your power — reconciliation takes two. But it also refuses to let the other person''s hardness excuse your own. Your assignment is only your side of the street: the apology you owe, the tone you use, the first move you could make. Do your part fully, and release the outcome you cannot control.',
   'In your most strained relationship, what is the part that actually depends on you?',
   'practical', 'relationships', array['peace','conflict','responsibility']),
  ('Bearing with one another',
   'Ephesians 4:2-3', 'Ephesians', 4, 2, 3,
   'Paul''s recipe for unity is unglamorous: humility, gentleness, patience, bearing with one another in love. "Bearing with" assumes there will be things to bear — marriage does not fail the moment it requires endurance; that is when it becomes real. Eagerness to maintain unity means treating the bond itself as a treasure worth effort on ordinary days: the soft answer, the assumed good intent, the annoyance absorbed rather than returned. Great marriages are built from thousands of small acts of bearing.',
   'What small thing could you absorb with grace today instead of returning it?',
   'practical', 'marriage', array['unity','patience','gentleness']),
  ('Along the road',
   'Deuteronomy 6:6-7', 'Deuteronomy', 6, 6, 7,
   'Moses tells parents to impress God''s words on their children — not in scheduled lectures, but when you sit at home, walk along the road, lie down, get up. Faith transfers through the ordinary rhythms of a shared life: the car ride, the bedtime, the breakfast table. This takes the pressure off perfect family devotions and puts the weight where it belongs — on what your children see woven through your normal days. They will learn what God means to you from Tuesday, not just Sunday.',
   'Which ordinary daily moment with your kids could carry one honest sentence about God this week?',
   'practical', 'parenting', array['family','rhythms','teaching']),
  ('Where your treasure is',
   'Matthew 6:19-21', 'Matthew', 6, 19, 21,
   'Jesus'' argument against hoarding treasure on earth is not that money is evil but that earthly stores are insecure — moth, rust, and thieves get everything eventually. Then the diagnosis: where your treasure is, there your heart will be also. Notice the direction — the heart FOLLOWS the treasure. You do not wait to feel generous; you move the treasure and the heart comes after. Every act of giving is a small relocation of your heart toward what lasts.',
   'What is one concrete way to move a little treasure toward what cannot rust this week?',
   'reflective', 'financial_wisdom', array['treasure','generosity','heart']),
  ('Honor from the firstfruits',
   'Proverbs 3:9-10', 'Proverbs', 3, 9, 10,
   'Firstfruits giving means honoring God from the FIRST of the harvest — before the bills, not from whatever survives them. It is an act of ordered trust: putting God first in the budget line where your real priorities live. The proverb attaches a promise of provision, not as a vending machine, but as the settled experience of those who loosen their grip: God proves trustworthy with what remains. Giving first, even a little, preaches to your own heart about who provides.',
   'What would "first" rather than "leftover" giving look like at your current income?',
   'practical', 'financial_wisdom', array['firstfruits','trust','giving'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('The way out',
   '1 Corinthians 10:13', '1 Corinthians', 10, 13, null,
   'Three anchors in one verse: your temptation is common to humanity (you are not uniquely broken); God is faithful and limits what you face; and with every temptation He provides a way of escape. The way out usually is not mystical — it is the door you can walk through, the phone you can put down, the friend you can call, the room you can leave. Temptation''s favorite lie is inevitability. Faithfulness often looks like simply taking the exit while it is still small.',
   'For your most familiar temptation, what is the practical "way out" that appears early — and will you take it?',
   'encouragement', 'temptation', array['escape','faithfulness','endurance']),
  ('Strength made perfect in weakness',
   '2 Corinthians 12:9', '2 Corinthians', 12, 9, null,
   'Paul begged three times for his thorn to be removed. God''s answer was not removal but sufficiency: My grace is enough; My power is made perfect in weakness. Recovery communities have long known what the church sometimes forgets — admitting powerlessness is where real strength begins. Your struggle does not disqualify you from grace; it is precisely where grace does its best work. Today, weakness confessed out loud to God and one safe person is stronger than willpower performed alone.',
   'What weakness are you still trying to fight alone that grace is waiting to meet?',
   'encouragement', 'addiction', array['grace','weakness','honesty']),
  ('Slow to speak',
   'James 1:19-20', 'James', 1, 19, 20,
   'James gives anger a speed limit: quick to listen, slow to speak, slow to become angry — because human anger does not produce the righteousness of God. Notice he does not say anger is always sin; he says it is a bad producer. It promises justice and delivers wreckage. The discipline is sequencing: listen first, speak second, anger last and slowest. Most regretted words come from reversing that order. Slowing down is not weakness; it is refusing to let the flash decide.',
   'Where do you most need to trade speed for listening this week?',
   'practical', 'anger', array['listening','self-control','speech']),
  ('Set in families',
   'Psalm 68:6', 'Psalms', 68, 6, null,
   'God sets the lonely in families, the psalm says. It is one of Scripture''s quiet promises about how God actually works: His usual answer to loneliness is not a feeling delivered privately but people — a table, a congregation, a friendship that has to start somewhere awkward. That means the path out of loneliness usually requires showing up somewhere: the small group, the Sunday service, the coffee invitation. God sets the lonely in families, but He rarely does it while we stay home.',
   'What is one place you could keep showing up until it becomes belonging?',
   'encouragement', 'loneliness', array['belonging','community','courage']),
  ('Talking back to your soul',
   'Psalm 42:11', 'Psalms', 42, 11, null,
   'The psalmist does something remarkable: instead of only listening to his despair, he interrogates it — why, my soul, are you downcast? — and then preaches to himself: put your hope in God, for I will YET praise Him. Notice the honesty and the defiance held together: he does not deny the darkness, and he does not surrender to it. "Yet" is one of faith''s most powerful words. Hope, here, is not a mood. It is a direction you keep turning your face, even in tears.',
   'What would it sound like to say "I will yet praise Him" over your situation — honestly, not pretending?',
   'reflective', 'depression_hope', array['hope','lament','yet']),
  ('Begin with "Father"',
   'Matthew 6:9-13', 'Matthew', 6, 9, 13,
   'When the disciples asked how to pray, Jesus gave a pattern, and its first word settles everything: Father. Not a formula to impress, but a child''s address. The prayer moves in a learnable order — God''s name honored, His will welcomed, daily bread requested, forgiveness given and received, protection asked. If prayer feels like a skill you lack, borrow this scaffold line by line, slowly, in your own words. You are not performing for a judge. You are talking to your Father.',
   'Try praying the Lord''s Prayer one line at a time, pausing to add your own words to each. What line stops you?',
   'study', 'learning_to_pray', array['lords prayer','father','pattern']),
  ('Prayer without a room',
   '1 Thessalonians 5:16-18', '1 Thessalonians', 5, 16, 18,
   'Pray without ceasing sounds impossible if prayer means closed eyes and a quiet room. But Paul is describing a posture, not a marathon: a running conversation threaded through the day — thanks at the first coffee, help before the meeting, mercy in traffic. Short prayers are not lesser prayers. "Thank You." "Help." "Stay near." Rejoice always, pray continually, give thanks in all circumstances: three habits that turn an ordinary Tuesday into a day spent WITH God.',
   'What three moments in your daily routine could become one-sentence prayers this week?',
   'practical', 'learning_to_pray', array['habit','constancy','gratitude']),
  ('Not to condemn',
   'John 3:16-17', 'John', 3, 16, 17,
   'Everyone quotes verse 16; verse 17 answers the fear underneath: God did not send His Son into the world to condemn the world, but to save it. If you are new to faith, this is the heart of the whole story — the movement is love toward you, not a pointed finger. "Believes in Him" means entrusting yourself, the way you trust a bridge enough to walk on it, not passing a theology exam. Eternal life begins not when you have it all figured out, but when you lean your weight on Him.',
   'What have you assumed God''s posture toward you is — and how does verse 17 challenge it?',
   'study', 'new_to_christianity', array['gospel','love','belief'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('A lamp, not a floodlight',
   'Psalm 119:105', 'Psalms', 119, 105, null,
   'Your word is a lamp to my feet and a light to my path. An ancient oil lamp threw light only a step or two ahead — not a floodlight revealing the whole road. That is honest about how Scripture usually works: it rarely shows the entire journey, but it reliably lights the next step. Read this way, the Bible stops being a puzzle to master and becomes bread for today. You do not need to understand everything. You need enough light for your feet, and He gives it daily.',
   'What is the one next step today''s reading actually lights for you?',
   'practical', 'understanding_the_bible', array['scripture','guidance','daily bread']),
  ('Be still and know',
   'Psalm 46:10', 'Psalms', 46, 10, null,
   'Father, the earth around me shakes and I fill the silence with striving. You say: be still, and know that I am God. So I stop — hands open, shoulders down, thoughts handed over one at a time. You are God and I am not, and today that is not a threat but a relief. Be exalted in what I cannot control. Quiet the part of me that believes everything depends on my grip. I am still now. You are God. That is enough. Amen.',
   'Sit in silence for two minutes after praying this. What surfaced?',
   'prayer', 'understanding_god', array['stillness','sovereignty','surrender']),
  ('While you were still far off',
   'Luke 15:20', 'Luke', 15, 20, null,
   'The son rehearsed a speech about becoming a hired servant, but he never got to finish it — while he was still a long way off, the father saw him, was filled with compassion, and RAN. In that culture, patriarchs did not run; this father hikes up his robe and sprints. If you have been away from God, notice who moves first and fastest in this story. You do not need a polished speech or a probation period. You need only to turn toward home. He is already running.',
   'What speech have you been rehearsing for God that the Father''s embrace makes unnecessary?',
   'encouragement', 'returning_to_faith', array['prodigal','grace','homecoming']),
  ('The harvest has a timeline',
   'Galatians 6:9', 'Galatians', 6, 9, null,
   'Let us not grow weary of doing good, for at the proper time we will reap — IF we do not give up. Paul admits what every farmer knows: there is a long, unglamorous middle between sowing and harvest where nothing seems to be happening. Most spiritual disciplines feel exactly like that middle. The promise is not instant fruit but certain fruit, at the proper time. Today''s quiet faithfulness — the prayer, the reading, the small obedience — is seed in the ground, not seed wasted.',
   'Which good habit feels fruitless right now, and what would it mean to trust the "proper time"?',
   'encouragement', 'discipline', array['perseverance','sowing','habits']),
  ('Fearfully and wonderfully',
   'Psalm 139:13-14', 'Psalms', 139, 13, 14,
   'Father, You knit me together before anyone else had an opinion of me. I praise You because I am fearfully and wonderfully made — and today I choose to believe that about myself, since it is Your word and not my mood that gets the final say. Where others'' voices have carved doubt into me, speak louder. Where I have agreed with contempt for what You made, forgive me. Let me walk into today as someone wonderfully made, on purpose, for purpose. Amen.',
   'Whose verdict about you have you been trusting more than your Maker''s?',
   'prayer', 'confidence', array['identity','worth','made']),
  ('Two bosses, one audience',
   'Colossians 3:23', 'Colossians', 3, 23, null,
   'Whatever you do, work at it with all your heart, as working for the Lord and not for men. Paul wrote this to servants with earthly masters they did not choose — and gave their labor an audience of One. This transforms the unseen work: the spreadsheet nobody reads, the shift nobody thanks you for, the diaper changed at 3 a.m. Excellence becomes worship when the Lord is the customer. Your career may or may not notice your faithfulness this week. Heaven does.',
   'What piece of unnoticed work can you do today "as for the Lord"?',
   'practical', 'career', array['work','excellence','worship']),
  ('Forgetting what lies behind',
   'Philippians 3:13-14', 'Philippians', 3, 13, 14,
   'Paul — apostle, church planter — says he has not arrived. But one thing he does: forgetting what lies behind and straining toward what is ahead, he presses on toward the goal. Motivation dies in two places: yesterday''s failures and yesterday''s successes. Both are "what lies behind." The Christian life is run facing forward, with the posture of a runner leaning for the tape. You cannot change a single step already taken. You can lean into the next one. Press on.',
   'What from yesterday — a failure or even a success — do you need to leave behind to run today?',
   'encouragement', 'motivation', array['perseverance','forward','goal']),
  ('Not so with you',
   'Mark 10:43-45', 'Mark', 10, 43, 45,
   'James and John wanted the seats of honor; Jesus redefined the org chart: whoever wants to be great must be servant of all, for even the Son of Man came not to be served but to serve. "Not so with you" — leadership in His kingdom inverts the world''s model of leverage and being served. The test of your leadership this week is not how many people report to you but whom you stooped to serve when no one important was watching. Authority, in Jesus'' hands, looks like a towel.',
   'Who under your influence could you concretely serve this week — in a way that costs you something?',
   'study', 'leadership', array['servanthood','greatness','influence'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);
